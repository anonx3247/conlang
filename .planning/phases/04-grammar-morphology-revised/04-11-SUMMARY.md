---
phase: 04-grammar-morphology-revised
plan: 11
subsystem: grammar
tags: [multi-pos, inflectional-rules, junction-table, D-55, D-56, G-05, G-09]
requires:
  - "v9 inflectional_rule_pos junction table (plan 04-08)"
  - "RuleEditorDialog kind-aware mode (plan 04-05)"
provides:
  - "InflectionalRulePOSDao (CRUD + stream over inflectional_rule_pos)"
  - "Junction-driven watchInflectionalRulesForPos"
  - "Multi-select POS picker in RuleEditorDialog inflectional mode"
  - "POS-set grouping in rules_page inflectional mode (D-56)"
affects:
  - "lib/features/morphology/data/morphology_dao.dart"
  - "lib/features/morphology/presentation/rules/rule_editor_dialog.dart"
  - "lib/features/morphology/presentation/rules/rules_page.dart"
tech-stack:
  added: []
  patterns:
    - "Drift DatabaseAccessor + DriftAccessor for the junction DAO"
    - "Junction-driven inner join for inflectional rule lookup"
    - "Provider.family<Set<int>, int> for per-rule POS set streams"
    - "FilterChip Wrap for multi-select POS picker"
    - "Dimension intersection by name across multi-POS selection"
    - "Post-frame setState hydration guarded by '_hydratedPosSetForRuleId'"
    - "Pure grouping helper (List + Map -> ordered records) for testability"
key-files:
  created:
    - lib/features/grammar/data/inflectional_rule_pos_dao.dart
    - lib/features/grammar/data/inflectional_rule_pos_dao.g.dart
    - test/unit/grammar/inflectional_rule_pos_dao_test.dart
    - test/unit/morphology/morphology_dao_inflectional_test.dart
    - test/widget/grammar/rule_editor_multi_pos_test.dart
    - test/widget/grammar/rules_page_pos_grouping_test.dart
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/grammar/data/grammar_providers.dart
    - lib/features/morphology/data/morphology_dao.dart
    - lib/features/morphology/data/morphology_dao.g.dart
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/morphology/presentation/rules/rules_page.dart
    - test/unit/grammar/grammar_dao_test.dart
    - test/unit/grammar/paradigm_cell_override_test.dart
    - test/widget/grammar/rule_editor_dialog_kind_test.dart
decisions:
  - "Multi-POS intersection uses dimension NAME (not id) — dimensions are per-POS rows (D-02) that share names across POS but not ids; the intersection renders the first-POS row for shared names."
  - "Legacy input_pos_id is populated with the FIRST selected POS on inflectional save (convenience cache only; junction is authoritative)."
  - "Pure grouping helper exported as a top-level function so the pure algorithm is testable without pumping a widget tree."
  - "Rule 1 auto-fix: two pre-existing tests seeded inflectional rules via featureBindings.pos alone (v8 semantics); they were updated to also write the junction via replaceForRule."
metrics:
  duration: ~28m (executor wall-clock)
  tasks: 4
  files_changed: 16
  lines_added: 1703
  lines_removed: 120
  tests_added: 25
  tests_regression_fixed: 2
---

# Phase 04 Plan 11: Multi-POS Inflectional Rules (G-05, G-09) Summary

Multi-POS inflectional rules with junction-driven read/write and POS-set grouping in the rules list — G-05 + G-09 closed end-to-end via the v9 `inflectional_rule_pos` table.

## Context

Plan 04-08 added the `inflectional_rule_pos` junction table (schema v9) and
backfilled one junction row per existing inflectional rule using its
`input_pos_id`. Plan 04-11 wires that table into the read path (MorphologyDao),
write path (RuleEditorDialog save), and UI grouping (rules_page) so a single
inflectional rule can target multiple parts of speech — the D-55 / D-56
contract.

## Tasks

### Task 1 — InflectionalRulePOSDao (commit `c668444`)

Created a new `@DriftAccessor(tables: [InflectionalRulePOS])` DAO with three
operations:

- **`replaceForRule({required int ruleId, required Set<int> posIds})`** —
  transactional delete-then-insert. Empty set clears all rows for the rule.
- **`watchPosSetForRule(int ruleId)`** — streams the POS set for one rule.
- **`watchAllPosSetsByRuleId()`** — streams `Map<int, Set<int>>` for every
  rule that has at least one junction row (fuels `rules_page` grouping).

Registered in `@DriftDatabase.daos` and exposed via three providers in
`grammar_providers.dart`:

- `inflectionalRulePOSDaoProvider`
- `posSetForRuleProvider` (family by rule id)
- `allRulePosSetsProvider`

**Unit tests (10):** `replaceForRule` insert/replace/clear, isolation across
rules, `watchPosSetForRule` happy path + empty set, `watchAllPosSetsByRuleId`
happy + empty, ON DELETE CASCADE cleanup when parent rule is deleted, and
`deleteAllForRule` explicit cleanup.

### Task 2 — Junction-driven MorphologyDao (commit `8a187be`)

Replaced `watchInflectionalRulesForPos`'s Dart-side `featureBindings.pos`
filter with an INNER JOIN on the junction table:

```dart
select(morphologicalRules).join([
  innerJoin(
    inflectionalRulePOS,
    inflectionalRulePOS.ruleId.equalsExp(morphologicalRules.id),
  ),
])
  ..where(
    morphologicalRules.kind.equals('inflectional') &
        inflectionalRulePOS.posId.equals(posId),
  )
  ..orderBy([OrderingTerm.asc(morphologicalRules.ordering)]);
```

Deduplication on the joined rows defends against schema drift.
`inflectionalRulesForPosProvider` is unchanged at the provider level — the
contract `List<InflectionalRule>` for a given `posId` is preserved.

**Unit tests (6):** single-POS lookup, multi-POS rule surfaces in every
matching POS, derivational rules filtered by kind even with a junction row,
inactive rules still returned (paradigm engine filters isActive downstream),
v9-backfilled shape works, legacy `input_pos_id` is NOT consulted without a
junction row.

**Regressions:** `paradigm_generation_test.dart` + `paradigm_engine_test.dart`
(19 tests) still green.

### Task 3 — Multi-POS picker in RuleEditorDialog (commit `d20e59c`)

Replaced the single-select "Target POS" `DropdownButtonFormField` with a
`FilterChip`-based multi-select:

- New state: `final Set<int> _inflectionalPosSet = <int>{}`
- `_selectedPosIdForChips` is now a getter returning the first element
  (preserves the tiebreak detector and legacy-cache paths).
- Async hydration from `posSetForRuleProvider` when editing an existing rule,
  once per rule id, via `WidgetsBinding.addPostFrameCallback`.
- Dimension chip rows render the INTERSECTION (by name) of dimensions across
  every selected POS, with an informative empty-intersection message.
- Save path:
  1. Build `featureBindings.pos = _inflectionalPosSet.toList()..sort()`
     as a convenience cache.
  2. Insert or update the `MorphologicalRules` row with the first selected
     POS in `input_pos_id` (legacy cache).
  3. Call `InflectionalRulePOSDao.replaceForRule(ruleId, posIds)`.
- New validation: empty POS set → `"At least one POS must be selected for
  inflectional rules."` — rejected at save time, no DB write.

**Widget tests (7):** new-rule initial state, hydrate-from-junction on edit,
accumulating multi-POS chip taps, save writes junction rows, legacy
`input_pos_id` convenience cache, empty-set validation, dimension
intersection visibility (Noun+Adjective hides Gender, keeps Number).

**Existing tests adjusted (2):** `rule_editor_dialog_kind_test.dart` tests 1
and 4 interacted with the now-removed "Target POS" dropdown; they were
updated to tap the new `FilterChip`. Tests 2, 3, 5, 6 unchanged. All 6 kind
tests green.

### Task 4 — POS-set grouping in rules_page.dart (commit `cbdd399`)

New top-level helper `groupInflectionalRulesByPosSet` producing an ordered
`List<({String header, List<MorphologicalRule> rules})>`:

1. Group rules by canonical POS-set key (sorted, comma-joined).
2. Split into three tiers:
   - **Single-POS** (`|posIds| == 1`) — alphabetic by POS name
   - **Multi-POS** (`|posIds| > 1`) — alphabetic by joined name
     (e.g. "Adjective + Noun")
   - **Unattached** (`|posIds| == 0`) — always last
3. Concatenate in the order `[...single, ...multi, ...unattached]`.

`_buildInflectionalGroupedList` consumes `allRulePosSetsProvider`, runs the
helper, and renders small-caps section headers above rule cards. A multi-POS
rule appears EXACTLY ONCE in its own POS-set group — never duplicated under
every constituent POS.

Derivational mode uses the existing flat-list path unchanged.

**Pure tests (2):** alphabetization + tier ordering; Unattached behavior.
**Widget tests (5):** single-POS render, multi-POS renders once,
alphabetized rendering order by y-coordinate, Unattached at bottom,
derivational mode unchanged (legacy "Filter by POS" dropdown still present).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Pre-existing v8 fixtures in two tests broke after the
D-55 junction became authoritative**

- **Found during:** final regression run after Task 4 commit
- **Issue:** `grammar_dao_test.dart::watchInflectionalRulesForPos filters by
  pos AND kind` and
  `paradigm_cell_override_test.dart::paradigmCoverageMatrixProvider flags
  only (dim, level) pairs covered by an active inflectional rule` both
  seeded inflectional rules via `featureBindings.pos` alone, expecting the
  v8 Dart-side filter to surface them. Post-Task-2, the v9 JOIN query
  requires an `inflectional_rule_pos` row — neither test was writing one.
- **Fix:** Updated both tests to also call
  `InflectionalRulePOSDao.replaceForRule` on the seeded rule. Also
  rewrote the `grammar_dao_test.dart` "applies-to-all (empty pos)" case to
  an "attached to a different POS" case — the v8 empty-pos shape is no
  longer a supported semantics.
- **Files modified:** `test/unit/grammar/grammar_dao_test.dart`,
  `test/unit/grammar/paradigm_cell_override_test.dart`
- **Commit:** `04b6cd2`

### Out-of-scope (not fixed)

- `test/phonotactic_dsl_smoke_test.dart` fails at test-load with a
  pre-existing assertion on line 72 (`!c1.rule!.isForbidden`). Unrelated to
  this plan — phonotactic DSL is phase 01 territory. Already recorded in
  `.planning/phases/04-grammar-morphology-revised/deferred-items.md`.

## Verification

- `flutter test --no-pub test/unit/grammar/inflectional_rule_pos_dao_test.dart` — **10 pass**
- `flutter test --no-pub test/unit/morphology/morphology_dao_inflectional_test.dart` — **6 pass**
- `flutter test --no-pub test/widget/grammar/rule_editor_multi_pos_test.dart` — **7 pass**
- `flutter test --no-pub test/widget/grammar/rules_page_pos_grouping_test.dart` — **7 pass** (2 pure + 5 widget)
- `flutter test --no-pub test/widget/grammar/rule_editor_dialog_kind_test.dart` — **6 pass** (plan 04-05 regression guard)
- `flutter test --no-pub test/widget/grammar/` — **63 pass**
- `flutter test --no-pub test/unit/ test/widget/ test/integration/` — **199 pass**

## Known Stubs

None. The plan closed G-05 and G-09 end-to-end; no UI stubs or hardcoded
placeholders were introduced.

## Self-Check: PASSED

**Files:**
- `lib/features/grammar/data/inflectional_rule_pos_dao.dart` — FOUND
- `lib/features/grammar/data/inflectional_rule_pos_dao.g.dart` — FOUND
- `test/unit/grammar/inflectional_rule_pos_dao_test.dart` — FOUND
- `test/unit/morphology/morphology_dao_inflectional_test.dart` — FOUND
- `test/widget/grammar/rule_editor_multi_pos_test.dart` — FOUND
- `test/widget/grammar/rules_page_pos_grouping_test.dart` — FOUND

**Commits:**
- `c668444` — FOUND (Task 1)
- `8a187be` — FOUND (Task 2)
- `d20e59c` — FOUND (Task 3)
- `cbdd399` — FOUND (Task 4)
- `04b6cd2` — FOUND (Rule 1 auto-fix)
