---
phase: 04-grammar-morphology-revised
plan: 12
subsystem: lexicon-derivation
tags: [derivation, lexicon, riverpod, drift, reactive]
requires:
  - 04-08 (v9 schema: Lexemes.derivedFromLexemeId, derivedViaRuleId, rootOnlyViaDerivations; MorphologicalRules.autoApply; LexemeParents junction)
  - 04-09 (lexeme_providers.dart merge-conflict avoidance only — no semantic dependency)
provides:
  - lib/features/lexicon/data/lexeme_providers.dart::computedDerivedFormsProvider keyed by int lexemeId with strict D-61 POS filter
  - lib/features/lexicon/data/lexeme_providers.dart::promotedDerivedFormProvider — render-time reactive computation from rule + parent
  - lib/features/lexicon/data/lexeme_providers.dart::PromotedDerivedForm value class
  - lib/features/lexicon/data/lexeme_dao.dart::promoteDerivation / demoteDerivation / detachFromRule
  - lib/features/morphology/application/derivation_promotion_service.dart::DerivationPromotionService.reconcile + provider
  - lib/features/grammar/data/lexeme_parents_dao.dart::LexemeParentsDao CRUD + streams
  - lib/features/grammar/data/grammar_providers.dart::lexemeParentsDaoProvider / parentsForLexemeProvider / childrenForLexemeProvider
affects:
  - Closes G-13 (POS filter bug on derivation provider)
  - Foundation for G-14, G-17, G-18, G-19 (UI consumers in plan 04-14)
  - LexemeParents data layer ready for D-62 UI display
tech-stack:
  added: []
  patterns:
    - Render-time reactive computation via Riverpod stream chains: promotedDerivedFormProvider watches both parent lexemeByIdProvider AND morphologicalRuleListProvider so rule edits propagate to every dependent row without re-save
    - Free-text POS resolution via posForLexeme (case-insensitive name/abbr match) — inherited from plan 04-07 research recommendation A7
    - Idempotent reconcile service keyed by (parentId, ruleId) pair — single-pass O(rules * lexemes)
    - insertOrIgnore on composite-PK junction for duplicate-safe writes (pattern established by 04-11's InflectionalRulePOSDao)
key-files:
  created:
    - lib/features/morphology/application/derivation_promotion_service.dart
    - lib/features/grammar/data/lexeme_parents_dao.dart
    - lib/features/grammar/data/lexeme_parents_dao.g.dart
    - test/unit/lexicon/computed_derived_forms_pos_filter_test.dart
    - test/unit/lexicon/promoted_derivation_test.dart
    - test/unit/lexicon/auto_apply_derivation_test.dart
    - test/unit/grammar/lexeme_parents_dao_test.dart
  modified:
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/features/lexicon/data/lexeme_dao.dart
    - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
    - lib/features/grammar/data/grammar_providers.dart
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - test/unit/lexicon/computed_derived_forms_kind_filter_test.dart
decisions:
  - "04-12: Re-key computedDerivedFormsProvider from String rootIpa to int lexemeId so the provider can resolve POS internally (Option A from the planner) — alternative (rootIpa, posId) tuples or a new `forLexemeId` variant both leaked the POS concern to call sites"
  - "04-12: Eagerly subscribe to lexemeByIdProvider in test helpers — the family is lazy and the first synchronous read would otherwise see AsyncLoading and short-circuit with an empty list before Drift emits its first stream event"
  - "04-12: promotedDerivedFormProvider's rule lookup is a linear scan over morphologicalRuleListProvider's list rather than a DB query — the list is typically <100 rules and Riverpod caches the scan result per lexeme id, so the tradeoff for simplicity wins"
  - "04-12: DerivationPromotionService uses a Set<String> of `\"parentId:ruleId\"` pairs rather than a Record<int,int> — Dart records do not support value equality as Set keys without explicit Hashable wrappers; string join is trivially hashable and unambiguous"
  - "04-12: promoteDerivation leaves `ipa` set to the parent's ipa as a placeholder (not null) — the column is non-nullable so it must hold *something*; the authoritative form is computed on every read via promotedDerivedFormProvider, so the placeholder is never user-visible"
  - "04-12: DerivationPromotionService only promotes from non-derived parent rows (skips already-promoted lexemes) — this keeps auto-apply scoped to a single derivation layer. Cascading auto-apply across derivation chains would blow up the Lexemes table and was never part of D-59's scope"
metrics:
  duration_min: 18
  task_count: 4
  files_created: 7
  files_modified: 7
  completed: 2026-04-11
---

# Phase 04 Plan 12: Derivation data/engine layer Summary

**One-liner:** Re-key derivation provider by lexeme id for strict D-61 POS filter, add promote/demote/detach DAO helpers with a render-time reactive PromotedDerivedForm provider that satisfies D-58's 100-lexeme rule-edit constraint, implement D-59 autoApply reconcile service with the exact "`{meaning} ({rule.name})`" template, and ship LexemeParentsDao for D-62 manual etymology links.

## Goal

Deliver the data/engine layer of the Phase 4 derivation overhaul:
- G-13 / D-61: strict POS match on derivation rules (no "any POS" sentinel)
- D-57: promoted-derivation path (new Lexeme row per user-meaning-assignment, rule-linked via v9 columns)
- D-58: computed-by-default, stored-if-edited — reactive form computation from rule + parent, implicit detach gesture on rom/ipa edit
- D-59: auto-apply derivational rules materialize promoted rows with the exact "`{parentMeaning} ({ruleName})`" gloss template
- D-62 (data layer): LexemeParentsDao for the v9 lexeme_parents junction (UI display in plan 04-14)

UI consumers (D-60 suggestion chips, D-63 grey root filter, D-64/D-65 rootOnlyViaDerivations toggle, parent list render) live in plan 04-14.

## What Changed

### Task 1 — D-61 / G-13 strict POS filter on computedDerivedFormsProvider

- **Re-keyed** `computedDerivedFormsProvider` from `Provider.family<_, String rootIpa>` to `Provider.family<_, int lexemeId>` so the provider can resolve the lexeme's POS via `lexemeByIdProvider` + `posListProvider` + `posForLexeme`.
- **Added** strict filter: `dbRule.inputPosId == null || dbRule.inputPosId != pos.id` -> skip. No universal sentinel — rules with a null `inputPosId` are never applied.
- **Updated** the sole call site `derivation_tree_widget.dart` to pass `rootId` instead of `rootIpa`. The widget's `rootIpa` parameter is still used for the root-node label rendering — only the provider argument changed.
- **Adapted** `test/unit/lexicon/computed_derived_forms_kind_filter_test.dart` from 04-07 to the new signature (seeds a Noun/Verb lexeme per test case; rules now carry `inputPosId`).
- **Added** `test/unit/lexicon/computed_derived_forms_pos_filter_test.dart` with 6 tests covering Noun rule not applied to Verb, matching POS applied, null inputPosId excluded, lowercase free-text match via posForLexeme, unresolvable POS returns empty, and inflectional kind still skipped.

### Task 2 — D-57 + D-58 promoted-derivation path

- **LexemeDao.promoteDerivation(parentId, ruleId, gloss)** — inserts a Lexeme row with `derivedFromLexemeId` + `derivedViaRuleId` set, `partOfSpeech` resolved from the rule's output POS (looked up in `partsOfSpeech`), `romanization = null`, and `ipa` seeded as a placeholder from the parent.
- **LexemeDao.demoteDerivation(lexemeId)** — deletes the row; returns `false` for non-promoted rows (silent no-op, callers may demote unconditionally).
- **LexemeDao.detachFromRule(lexemeId, newIpa, newRom)** — writes the new form AND nulls `derivedViaRuleId` in one companion update. `derivedFromLexemeId` is preserved — only the rule link is severed. This is the implicit detach gesture.
- **PromotedDerivedForm** value class + **promotedDerivedFormProvider(lexemeId)** — render-time reactive computation that watches both `lexemeByIdProvider(parentId)` AND `morphologicalRuleListProvider`. When the rule's DSL source changes, every dependent promoted row re-emits automatically via Riverpod.
- **Test 3 (the 100-lexeme constraint, the correctness gate):** seeds one parent `kama` + 100 promoted rows, reads each (all return `kamain`), updates the rule from `+in` to `+il`, reads each again — all return `kamail`. No manual re-save on any row. Passes in ~300ms.

### Task 3 — D-59 autoApply reconcile service

- **DerivationPromotionService.reconcile()** walks every `(rule, lexeme)` pair where:
  - `rule.isActive && rule.autoApply && rule.kind == 'derivational'`
  - `rule.inputPosId` non-null AND matches `posForLexeme(parent)`
  - `parent.meaning` non-null and non-empty
  - parent is NOT already a promoted row (first-layer only)
  - no existing `(derivedFromLexemeId = parent, derivedViaRuleId = rule)` row (idempotency)
- Templated gloss matches the D-59 user example EXACTLY: `'$meaning (${rule.name})'` — e.g. `kama "to run" + Actor rule` -> promoted Lexeme with gloss `"to run (Actor)"`. Test 1 asserts this exact string.
- Exposed via `derivationPromotionServiceProvider`. Wiring into app startup / rule-save / lexeme-meaning-save paths is deferred to plan 04-14 UI.

### Task 4 — D-62 data layer (LexemeParentsDao)

- **LexemeParentsDao** with full CRUD: `insertParent` (insertOrIgnore on composite PK), `updateParent`, `deleteParent`, `watchParentsForChild`, `watchChildrenForParent`.
- Registered in `@DriftDatabase.daos` (+ import); Drift codegen regenerated.
- **grammar_providers.dart** now exposes `lexemeParentsDaoProvider`, `parentsForLexemeProvider` (child -> parents), `childrenForLexemeProvider` (parent -> children).
- 7 unit tests including CASCADE coverage (deleting either child or parent cleans up junction rows via the v9 FK constraint).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Lazy family-provider + AsyncLoading short-circuit in tests**

- **Found during:** Task 1 (first `computed_derived_forms_pos_filter_test.dart` run)
- **Issue:** `computedDerivedFormsProvider(id)` now reads `lexemeByIdProvider(id)` internally. In a fresh `ProviderContainer`, the first synchronous `container.read(computedDerivedFormsProvider(id))` sees `AsyncLoading` on the lexeme family (because nothing has subscribed yet) and returns `const []` — all positive cases failed with "Expected: 1, Actual: 0".
- **Fix:** Eagerly `container.listen(lexemeByIdProvider(lexemeId), ...)` inside the test helpers (both `readDerivedFor` and `readPromoted`) before pumping ticks and reading the result. For `promotedDerivedFormProvider` the parent subscription happens on the second build, so Test 2 of Task 2 needed an additional `pumpTicks()` pass.
- **Files modified:** `test/unit/lexicon/computed_derived_forms_pos_filter_test.dart`, `test/unit/lexicon/computed_derived_forms_kind_filter_test.dart`, `test/unit/lexicon/promoted_derivation_test.dart`
- **Commit:** covered in `7c55080` and `1664d24`

**2. [Rule 1 — Bug] Plan interface description specified `'suffix: in'` DSL syntax; actual parser uses `'+in'`**

- **Found during:** Task 1 RED (test file compiled but failed all DSL-parse branches)
- **Issue:** The plan's behavior examples say `source: 'suffix: in'`, but `parseMorphDsl` in `morphology_dsl.dart` expects the `+affix` / `affix+` form (see line 307 — `char('+') & pattern('^ |').plus().flatten()`).
- **Fix:** Use `'+in'` everywhere — matches the existing 04-07 `kind_filter_test` convention.
- **Files modified:** `test/unit/lexicon/computed_derived_forms_pos_filter_test.dart` (before first commit, so no separate commit)

### Deferred Issues

Two pre-existing compile failures surfaced when running the full grammar suite; both reproduced on the ddc1b96 base BEFORE any 04-12 changes. Logged in `.planning/phases/04-grammar-morphology-revised/deferred-items.md` under "From 04-12":

1. **`test/unit/grammar/typology_providers_test.dart`** — `markersForPosProvider` referenced but not defined in `lib/features/grammar/data/typology_providers.dart:391`. Gap from plan 04-10 marker integration.
2. **`test/unit/grammar/marker_dao_test.dart`** — references `db.markerDao` but `AppDatabase` has no such getter. Gap from plan 04-10 (`a30a938`) — the DAO was registered in the Drift accessor list but the hand-written convenience getter was never authored.

Neither is touched by plan 04-12's scope (derivation data/engine layer).

## Authentication / Human Gates

None — plan is fully autonomous.

## Verification

### Automated

```bash
flutter test test/unit/lexicon/ 2>&1 | tail -3
# 00:01 +24: All tests passed!   (6 POS filter + 4 kind filter + 7 promoted + 7 auto-apply)

flutter test test/unit/grammar/lexeme_parents_dao_test.dart 2>&1 | tail -3
# 00:01 +7: All tests passed!

flutter analyze lib/features/morphology/application/ lib/features/grammar/data/lexeme_parents_dao.dart lib/features/lexicon/data/lexeme_dao.dart lib/features/lexicon/data/lexeme_providers.dart 2>&1 | tail -3
# No issues found!
```

### Success Criteria Check

- [x] D-61 strict POS filter: `computedDerivedFormsProvider` keyed by int lexemeId, applies `dbRule.inputPosId == pos.id` — G-13 closed
- [x] D-57 promoted derivation path: `promoteDerivation` / `demoteDerivation` / `detachFromRule` live on `LexemeDao`
- [x] D-58 implicit detach + rule-edit reactivity: `promotedDerivedFormProvider` + 100-lexeme constraint test green
- [x] D-59 autoApply reconcile service: `DerivationPromotionService.reconcile()` produces exact `"to run (Actor)"` gloss; idempotent; defers when meaning is null
- [x] D-62 LexemeParentsDao: CRUD + streams + cascade + provider wiring
- [x] All 24 lexicon tests green (4 kind filter + 6 POS filter + 7 promoted + 7 auto-apply)
- [x] All 7 LexemeParentsDao tests green including CASCADE

## Commits

1. `912c431` test(04-12): add failing POS filter test for computedDerivedFormsProvider (D-61)
2. `7c55080` feat(04-12): strict POS filter on computedDerivedFormsProvider (D-61 / G-13)
3. `88a5ae5` test(04-12): add failing promoted-derivation tests (D-57 + D-58)
4. `1664d24` feat(04-12): promoted derivation path — D-57 DAO + D-58 reactive provider
5. `56714bf` test(04-12): add failing auto-apply derivation reconcile tests (D-59)
6. `73988e5` feat(04-12): add DerivationPromotionService reconcile (D-59)
7. `202a6a1` test(04-12): add failing LexemeParentsDao tests (D-62)
8. `667a205` feat(04-12): add LexemeParentsDao for v9 lexeme_parents junction (D-62)
9. `02140cf` chore(04-12): drop unused import + log pre-existing typology compile gap
10. `d1d7e60` chore(04-12): log pre-existing marker_dao_test compile gap in deferred items

## Notes for Plan 04-14 (UI consumers)

Plan 04-14 can now:
- Render derivation suggestions via `computedDerivedFormsProvider(lexemeId)` — only matching-POS rules surface (D-60 suggestion chips).
- Render promoted derived forms via `promotedDerivedFormProvider(lexemeId)` — rom + ipa are computed on every frame, so rule edits flow through with no additional plumbing.
- Call `lexemeDao.detachFromRule(...)` from an edit handler when the user types into a rom/ipa field on a promoted lexeme (D-58 implicit detach).
- Call `lexemeDao.demoteDerivation(...)` from a "Remove this derived form" button (D-57 reversal).
- Call `derivationPromotionServiceProvider.reconcile()` from app startup + the rule save path + the lexeme meaning save path to materialize `autoApply=true` rules.
- Render manual etymology via `parentsForLexemeProvider(childLexemeId)` alongside the rule-linked derivation header (D-62 UI).
- Surface `rootOnlyViaDerivations` toggle on the word detail panel (D-63) — the v9 column is already present, just needs a checkbox + the filtered dictionary sidebar rendering.

## Self-Check: PASSED

All 7 created files present on disk:
- lib/features/morphology/application/derivation_promotion_service.dart
- lib/features/grammar/data/lexeme_parents_dao.dart
- lib/features/grammar/data/lexeme_parents_dao.g.dart
- test/unit/lexicon/computed_derived_forms_pos_filter_test.dart
- test/unit/lexicon/promoted_derivation_test.dart
- test/unit/lexicon/auto_apply_derivation_test.dart
- test/unit/grammar/lexeme_parents_dao_test.dart

All 10 task commits verified in `git log --all`:
912c431, 7c55080, 88a5ae5, 1664d24, 56714bf, 73988e5, 202a6a1, 667a205, 02140cf, d1d7e60
