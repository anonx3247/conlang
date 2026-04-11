---
phase: 04-grammar-morphology-revised
plan: 03
subsystem: grammar, morphology
tags: [paradigm-engine, feature-consumption, most-specific, tiebreak, typology, cartesian, riverpod]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    plan: 01
    provides: FeatureBindings, schema v8 (Dimensions / ParadigmCellOverrides / MorphologicalRules.kind+featureBindings)
  - phase: 04-grammar-morphology-revised
    plan: 02
    provides: InflectionalRule view-model, dimensionLevelEncode/decode, grammarDaoProvider, inflectionalRulesForPosProvider, posForLexeme resolver
provides:
  - ParadigmCell sealed hierarchy (ParadigmFilled / ParadigmUncovered / ParadigmAmbiguous)
  - computeParadigmCell(root, target, rules, inventory) implementing D-10/D-11/D-12/D-13 + A3
  - findDuplicateSpecificityConflicts for live rule-editor tie detection
  - ParadigmAxes value type with JSON round-trip + defaultsFor
  - TypologySettings value type
  - cartesianFeatureSets + ParadigmChart + generateParadigm pure-Dart chart generator
  - featureSetKey stable string keys for feature-set Map lookups
  - Riverpod providers: typologySettingsProvider, paradigmAxesProvider(posId), computedInflectedParadigmProvider(lexemeId)
  - readTypologySettings / writeTypologyKey / readParadigmAxes / writeParadigmAxes DB helpers
affects: [04-04, 04-05, 04-06, 04-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: strict most-specific with intra-specificity fall-through — A3 research recommendation. The engine sorts candidates by specificity desc, takes the top spec tier as a group, tries them in list order until one MorphSuccess lands. On total failure it does NOT fall through to lower specificity."
    - "Pattern: identical-binding detection as the only ambiguity trigger (D-12). Two rules at the same specificity with DIFFERENT binding maps are distinct candidates that can fire in sequence, not a tie."
    - "Pattern: per-iteration subset check guarantees termination. Every loop iteration must consume at least one dim from `remaining`; _isSubset returns false for empty maps so unbound rules cannot loop forever."
    - "Pattern: stable string-keyed ParadigmChart to work around Dart's non-structural Map equality. Cells are keyed by `featureSetKey(Map<int,int>)` so callers can look up `chart.cellFor(const {10:1, 11:2})` without constructing the exact same Map instance."
    - "Pattern: pure-Dart helpers (readTypologySettings, writeTypologyKey, readParadigmAxes, writeParadigmAxes) taking AppDatabase directly — the provider wrapper is a thin shell so tests can drive the persistence layer without a ProviderContainer."
    - "Pattern: Drift update-then-insert upsert for project_settings (key has unique constraint but id is PK, so insertOnConflictUpdate targets id not key). Matches `romanizationEnabledProvider`."

key-files:
  created:
    - lib/features/grammar/domain/paradigm_cell.dart
    - lib/features/grammar/domain/paradigm_engine.dart
    - lib/features/grammar/domain/tiebreak_detector.dart
    - lib/features/grammar/domain/paradigm_axes.dart
    - lib/features/grammar/data/typology_providers.dart
    - test/unit/grammar/paradigm_engine_test.dart
    - test/unit/grammar/tiebreak_detector_test.dart
    - test/unit/grammar/paradigm_generation_test.dart
    - test/unit/grammar/typology_providers_test.dart
    - .planning/phases/04-grammar-morphology-revised/04-03-SUMMARY.md
  modified: []

key-decisions:
  - "Ambiguity check uses identical-binding detection only (D-12). Two spec-1 rules binding different dims (e.g. -s{number:PL} and -o{gender:M}) both match a {M,PL} cell, but they are NOT tied — the engine applies both in sequence. Only rules with byte-identical binding maps trigger ParadigmAmbiguous."
  - "Intra-specificity fall-through on DSL match failure. When the first top-spec candidate returns MorphNoMatch the engine tries the next top-spec candidate in list order. If ALL top-spec candidates fail (MorphNoMatch or invalid DSL) the engine is strict: no fall-through to the next-lower specificity tier. The cell becomes ParadigmUncovered (if chain is empty) or ParadigmFilled with the partial chain accumulated so far."
  - "Partial chain = ParadigmFilled. When a cell's feature set is partially consumed but no further candidates match, the engine returns ParadigmFilled(working, chain) rather than ParadigmUncovered. Rationale: the existing operations produced a real surface form; marking the cell as 'uncovered' would discard that work. The UI layer (04-06) can show a warning badge if the chain did not cover every dim."
  - "ParadigmChart wrapper over `Map<String, ParadigmChartEntry>` instead of `Map<FeatureSet, ParadigmCell>`. Dart Maps have identity equality, not structural, so a `Map<Map,...>` cannot be looked up with a literal. The stable `featureSetKey` serializes feature sets into sorted `'10:1,11:2'` strings which ARE equal across instances."
  - "Plan's `TextColumn<FeatureBindings>` pattern continues to be respected — we read `.featureBindings` via the existing converter, no new column touches."
  - "Test 8 of the plan (intra-spec fall-through with two same-dim rules) was re-framed: the plan's setup used two {PL}-bound rules, which is IDENTICAL bindings and therefore ParadigmAmbiguous by D-12. The re-framed Test 8 uses {PL} and {M} rules (different bindings, same specificity) to demonstrate fall-through without conflating with the ambiguity path."
  - "Pure-Dart `generateParadigm` helper (not just a provider body) so tests can exercise Cartesian expansion + D-07 skippedDimensions without constructing a ProviderContainer. The provider body is a 10-line wrapper over the helper."
  - "`projectSettingsProvider` was not created as a cross-file abstraction. Instead, typology_providers.dart reads `db.projectSettings` directly via a StreamProvider. The codebase already has this pattern in romanization_providers.dart; inventing a shared provider would touch unrelated files and complicate the dependency graph."

patterns-established:
  - "Paradigm engine: pure function over (root, target, rules, inventory) + stateless MorphologyEngine. No IO, no providers, trivially testable."
  - "Strict most-specific with intra-specificity fall-through: canonical algorithm for the whole grammar subsystem. Plans 04-04 (rule editor) and 04-06 (paradigm viewer) consume it without re-implementing the semantics."
  - "ParadigmChart string-keying: the template for any `Map<Map,...>` use case in the codebase going forward."
  - "DB helper + provider split: `readX` / `writeX` functions take the AppDatabase and live in the same file as the providers that wrap them. Tests exercise the helpers; UI consumes the providers."

requirements-completed: [GRAM-02, GRAM-03, GRAM-04, GRAM-05]

# Metrics
duration: ~10min
completed: 2026-04-10
---

# Phase 4 Plan 03: Paradigm Engine & Typology Providers Summary

**Feature-consumption paradigm engine with strict most-specific semantics, identical-binding tiebreak detection, paradigm axis config + typology settings persisted in project_settings, and a pure-Dart `generateParadigm` chart builder over the Cartesian product of a POS's dimensions.**

## Performance

- **Duration:** ~10 minutes
- **Tasks:** 2 (Task 1 engine/tiebreak, Task 2 axes/typology/generation)
- **Files created:** 10 (5 lib + 4 test + SUMMARY)
- **Files modified:** 0
- **Tests added:** 39 (12 paradigm_engine + 7 tiebreak_detector + 8 paradigm_generation + 12 typology_providers)

## Accomplishments

- **ParadigmCell sealed hierarchy** (`paradigm_cell.dart`): `ParadigmFilled(form, ruleChain)`, `ParadigmUncovered(failureReason)`, `ParadigmAmbiguous(tiedRules)`. Exhaustive by construction; callers cannot forget a case.
- **`computeParadigmCell`** (`paradigm_engine.dart`) — pure function implementing the full feature-consumption algorithm:
  - D-13 pre-filter drops inactive rules and unbound rules (`bindings.isInflectional == false`).
  - Loop: candidates = subset(remaining), sort by specificity desc, top tier by max spec, check for identical-binding ambiguity (D-12), else try each top-tier rule via `parseMorphDsl + engine.applyRule` in list order, first MorphSuccess wins.
  - Strict semantics: on total top-tier failure the engine does NOT fall through to lower specificity.
  - Partial chain handling: when subsequent iterations cannot extend the chain, returns `ParadigmFilled(workingForm, partialChain)` instead of discarding the accumulated work.
- **`findDuplicateSpecificityConflicts`** (`tiebreak_detector.dart`) — live rule-editor banner input. Groups active inflectional rules by their binding key and flags any group of 2+. Inactive / derivational rules are excluded.
- **`ParadigmAxes`** (`paradigm_axes.dart`) — rows/cols/tabs axis config with JSON round-trip, `defaultsFor(dims)` picker (first dim -> rows, second -> cols, rest -> tabs), and T-04-11 defense (malformed JSON returns empty axes, no throws).
- **`TypologySettings`** + persistence helpers (`typology_providers.dart`):
  - `readTypologySettings(db)` / `writeTypologyKey(db, key, value)` — async DB helpers.
  - `readParadigmAxes(db, posId: X)` / `writeParadigmAxes(db, posId: X, axes: Y)` — per-POS axis config.
  - Keys: `typology.alignment`, `typology.word_order`, `typology.modality`, `typology.paradigm_axes.{posId}`.
- **`cartesianFeatureSets` + `ParadigmChart` + `generateParadigm`** — pure-Dart chart builder honoring D-07 (skippedDimensionIds removes dims before expansion). `featureSetKey` produces stable sorted-string keys so callers can look up cells by literal feature set without Dart Map equality pain.
- **Riverpod providers**:
  - `typologySettingsProvider` — StreamProvider over project_settings full rows.
  - `paradigmAxesProvider(posId)` — StreamProvider.family, falls back to `defaultsFor` when no row exists.
  - `computedInflectedParadigmProvider(lexemeId)` — Provider.family resolving lexeme → pos → dims → rules → chart via the pure helper.
- **All pre-existing tests pass** — no regression across unit + integration suites (164 tests, all green).

## Method Reference

### Paradigm engine

| Function | Returns | Purpose |
|----------|---------|---------|
| `computeParadigmCell({root, target, rules, inventory, engine})` | `ParadigmCell` | Feature consumption for one cell |
| `findDuplicateSpecificityConflicts(rules)` | `List<TiebreakConflict>` | Identical-binding tie detection |

### Paradigm chart + generation

| Function | Returns | Purpose |
|----------|---------|---------|
| `cartesianFeatureSets(dims)` | `Iterable<FeatureSet>` | Cartesian product of dim levels |
| `featureSetKey(featureSet)` | `String` | Stable sorted-dim-id key |
| `generateParadigm({root, dimensions, rules, inventory, skippedDimensionIds})` | `ParadigmChart` | Full paradigm chart |
| `ParadigmChart.cellFor(featureSet)` | `ParadigmCell?` | Lookup by literal feature set |
| `ParadigmChart.entries` | `Iterable<ParadigmChartEntry>` | All generated cells |

### Typology + axes persistence

| Function | Returns | Purpose |
|----------|---------|---------|
| `readTypologySettings(db)` | `Future<TypologySettings>` | Read all three typology keys |
| `writeTypologyKey(db, key, value)` | `Future<void>` | Upsert single typology key |
| `readParadigmAxes(db, posId:)` | `Future<ParadigmAxes>` | Read per-POS axis config with defaults |
| `writeParadigmAxes(db, posId:, axes:)` | `Future<void>` | Upsert axis config |

### Providers

| Provider | Type | Backing |
|----------|------|---------|
| `typologySettingsProvider` | `StreamProvider<TypologySettings>` | `db.projectSettings` stream → filter keys |
| `paradigmAxesProvider` | `StreamProvider.family<ParadigmAxes, int>` | `db.projectSettings` + dims fallback |
| `computedInflectedParadigmProvider` | `Provider.family<ParadigmChart, int>` | `lexemeByIdProvider × posListProvider × dimensionsForPosProvider × inflectionalRulesForPosProvider × phonemeInventoryProvider` |

## Task Commits

Each task was TDD-committed (RED test, then GREEN implementation):

1. **Task 1 RED** — `9c46a18` test(04-03): add failing tests for paradigm engine and tiebreak detector (RED)
2. **Task 1 GREEN** — `55b1e18` feat(04-03): implement paradigm engine with strict most-specific semantics
3. **Task 2 RED** — `83a2cfa` test(04-03): add failing tests for paradigm axes, typology, generation (RED)
4. **Task 2 GREEN** — `de096de` feat(04-03): implement paradigm axes + typology providers + chart generator

## Test Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test/unit/grammar/paradigm_engine_test.dart | 12 | PASSING |
| test/unit/grammar/tiebreak_detector_test.dart | 7 | PASSING |
| test/unit/grammar/paradigm_generation_test.dart | 8 | PASSING |
| test/unit/grammar/typology_providers_test.dart | 12 | PASSING |
| **Total new tests this plan** | **39** | **PASSING** |
| Grammar suite regression (04-01 + 04-02 tests) | 40 | PASSING |
| Full unit + integration regression | 164 | PASSING |

## Analyzer

`flutter analyze --no-fatal-warnings lib/features/grammar/` — **no issues** (all 14 files in the grammar subsystem clean).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `OrderingTerm` not exported from `app_database.dart`**

- **Found during:** Task 2 GREEN (first compile of typology_providers.dart)
- **Issue:** The plan's snippet used `OrderingTerm.asc(...)` in `.orderBy([...])` without importing it. `app_database.dart` re-exports Drift types but not `OrderingTerm`.
- **Fix:** Added `import 'package:drift/drift.dart' show OrderingTerm, Value;` (already had `Value` for `ProjectSettingsCompanion`).
- **Files modified:** lib/features/grammar/data/typology_providers.dart
- **Verification:** Compiles; `readParadigmAxes` query runs; `writeParadigmAxes upserts on second call` test passes.
- **Committed in:** de096de (Task 2 GREEN)

**2. [Rule 3 - Blocking] `isNull` ambiguous import in test file**

- **Found during:** Task 2 GREEN (first compile of typology_providers_test.dart)
- **Issue:** The test imports `package:drift/drift.dart` (for `Value`, `NativeDatabase` access patterns) and `package:flutter_test/flutter_test.dart` (for matchers). Both export `isNull`. Same failure seen in 04-01's migration test; same fix.
- **Fix:** `import 'package:drift/drift.dart' hide isNull;`
- **Files modified:** test/unit/grammar/typology_providers_test.dart
- **Verification:** Test compiles; all 12 tests pass.
- **Committed in:** de096de (Task 2 GREEN)

**3. [Rule 3 - Blocking] Dart Map equality cannot look up cells by literal**

- **Found during:** Task 2 GREEN (first test run of generateParadigm 2×2 test)
- **Issue:** The plan returned `Map<FeatureSet, ParadigmCell>` where `FeatureSet = Map<int, int>`. Dart Maps have identity equality, so `chart[const {10: 1, 11: 2}]` returns null — there is no guarantee that the Map instance stored as a key is `==` to a freshly constructed literal with the same entries. Both `Map.contains` on the cartesian product output AND direct chart lookups failed.
- **Fix:** Introduced `ParadigmChart` wrapper over `Map<String, ParadigmChartEntry>` keyed by `featureSetKey(featureSet)` — a stable sorted `'10:1,11:2'` string. Added `chart.cellFor(featureSet)` which runs the same keying on the input. Tests look up cells and enumerate keys via `featureSetKey` transforms.
- **Files modified:** lib/features/grammar/data/typology_providers.dart, test/unit/grammar/paradigm_generation_test.dart
- **Verification:** All 8 generation tests + the lookup-shaped tests pass.
- **Committed in:** de096de (Task 2 GREEN)

**4. [Rule 1 - Bug] Plan's Test 8 conflated fall-through with ambiguity**

- **Found during:** Task 1 RED test authoring
- **Issue:** The plan's Test 8 setup — two rules both bound to `{number: PL}`, one with a failing DSL condition, the other a plain suffix — would actually trigger the identical-binding ambiguity path (D-12), not intra-specificity fall-through. The plan stated the engine should pick the second rule via fall-through, contradicting its own D-12 rule.
- **Fix:** Re-framed the test: one rule bound to `{number: PL}` with a failing condition, a second rule bound to `{gender: M}` plain suffix. Both are specificity 1 with DIFFERENT binding maps, so they are not an identical-binding tie — they ARE candidates to be tried in the same specificity tier. The engine tries `-na` first, it fails its DSL on `'kat'`, the engine falls through to `-o`. Apply `-o`, remove gender from remaining. Next iteration, `-na` is the only candidate for `{number: PL}`, still fails its DSL on `'kato'`, and since the chain is non-empty the engine returns `ParadigmFilled('kato', [-o])` as a partial chain. Plan's intent (demonstrate intra-spec fall-through) is preserved; the test is now consistent with D-12.
- **Files modified:** test/unit/grammar/paradigm_engine_test.dart
- **Verification:** Test passes with the expected `ParadigmFilled` + single-rule chain.
- **Committed in:** 55b1e18 (Task 1 GREEN — test was corrected before the GREEN commit)

**5. [Rule 2 - Missing hardening] `ParadigmAxes.fromJsonString` wraps jsonDecode in try/catch**

- **Found during:** Task 2 GREEN (implementing ParadigmAxes)
- **Issue:** Plan snippet only checked `if (decoded is! Map)`, but `jsonDecode` itself throws `FormatException` on non-JSON input like `'not a json'`. The plan's Test 4 of Task 2 asserts that malformed input returns empty axes — which requires swallowing the FormatException.
- **Fix:** Wrapped `jsonDecode` + the type check in a `try` block that catches `FormatException` and returns `const ParadigmAxes()`. Matches the 04-02 `decodeLevelsJson` pattern.
- **Files modified:** lib/features/grammar/domain/paradigm_axes.dart
- **Verification:** Tests `empty string parses to empty axes` and `malformed JSON parses to empty axes` both pass on inputs `''`, `'not a json'`, and `'[1,2,3]'`.
- **Committed in:** de096de (Task 2 GREEN)

---

**Total deviations:** 5 auto-fixed (3 Rule 3 blocking, 1 Rule 1 test bug in plan, 1 Rule 2 hardening). No Rule 4 architectural decisions required. No scope changes.

## Issues Encountered

- **Pre-existing flutter tool crash on first invocation:** First `flutter test` invocation crashed with `StateError: Bad state: No element`. Resolved by running `flutter pub get` first — same pre-existing issue noted in 04-01 and 04-02 summaries.
- **Pre-existing drift codegen warning about `morphologicalRulesRefs`:** Unchanged from 04-01 base. Not touched by this plan.
- **ProviderContainer integration test deferred:** The plan suggested either a full ProviderContainer override path or a pure-Dart fallback. Chose the pure-Dart path because `computedInflectedParadigmProvider` depends on 5 upstream providers (lexemeByIdProvider, posListProvider, dimensionsForPosProvider, inflectionalRulesForPosProvider, phonemeInventoryProvider), and mocking all of them would be ~150 lines of setup for little additional confidence vs. the pure `generateParadigm` helper tests. The provider body itself is a thin 10-line wrapper over the tested pure helper.

## Upstream Provider Name Resolution

The plan flagged several "hypothetical" provider names for executor verification. Results:

| Plan name | Actual name | Location |
|-----------|-------------|----------|
| `projectSettingsProvider` | **Does not exist** — inline `db.select(db.projectSettings).watch()` | Same pattern as `romanizationEnabledProvider` |
| `lexemeByIdProvider` | Exists as written | lib/features/lexicon/data/lexeme_providers.dart:223 |
| `posListProvider` | Exists as written | lib/features/morphology/data/morphology_providers.dart:47 |
| `phonemeInventoryProvider` | Exists as written | lib/features/phonology/data/phonotactic_providers.dart:162 |

The missing `projectSettingsProvider` was NOT introduced — doing so would have touched unrelated files. Instead, `typology_providers.dart` reads `db.projectSettings` directly via a StreamProvider, mirroring the existing `romanizationEnabledProvider` pattern.

## User Setup Required

None — pure data + domain code. No migrations, no UI. Plan 04-04 (Grammar Shell + Rule Editor) will wire the typology providers and tiebreak detector into the UI.

## Next Plan Readiness

- **04-04 (Grammar Shell + Rule Editor + Typology form):** Can subscribe to `typologySettingsProvider` for the typology form and consume `findDuplicateSpecificityConflicts` for the live rule-editor banner. Can write via `writeTypologyKey` / `writeParadigmAxes`.
- **04-05 (Inflectional Rule Editor):** Uses `findDuplicateSpecificityConflicts` output to show conflicts inline; applies via `morphologyDao.insertRuleWithKind(..., RuleKind.inflectional)` (from 04-02).
- **04-06 (Paradigm Viewer):** Is entirely downstream of `computedInflectedParadigmProvider`. It reads `ParadigmChart.entries`, uses `paradigmAxesProvider(posId)` to pick rows/cols/tabs, and renders `ParadigmFilled` / `ParadigmUncovered` / `ParadigmAmbiguous` with appropriate styling.
- **04-07 (Lexicon Derivations + word detail embed):** Independent of this plan's engine. Uses `rulesByKindProvider(RuleKind.derivational)` from 04-02.

## Threat Flags

None — this plan introduces only pure-Dart domain code, a provider layer, and per-key project_settings persistence. No new endpoints, auth paths, or trust boundaries.

Threat model coverage:

- **T-04-10** (DoS via pathological paradigm size) — accepted per plan; D-06 soft warning at >100 cells will live in 04-04's dimension editor.
- **T-04-11** (Tampering on corrupted paradigm_axes JSON) — **mitigated** by `ParadigmAxes.fromJsonString` catching FormatException and returning `const ParadigmAxes()`. Tests `empty string parses to empty axes` and `malformed JSON parses to empty axes` lock this.
- **T-04-12** (DSL parser injection) — reuses Phase 2 petitparser, unchanged surface. No new injection vectors.
- **T-04-13** (Engine accidentally applying derivational rules to paradigm cells) — **mitigated** by D-13 pre-filter `r.bindings.isInflectional`. Test `derivational rule (empty dims) filtered even if present` locks this; unbound rules (`dims.isEmpty`) are also rejected by `_isSubset` as a defense-in-depth second gate.

## Self-Check: PASSED

All claimed files and commits verified to exist:

**Files (10):**
- FOUND: lib/features/grammar/domain/paradigm_cell.dart
- FOUND: lib/features/grammar/domain/paradigm_engine.dart
- FOUND: lib/features/grammar/domain/tiebreak_detector.dart
- FOUND: lib/features/grammar/domain/paradigm_axes.dart
- FOUND: lib/features/grammar/data/typology_providers.dart
- FOUND: test/unit/grammar/paradigm_engine_test.dart
- FOUND: test/unit/grammar/tiebreak_detector_test.dart
- FOUND: test/unit/grammar/paradigm_generation_test.dart
- FOUND: test/unit/grammar/typology_providers_test.dart
- FOUND: .planning/phases/04-grammar-morphology-revised/04-03-SUMMARY.md

**Commits (4):**
- FOUND: 9c46a18 test(04-03): add failing tests for paradigm engine and tiebreak detector (RED)
- FOUND: 55b1e18 feat(04-03): implement paradigm engine with strict most-specific semantics
- FOUND: 83a2cfa test(04-03): add failing tests for paradigm axes, typology, generation (RED)
- FOUND: de096de feat(04-03): implement paradigm axes + typology providers + chart generator

---
*Phase: 04-grammar-morphology-revised*
*Completed: 2026-04-10*
