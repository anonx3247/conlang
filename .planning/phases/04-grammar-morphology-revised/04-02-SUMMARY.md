---
phase: 04-grammar-morphology-revised
plan: 02
subsystem: grammar, morphology
tags: [drift, dao, riverpod, grammar, dimensions, templates, rule-kind, inflectional, pos-resolver]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    plan: 01
    provides: Dimensions / ParadigmCellOverrides tables, FeatureBindings + RuleKind, MorphologicalRules.kind/featureBindings/inputPosId/outputPosId columns
provides:
  - DimensionLevel value type + encodeLevelsJson / decodeLevelsJson helpers
  - dimensionTemplates const catalog (22 entries across 9 feature groups)
  - GrammarDao (@DriftAccessor([Dimensions])) — CRUD for the Dimensions table
  - MorphologyDao kind-aware queries (watchRulesByKind, watchInflectionalRulesForPos, insertRuleWithKind)
  - InflectionalRule view-model wrapping a Drift MorphologicalRule row with parsed FeatureBindings
  - posForLexeme(lexeme, posList) resolver — research recommendation A7
  - Riverpod providers: grammarDaoProvider, dimensionsForPosProvider, dimensionTemplatesProvider, rulesByKindProvider, inflectionalRulesForPosProvider
affects: [04-03, 04-04, 04-05, 04-06, 04-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: thin grammar-scoped Drift DAO (GrammarDao) separate from rule CRUD in MorphologyDao, per D-41"
    - "Pattern: JSON TypeConverter pos subset filter done in Dart on top of the SQL kind filter (featureBindings.pos is not SQL-expressible)"
    - "Pattern: insertRuleWithKind overrides any companion.kind value to guarantee the canonical write path is correct"
    - "Pattern: hand-written plain Provider / StreamProvider (not @riverpod codegen) for grammar-scoped providers that traffic in Drift-generated types, per STATE 01-05"
    - "Pattern: InflectionalRule view-model as the non-Drift consumption surface for the paradigm engine — wraps a MorphologicalRule row with debug assertion guard"
    - "Pattern: two-pass free-text resolver (name then abbreviation, case-insensitive) to avoid migrating Phase 3 Lexemes.partOfSpeech column — research A7"

key-files:
  created:
    - lib/features/grammar/domain/dimension_level.dart
    - lib/features/grammar/domain/inflectional_rule.dart
    - lib/features/grammar/domain/pos_resolver.dart
    - lib/features/grammar/data/dimension_templates.dart
    - lib/features/grammar/data/grammar_dao.dart
    - lib/features/grammar/data/grammar_dao.g.dart
    - lib/features/grammar/data/grammar_providers.dart
    - test/unit/grammar/dimension_templates_test.dart
    - test/unit/grammar/grammar_dao_test.dart
    - test/unit/grammar/pos_resolver_test.dart
    - .planning/phases/04-grammar-morphology-revised/04-02-SUMMARY.md
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/morphology/data/morphology_dao.dart
    - lib/features/morphology/data/morphology_providers.dart

key-decisions:
  - "Template catalog ships 22 const entries (exceeding the >=20 must-have): Gender 4, Number 3, Case 3, Tense 3, Aspect 2, Person 2, Mood 2, Voice 2, Definiteness 1. Every template has a plain-text tooltip description per D-04."
  - "decodeLevelsJson wraps jsonDecode in a try/catch for FormatException and also gates on the decoded type being a List — defense in depth against T-04-07 (hand-edited DB state)."
  - "watchInflectionalRulesForPos applies the kind filter in SQL (via watchRulesByKind) but the pos subset filter in Dart because featureBindings is a JSON TypeConverter column and SQL cannot express an int-in-list subset against a JSON blob."
  - "insertRuleWithKind overrides companion.kind via copyWith(kind: Value(kind.dbString)) rather than requiring callers to set it — the method is the canonical kind-aware insert path and wins any argument conflict."
  - "inflectionalRulesForPosProvider filters inactive rules out before mapping to InflectionalRule view-models — the paradigm engine should never see inactive rules, so the filter is moved up one layer."
  - "posForLexeme uses a two-pass lookup (name first, then abbreviation) rather than a single pass with precedence logic per item — the two-pass form makes the precedence guarantee unambiguous even when multiple rows could match."
  - "posForLexeme trims whitespace before matching so pasted values with trailing spaces still resolve. Not in the plan's explicit test list but added as a free Rule 2 hardening (free-text is user-typed)."
  - "GrammarDao is a thin accessor on a single table (Dimensions) because Phase 4 D-41 locks rule CRUD into MorphologyDao. Splitting dimension CRUD into its own DAO keeps the grammar feature package organizationally self-contained without duplicating rule code."

patterns-established:
  - "Grammar feature subpackage layout: domain/ for value types and view-models, data/ for Drift DAOs + Riverpod providers + const catalogs"
  - "Kind-aware rule queries: always filter by kind in SQL, then apply any JSON-column subset filters in Dart"
  - "Free-text resolver pattern for columns that were deliberately not migrated to FK — two-pass (preferred field first, then fallback field), case-insensitive, trimmed input"

requirements-completed: [GRAM-01, GRAM-02, GRAM-06]

# Metrics
duration: 7min
completed: 2026-04-11
---

# Phase 4 Plan 02: Grammar & Morphology Data Layer Summary

**Dimension template catalog (22 entries), GrammarDao for the Dimensions table, MorphologyDao kind-aware extensions, InflectionalRule view-model, posForLexeme resolver, and Riverpod providers — the data layer Plans 04-03 through 04-07 will consume.**

## Performance

- **Duration:** ~7 minutes
- **Started:** 2026-04-11T00:44:04Z
- **Completed:** 2026-04-11T00:51:30Z
- **Tasks:** 3 (Task 1, Task 2, Task 3) — each with TDD RED/GREEN commits
- **Files modified:** 15 (11 created, 4 modified)
- **Tests added:** 32 (11 dimension_templates + 10 grammar_dao + 11 pos_resolver)

## Accomplishments

- `DimensionLevel` value type with `toJson`/`fromJson`, `copyWith`, structural equality, and `encodeLevelsJson` / `decodeLevelsJson` helpers (defensive against malformed JSON per T-04-07: returns `const []` on empty, non-JSON, non-list, or FormatException input).
- `dimensionTemplates` const catalog ships 22 entries across all 9 required groups. Every entry carries a plain-text description string for the tooltip (D-04 requirement).
- `GrammarDao` (`@DriftAccessor([Dimensions])`) with `watchDimensionsForPos`, `insertDimension`, `updateDimension`, `updateDimensionLevels`, `nextDimensionOrdering`, `nextLevelId`, `deleteDimension`. Registered on the AppDatabase `@DriftDatabase` annotation so `db.grammarDao` is a generated accessor.
- `MorphologyDao` extended with three kind-aware methods:
  - `watchRulesByKind(RuleKind kind)` — SQL filter on the `kind` column, ordered by `ordering` asc.
  - `watchInflectionalRulesForPos(int posId)` — kind filter plus in-Dart pos subset check (empty pos list = applies to all, or contains posId).
  - `insertRuleWithKind(companion, kind)` — canonical kind-aware insert; overrides any `companion.kind` value to guarantee correctness.
- `InflectionalRule` view-model wraps a Drift `MorphologicalRule` row with parsed `FeatureBindings`, with a debug assertion guard against non-inflectional rows. This is the non-Drift consumption surface the 04-03 paradigm engine will use.
- `posForLexeme(Lexeme, List<PartsOfSpeechData>)` resolver (research recommendation A7) — two-pass case-insensitive match (name first, then abbreviation) with trimmed input. Lets the paradigm engine and UI convert a lexeme's free-text POS into a structured `PartsOfSpeechData` row without requiring a Phase 3 schema migration.
- Riverpod providers (hand-written plain `Provider` / `StreamProvider` per STATE 01-05, not `@riverpod` codegen):
  - `grammarDaoProvider` — `GrammarDao?` scoped to the currently-open project database.
  - `dimensionsForPosProvider` — `StreamProvider.family<List<Dimension>, int>` over `watchDimensionsForPos`.
  - `dimensionTemplatesProvider` — stable reference to the const catalog for UI consumption.
  - `rulesByKindProvider` — `StreamProvider.family<List<MorphologicalRule>, RuleKind>` over `watchRulesByKind`.
  - `inflectionalRulesForPosProvider` — `StreamProvider.family<List<InflectionalRule>, int>`, filters inactive rules BEFORE mapping to view-models so the paradigm engine never sees them.
- All pre-existing tests still pass — migration, backup, and feature_bindings suites verified regression-free (54 tests across grammar / migration / backup directories).

## Dimension Template Catalog Coverage

| Group | Templates | Count |
|-------|-----------|-------|
| Gender | mf, mfn, anim_inanim, common_neuter | 4 |
| Number | sg_pl, sg_du_pl, sg_pl_coll | 3 |
| Case | nom_acc_gen_dat, abs_erg_gen_dat, latin_like | 3 |
| Tense | prs_pst, prs_pst_fut, nonfut_fut | 3 |
| Aspect | pfv_ipfv, prog_hab_perf | 2 |
| Person | 1_2_3, incl_excl | 2 |
| Mood | ind_subj_imp, ind_opt_imp | 2 |
| Voice | act_pass, act_mid_pass | 2 |
| Definiteness | def_indef | 1 |
| **Total** | | **22** |

All required plan ids present: `gender.mf`, `gender.mfn`, `number.sg_pl`, `case.nom_acc_gen_dat`, `case.abs_erg_gen_dat`, `tense.prs_pst_fut`, `person.1_2_3`, `mood.ind_subj_imp`, `voice.act_pass`, `definiteness.def_indef`.

## Method Reference

### MorphologyDao (new methods — Phase 4)

| Method | Returns | Purpose |
|--------|---------|---------|
| `watchRulesByKind(RuleKind kind)` | `Stream<List<MorphologicalRule>>` | SQL filter on kind column |
| `watchInflectionalRulesForPos(int posId)` | `Stream<List<MorphologicalRule>>` | Inflectional rules that apply to the given POS (empty pos list = all) |
| `insertRuleWithKind(companion, kind)` | `Future<int>` | Canonical kind-aware insert; overrides companion.kind |

### GrammarDao (new DAO)

| Method | Returns | Purpose |
|--------|---------|---------|
| `watchDimensionsForPos(int posId)` | `Stream<List<Dimension>>` | All dimensions for a POS, ordered by `ordering` asc |
| `nextDimensionOrdering(int posId)` | `Future<int>` | max(ordering) + 1 for inserting at the end, or 0 if empty |
| `nextLevelId(int dimensionId)` | `Future<int>` | max(level.id) + 1 across the dimension's levelsJson, or 1 if empty |
| `insertDimension(companion)` | `Future<int>` | Insert a new dimension, returns generated id |
| `updateDimension(row)` | `Future<bool>` | Replace all fields of an existing dimension row |
| `updateDimensionLevels(dimId, levels)` | `Future<int>` | Encodes `List<DimensionLevel>` and writes to `levels_json` |
| `deleteDimension(int id)` | `Future<int>` | Delete and return row count |

## Riverpod Provider Reference

| Provider | Type | Backing |
|----------|------|---------|
| `grammarDaoProvider` | `Provider<GrammarDao?>` | `currentDatabaseProvider?.grammarDao` |
| `dimensionsForPosProvider` | `StreamProvider.family<List<Dimension>, int>` | `grammarDao.watchDimensionsForPos(posId)` |
| `dimensionTemplatesProvider` | `Provider<List<DimensionTemplate>>` | const `dimensionTemplates` |
| `rulesByKindProvider` | `StreamProvider.family<List<MorphologicalRule>, RuleKind>` | `morphologyDao.watchRulesByKind(kind)` |
| `inflectionalRulesForPosProvider` | `StreamProvider.family<List<InflectionalRule>, int>` | `morphologyDao.watchInflectionalRulesForPos(posId)` -> filter active -> `InflectionalRule.fromDbRow` |

## Task Commits

Each task was TDD-committed (RED test, then GREEN implementation):

1. **Task 1 RED** — `35b73ae` test(04-02): add failing tests for DimensionLevel and dimension_templates (RED)
2. **Task 1 GREEN** — `58d9ecb` feat(04-02): implement DimensionLevel value type and dimensionTemplates catalog
3. **Task 2 RED** — `ad782ca` test(04-02): add failing tests for GrammarDao and MorphologyDao kind-aware queries (RED)
4. **Task 2 GREEN** — `7f69d08` feat(04-02): add GrammarDao, extend MorphologyDao with kind-aware queries, wire providers
5. **Task 3 RED** — `efa90be` test(04-02): add failing tests for posForLexeme resolver (RED)
6. **Task 3 GREEN** — `bb86612` feat(04-02): implement posForLexeme resolver (research A7)

## Test Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test/unit/grammar/feature_bindings_converter_test.dart | 8 | PASSING (04-01 existing) |
| test/unit/grammar/dimension_templates_test.dart | 11 | PASSING (new) |
| test/unit/grammar/grammar_dao_test.dart | 10 | PASSING (new) |
| test/unit/grammar/pos_resolver_test.dart | 11 | PASSING (new) |
| test/integration/migration_v7_to_v8_test.dart | 9 | PASSING (regression check) |
| test/unit/project/project_backup_test.dart | 5 | PASSING (regression check) |
| **Total new tests this plan** | **32** | **PASSING** |
| **Regression-verified pre-existing tests** | **22** | **PASSING** |

## Code Generation

- `dart run build_runner build --delete-conflicting-outputs` was run once after Task 2 to:
  - Generate `lib/features/grammar/data/grammar_dao.g.dart` (`_$GrammarDaoMixin`)
  - Update `lib/db/app_database.g.dart` with the `grammarDao` accessor on `AppDatabase`
- Drift codegen continues to warn about duplicate `morphologicalRulesRefs` on `$PartsOfSpeechTable` — this is the pre-existing 04-01 warning (three FKs from MorphologicalRules to PartsOfSpeech: posId, inputPosId, outputPosId). Not a 04-02 regression. Resolvable in a follow-up via `@ReferenceName()` annotations; not required for the data layer to work.

## Analyzer

`flutter analyze lib/features/grammar/ lib/features/morphology/data/morphology_dao.dart lib/features/morphology/data/morphology_providers.dart` — no issues.

`flutter analyze lib/db/app_database.dart` shows 1 pre-existing info-level `annotate_overrides` hint on `lexemeDao get` (unchanged from 04-01 base, not introduced by this plan).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing hardening] decodeLevelsJson wraps jsonDecode in try/catch**

- **Found during:** Task 1 (implementing decodeLevelsJson)
- **Issue:** Plan snippet handled the "not a List" case but `jsonDecode` itself throws `FormatException` on non-JSON input. The plan test "decodeLevelsJson returns empty list on malformed input" passes `'not a json'` which would throw from `jsonDecode` before the type check.
- **Fix:** Wrapped `jsonDecode` + subsequent `whereType<Map>().map(...)` in a `try` block that catches `FormatException` and returns `const []`. Also kept the explicit `if (decoded is! List)` type check as defense in depth.
- **Files modified:** lib/features/grammar/domain/dimension_level.dart
- **Verification:** dimension_templates_test "decodeLevelsJson returns empty list on malformed input" passes for `''`, `'not a json'`, and `'{}'`.
- **Committed in:** 58d9ecb (Task 1 GREEN)

**2. [Rule 2 - Missing hardening] posForLexeme trims whitespace**

- **Found during:** Task 3 (implementing the resolver)
- **Issue:** The plan's matching rules lowercase the input but do not trim. Real free-text entry from users commonly has trailing spaces (paste from other apps, accidental double spaces). The `toLowerCase().trim()` pair is cheap and prevents a silent no-match.
- **Fix:** Added `.trim()` after `.toLowerCase()`, then an extra empty-after-trim guard. Added an extra test `'trims whitespace before matching'` covering `'  Noun  '`.
- **Files modified:** lib/features/grammar/domain/pos_resolver.dart, test/unit/grammar/pos_resolver_test.dart
- **Verification:** pos_resolver_test 'trims whitespace before matching' passes.
- **Committed in:** bb86612 (Task 3 GREEN) / efa90be (Task 3 RED includes the extra test)

**3. [Rule 3 - Blocking] Test import needed MorphologyDao class explicitly**

- **Found during:** Task 2 (first RED run of grammar_dao_test.dart)
- **Issue:** The plan's test skeleton relied on `MorphologyDao` being visible via the `package:conlang_workbench/db/app_database.dart` import, but `MorphologyDao` is defined in `morphology_dao.dart` (a DAO file, not re-exported by app_database.dart).
- **Fix:** Added `import 'package:conlang_workbench/features/morphology/data/morphology_dao.dart';` to the test file.
- **Files modified:** test/unit/grammar/grammar_dao_test.dart
- **Verification:** Test compiles and runs. All 10 grammar_dao tests pass.
- **Committed in:** ad782ca (Task 2 RED)

**4. [Rule 3 - Blocking] Test posNounId used instead of hardcoded 1/2**

- **Found during:** Task 2 (wiring the test for insertRuleWithKind + watchInflectionalRulesForPos)
- **Issue:** The plan's test skeleton used hardcoded POS id `1` in `FeatureBindings(pos: [1])`, but Drift `autoIncrement()` rowids are not guaranteed to start at 1 across all test runs (they are in SQLite memory, but this creates brittle coupling). Also the plan test used `[2]` as the "other POS" id without actually inserting that POS row.
- **Fix:** Captured the inserted POS row id into `posNounId` and used it in the feature bindings. For the "other POS" test case, used id `999` (a POS id that's guaranteed never to exist because only one POS is seeded in setUp).
- **Files modified:** test/unit/grammar/grammar_dao_test.dart
- **Verification:** Test is robust to autoIncrement variations.
- **Committed in:** ad782ca (Task 2 RED) / 7f69d08 (Task 2 GREEN)

---

**Total deviations:** 4 auto-fixed (2 Rule 2 hardening, 2 Rule 3 blocking). No Rule 4 architectural decisions required. No scope changes.

## Issues Encountered

- **Pre-existing drift codegen warning about `morphologicalRulesRefs`:** Already logged in 04-01-SUMMARY. Drift warns that the three FKs from MorphologicalRules to PartsOfSpeech (posId, inputPosId, outputPosId) collide on the auto-generated manager refs name. This is a warning only — Drift skips that specific manager filter generation, everything else works. Not a 04-02 regression.
- **Pre-existing info-level `annotate_overrides` on `lexemeDao get` in app_database.dart:** Present on the 04-01 base commit. Out of scope for this plan.

## User Setup Required

None — data layer only, no UI, no migrations. Plan 04-02 is transparent to end users until 04-03+ wire the UI.

## Next Plan Readiness

- Plan 04-03 (Paradigm Engine) can import `InflectionalRule` + `FeatureBindings` and consume `inflectionalRulesForPosProvider` directly. The `posForLexeme` resolver lets it look up a lexeme's POS to pick the right rule set.
- Plan 04-04 (Grammar Shell + POS + Typology) can consume `grammarDaoProvider`, `dimensionsForPosProvider`, and `dimensionTemplatesProvider` for the dimension manager UI.
- Plan 04-05 (Inflectional Rule Editor) can call `morphologyDao.insertRuleWithKind(..., RuleKind.inflectional)` and subscribe to `rulesByKindProvider(RuleKind.inflectional)`.
- Plan 04-06 (Paradigm Viewer) is entirely downstream of the engine + data layer — it reads, no new DAO methods needed from this plan.
- Plan 04-07 (Lexicon Derivations + word detail embed) can subscribe to `rulesByKindProvider(RuleKind.derivational)` for the derivational rule picker and use `posForLexeme` to gate which derivational rules are valid for a given lexeme.

## Threat Flags

None — this plan introduces only data-layer code (DAOs, value types, providers, const catalogs) and a stateless resolver function. All mitigations from the plan's `<threat_model>` are covered:

- T-04-07 (Tampering on corrupted levelsJson) -> mitigated by `decodeLevelsJson` returning `const []` on empty / non-JSON / non-list / FormatException inputs (dimension_templates_test "decodeLevelsJson returns empty list on malformed input").
- T-04-08 (Information disclosure via posForLexeme) -> accepted per plan; single-user local tool.
- T-04-09 (DoS via pathological nextLevelId input) -> accepted per plan; bounded by the D-06 soft warning at >100 total cells in the UI layer.

No new network endpoints, no new auth paths, no new trust boundaries, no new schema.

## Self-Check: PASSED

All claimed files and commits verified to exist.

**Files (15):**
- FOUND: lib/features/grammar/domain/dimension_level.dart
- FOUND: lib/features/grammar/domain/inflectional_rule.dart
- FOUND: lib/features/grammar/domain/pos_resolver.dart
- FOUND: lib/features/grammar/data/dimension_templates.dart
- FOUND: lib/features/grammar/data/grammar_dao.dart
- FOUND: lib/features/grammar/data/grammar_dao.g.dart
- FOUND: lib/features/grammar/data/grammar_providers.dart
- FOUND: test/unit/grammar/dimension_templates_test.dart
- FOUND: test/unit/grammar/grammar_dao_test.dart
- FOUND: test/unit/grammar/pos_resolver_test.dart
- FOUND: .planning/phases/04-grammar-morphology-revised/04-02-SUMMARY.md
- FOUND: lib/db/app_database.dart
- FOUND: lib/db/app_database.g.dart
- FOUND: lib/features/morphology/data/morphology_dao.dart
- FOUND: lib/features/morphology/data/morphology_providers.dart

**Commits (6):**
- FOUND: 35b73ae test(04-02): add failing tests for DimensionLevel and dimension_templates (RED)
- FOUND: 58d9ecb feat(04-02): implement DimensionLevel value type and dimensionTemplates catalog
- FOUND: ad782ca test(04-02): add failing tests for GrammarDao and MorphologyDao kind-aware queries (RED)
- FOUND: 7f69d08 feat(04-02): add GrammarDao, extend MorphologyDao with kind-aware queries, wire providers
- FOUND: efa90be test(04-02): add failing tests for posForLexeme resolver (RED)
- FOUND: bb86612 feat(04-02): implement posForLexeme resolver (research A7)
