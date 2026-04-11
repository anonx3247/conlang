---
phase: 04-grammar-morphology-revised
plan: 08
subsystem: database
tags: [drift, sqlite, migration, schema, gap-closure, markers, junction-tables, etymology]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    provides: v8 schema (Dimensions, ParadigmCellOverrides, MorphologicalRules.kind/featureBindings/inputPosId/outputPosId, Lexemes.skippedDimensionsJson)
provides:
  - Drift schema v9 with Markers, InflectionalRulePOS, LexemeParents tables
  - MorphologicalRules.autoApply column (D-59) — derivational auto-promote flag
  - Lexemes.derivedFromLexemeId + derivedViaRuleId (D-57, D-58) — rule-linked derivations
  - Lexemes.rootOnlyViaDerivations (D-63) — muted-in-dictionary filter
  - v8->v9 onUpgrade data migration with InflectionalRulePOS backfill
  - v9 beforeOpen safety-net (CREATE TABLE IF NOT EXISTS + idempotent ALTERs)
  - InflectionalRulePOS.tableName override (Drift snake-case fix for all-caps suffix)
affects: [04-09, 04-10, 04-11, 04-12, 04-13, 04-14]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: v8->v9 migration reuses the 04-01 shape — customSelect raw SQL in onUpgrade, idempotent try/catch beforeOpen safety net, mirror-structured v8 seed stub in integration test"
    - "Pattern: Junction table with composite primary key via `@override Set<Column> get primaryKey => {colA, colB}` (used by InflectionalRulePOS and LexemeParents)"
    - "Pattern: Override `String get tableName` on a Drift Table class when the Dart class name contains an acronym that Drift's auto-snake mangles (InflectionalRulePOS -> inflectional_rule_p_o_s without override)"
    - "Pattern: Backfill junction rows during migration via raw customSelect + customStatement('INSERT OR IGNORE INTO ...') rather than typed Drift insert — robust against v8-row / v9-class shape mismatch"

key-files:
  created:
    - test/integration/migration_v8_to_v9_test.dart
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/grammar/data/paradigm_cell_override_dao.g.dart
    - lib/features/lexicon/data/lexeme_dao.g.dart
    - lib/router/app_router.g.dart
    - test/integration/migration_v7_to_v8_test.dart
    - test/lexicon/lexeme_filter_test.dart
    - test/unit/grammar/pos_resolver_test.dart

key-decisions:
  - "v9 onUpgrade is additive-only (new tables + new columns + junction backfill). Pre-v9 rows keep all their values; new nullable columns come in as NULL, new BoolColumn.withDefault(false) columns come in as 0."
  - "InflectionalRulePOS backfill seeds one junction row per existing MorphologicalRules row where kind='inflectional' AND input_pos_id IS NOT NULL. Derivational rules are NOT backfilled (D-55 — the junction is scoped to inflectional). Rows with null input_pos_id are skipped (no junction row created)."
  - "Legacy MorphologicalRules.inputPosId column kept on v9+ for read-only compatibility; downstream callers query the InflectionalRulePOS junction instead. The legacy column is NOT updated when the junction changes — treat as stale convenience cache."
  - "InflectionalRulePOS class name contains the acronym 'POS' which Drift's camel->snake converter mangles to 'inflectional_rule_p_o_s'. Fixed by overriding `String get tableName => 'inflectional_rule_pos'` on the Table class so the auto-generated CREATE TABLE, the onUpgrade addColumn call, the beforeOpen safety-net CREATE TABLE IF NOT EXISTS, and the backfill INSERT all agree on `inflectional_rule_pos`."
  - "LexemeParents uses `@DataClassName('LexemeParentRow')` to avoid the awkward default `LexemeParent` (which would singularize the already-singular-per-row plural). Same pattern on InflectionalRulePOS via `@DataClassName('InflectionalRulePOSRow')`."
  - "The v9 Markers table's featureBindings column reuses the Phase 4 Plan 01 FeatureBindingsConverter (flat JSON: {\"pos\":[1],\"5\":2}) rather than introducing a nested schema. This keeps the converter round-tripping the same shape across MorphologicalRules and Markers."
  - "Drift auto-generated warnings on duplicate `morphologicalRulesRefs` and `lexemeParentsRefs` filter fields are cosmetic — the Drift manager API is unused in this project. These will be silenced by `@ReferenceName()` annotations if/when the manager API is adopted."

patterns-established:
  - "Add new table + new nullable column + new non-nullable-default column in a single migration without touching existing data — template for all future additive schema bumps"
  - "Table acronym suffixes (POS, DAO, etc.) need explicit `tableName` override when their Drift-generated default is ambiguous"

requirements-completed: [G-03, G-05, G-14, G-16, G-17, G-18, GRAM-01, GRAM-02, GRAM-06, GRAM-07]

# Metrics
duration: resumed-session
completed: 2026-04-11
---

# Phase 4 Plan 08: Schema v9 Foundation Summary

**Drift schema v9 adds Markers, InflectionalRulePOS, and LexemeParents junction tables, plus MorphologicalRules.autoApply and three Lexemes columns (derivedFromLexemeId, derivedViaRuleId, rootOnlyViaDerivations) to unblock every Phase 4 gap-closure plan (04-09 through 04-14). Migration is additive with a one-row-per-inflectional-rule junction backfill.**

## Performance

- **Duration:** Resumed session (Task 1 committed prior to usage-limit interruption)
- **Tasks:** 3 (1 RED test, 1 schema + migration, 1 codegen + GREEN)
- **Files created:** 1
- **Files modified:** 8

## Objective

Extend the Drift schema from v8 to v9 to support Phase 4 gap-closure decisions:

- **D-44** Markers table for unmarked-cell declarations
- **D-55** InflectionalRulePOS junction for multi-POS inflectional rules + backfill from legacy `input_pos_id`
- **D-57 / D-58** Lexemes.derivedFromLexemeId + derivedViaRuleId for rule-linked promoted derivations
- **D-59** MorphologicalRules.autoApply flag for derivational auto-promote
- **D-62** LexemeParents junction for manual etymology links
- **D-63** Lexemes.rootOnlyViaDerivations filter for muted-in-dictionary roots

This plan is the BLOCKING schema foundation — every downstream gap plan (04-09 through 04-14) depends on the v9 tables and columns existing at runtime.

## Schema v9 Delta

| Entity                         | Change                                                               | Decision      |
| ------------------------------ | -------------------------------------------------------------------- | ------------- |
| Markers (new table)            | `(id PK, pos_id FK CASCADE, feature_bindings TEXT JSON default '{}')` | D-44          |
| InflectionalRulePOS (new)      | `(rule_id FK CASCADE, pos_id FK CASCADE, PK(rule_id, pos_id))`       | D-55          |
| LexemeParents (new)            | `(child_lexeme_id FK CASCADE, parent_lexeme_id FK CASCADE, relationship TEXT nullable, notes TEXT nullable, PK(child, parent))` | D-62 |
| MorphologicalRules.autoApply   | new `BOOL NOT NULL DEFAULT 0`                                        | D-59          |
| Lexemes.derivedFromLexemeId    | new `INT nullable REFERENCES lexemes(id)`                            | D-57          |
| Lexemes.derivedViaRuleId       | new `INT nullable REFERENCES morphological_rules(id)`                | D-57 / D-58   |
| Lexemes.rootOnlyViaDerivations | new `BOOL NOT NULL DEFAULT 0`                                        | D-63          |
| schemaVersion                  | `8 -> 9`                                                             | plan 04-08    |

## Migration Data-Mutation Summary

**v8 -> v9 onUpgrade (lib/db/app_database.dart):**

1. `createTable(markers)` — creates the unmarked-cell table
2. `createTable(inflectionalRulePOS)` — creates the multi-POS junction
3. `createTable(lexemeParents)` — creates the etymology junction
4. `addColumn(morphologicalRules, autoApply)` — default 0 on all existing rows
5. `addColumn(lexemes, derivedFromLexemeId)` — NULL on all existing rows
6. `addColumn(lexemes, derivedViaRuleId)` — NULL on all existing rows
7. `addColumn(lexemes, rootOnlyViaDerivations)` — default 0 on all existing rows
8. **Junction backfill** (customSelect + customStatement loop):
   - Read every v8 `morphological_rules` row where `kind = 'inflectional' AND input_pos_id IS NOT NULL`
   - For each, `INSERT OR IGNORE INTO inflectional_rule_pos (rule_id, pos_id) VALUES (?, ?)`
   - Derivational rules are NOT backfilled
   - Inflectional rules with null `input_pos_id` are NOT backfilled (0-row result, not an error)

**Safety net (beforeOpen):** mirrors v8 — idempotent `CREATE TABLE IF NOT EXISTS` for all three new tables + `try/catch` `ALTER TABLE ADD COLUMN` for each of the four new columns. Runs on every connection open, safe against interrupted migrations.

## InflectionalRulePOS Table Name Fix

Drift's auto snake-case converter on `InflectionalRulePOS` produces `inflectional_rule_p_o_s` — each capital in the all-caps acronym becomes a separate snake segment. The migration SQL (`INSERT OR IGNORE INTO inflectional_rule_pos`) and the beforeOpen safety-net (`CREATE TABLE IF NOT EXISTS inflectional_rule_pos`) wanted the unmangled name.

**Fix:** Override `tableName` on the Table class:

```dart
@DataClassName('InflectionalRulePOSRow')
class InflectionalRulePOS extends Table {
  IntColumn get ruleId => integer().references(MorphologicalRules, #id, onDelete: KeyAction.cascade)();
  IntColumn get posId => integer().references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {ruleId, posId};

  @override
  String get tableName => 'inflectional_rule_pos';
}
```

This aligns Drift codegen (`static const String $name = 'inflectional_rule_pos'`) with the migration SQL and the safety-net statements. Without this override, the test error was `SqliteException(1): no such table: inflectional_rule_pos` during backfill because `m.createTable(inflectionalRulePOS)` created `inflectional_rule_p_o_s` while the backfill INSERT targeted `inflectional_rule_pos`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] InflectionalRulePOS physical table name mismatch**
- **Found during:** Task 3 (migration test GREEN run)
- **Issue:** Drift's default snake-case converter mangled `InflectionalRulePOS` -> `inflectional_rule_p_o_s`, breaking the migration SQL and beforeOpen CREATE-IF-NOT-EXISTS statements which both used `inflectional_rule_pos`.
- **Fix:** Added `@override String get tableName => 'inflectional_rule_pos';` on the Table class so the generated `$name` matches the raw-SQL references.
- **Files modified:** lib/db/app_database.dart (Task 2 commit)
- **Commit:** a5490ba

**2. [Rule 1 - Bug in Task 1 RED test] FeatureBindings JSON shape mismatch in Markers round-trip test**
- **Found during:** Task 3 (migration test GREEN run)
- **Issue:** The Task 1 RED test seeded `'{"pos":[1],"dims":{"5":2}}'` into a marker's `feature_bindings` column, then expected `markers.single.featureBindings.dims` to equal `{5: 2}`. But `FeatureBindingsConverter.fromJson` expects a FLAT JSON shape (`'{"pos":[1],"5":2}'`) where dimension ids are top-level stringified keys — the converter has no concept of a nested `dims` object, so the test got `{}` back.
- **Fix:** Updated the test's INSERT statement to use the flat JSON shape documented in `lib/features/grammar/domain/feature_bindings.dart`.
- **Files modified:** test/integration/migration_v8_to_v9_test.dart
- **Commit:** aefaf4f

**3. [Rule 1 - Stale assertion after schemaVersion bump] v7->v8 schemaVersion test**
- **Found during:** Task 3 (regression sweep)
- **Issue:** `migration_v7_to_v8_test.dart` had `expect(db.schemaVersion, equals(8))`. After bumping to 9, opening an AppDatabase on a seeded v7 file reports schemaVersion 9 (because AppDatabase is now v9 and the migration runs v7 -> v9). The hard-coded 8 made the test regress.
- **Fix:** Changed the assertion to `greaterThanOrEqualTo(8)` with a comment explaining that the v7->v8 test proves v7->v8 migration logic ran, not which version is current. Future version bumps won't regress this again.
- **Files modified:** test/integration/migration_v7_to_v8_test.dart
- **Commit:** aefaf4f

**4. [Rule 3 - Compile blocker from new non-nullable columns] Direct `Lexeme(...)` constructor callers**
- **Found during:** Task 3 (flutter analyze / test suite)
- **Issue:** Two pre-existing test helpers (`test/unit/grammar/pos_resolver_test.dart` and `test/lexicon/lexeme_filter_test.dart`) construct `Lexeme` via the direct data-class constructor (not `LexemesCompanion`). Drift generates the `Lexeme` data class with every non-nullable field as a required parameter, regardless of DB-level default. Adding `rootOnlyViaDerivations` as a non-nullable BoolColumn (even with `.withDefault(const Constant(false))`) made the test helpers stop compiling with `Required named parameter 'rootOnlyViaDerivations' must be provided`.
- **Fix:** Added `rootOnlyViaDerivations: false` to both direct constructor calls. Companion-based callers (most production code and test setups) are unaffected since Companions use `Value.absent()` as the default.
- **Files modified:** test/unit/grammar/pos_resolver_test.dart, test/lexicon/lexeme_filter_test.dart
- **Commit:** aefaf4f

None of these deviations required user input — they were directly caused by the current task's schema changes and fall under deviation Rules 1 and 3.

## Test Results

**New tests (Task 1 RED -> Task 3 GREEN):**

- `test/integration/migration_v8_to_v9_test.dart` — **17 tests, all passing**
  - schemaVersion reports 9 after migration
  - Markers table exists and is empty after migration
  - InflectionalRulePOS table exists after migration
  - LexemeParents table exists after migration
  - MorphologicalRules.autoApply column exists and defaults to false on pre-existing rows
  - Lexemes.derivedFromLexemeId exists and is NULL for pre-existing rows
  - Lexemes.derivedViaRuleId exists and is NULL for pre-existing rows
  - Lexemes.rootOnlyViaDerivations exists and defaults to false on pre-existing rows
  - InflectionalRulePOS backfill: inflectional rule with input_pos_id gets one junction row
  - InflectionalRulePOS backfill: derivational rules are NOT backfilled
  - InflectionalRulePOS backfill: inflectional rules with NULL input_pos_id are skipped
  - InflectionalRulePOS backfill: mixed seed (inflectional + derivational + null) produces exactly one junction row
  - pre-existing v8 Dimensions rows survive migration
  - pre-existing v8 ParadigmCellOverrides rows survive migration
  - pre-existing MorphologicalRuleExceptions rows survive migration
  - beforeOpen safety net is idempotent across reopen
  - FeatureBindings converter round-trips on Markers.featureBindings

**Regression suites re-run:**

- `test/integration/migration_v7_to_v8_test.dart` — **9 tests, all passing** (after the schemaVersion assertion fix above)
- `test/unit/grammar/` — **~130+ tests passing** (paradigm_engine, tiebreak_detector, grammar_dao, paradigm_cell_override, paradigm_generation, pos_resolver, typology_providers)
- `test/lexicon/` — **all tests passing** (lexeme_filter, lexeme_dao, etc.)
- `test/widget/grammar/word_detail_paradigm_test.dart` — 6 tests passing
- `test/morphology_engine_test.dart` — full suite passing

## Commits

| Task  | Hash     | Message                                                                                          |
| ----- | -------- | ------------------------------------------------------------------------------------------------ |
| 1     | 46ad226  | test(04-08): add failing v8->v9 migration test (RED)                                             |
| 2     | a5490ba  | feat(04-08): add v9 schema — Markers, InflectionalRulePOS, LexemeParents + promoted-derivation columns |
| 3     | aefaf4f  | feat(04-08): regenerate Drift codegen for v9 schema + fix v9-required test helpers               |

## Downstream Impact

After this plan, downstream gap plans (04-09 through 04-14) can now:

- `db.markers` — read/write unmarked-cell declarations (D-44, D-45, D-46 paradigm resolution)
- `db.inflectionalRulePOS` — read/write multi-POS inflectional rule memberships (D-55); rule editor must switch to the junction as source of truth for inflectional kind='inflectional' rules
- `db.lexemeParents` — read/write manual etymology links (D-62); etymology tree UI walks this + `lexeme.derivedFromLexemeId`
- `lexeme.derivedFromLexemeId` / `lexeme.derivedViaRuleId` — render promoted derivations with rule-computed display forms (D-57, D-58)
- `rule.autoApply` — toggle derivational rules between "auto-promote every matching word to a Lexeme" and "show as suggestion chip in word detail" (D-59, D-60)
- `lexeme.rootOnlyViaDerivations` — render roots that only surface through derivations in muted gray in the dictionary sidebar (D-63)

Schema v9 is the foundation — downstream plans implement the UI and business logic that reads and writes these new columns and tables.

## Self-Check: PASSED

- [x] lib/db/app_database.dart exists with `int get schemaVersion => 9`
- [x] Markers / InflectionalRulePOS / LexemeParents table classes defined
- [x] MorphologicalRules.autoApply column defined
- [x] Lexemes.derivedFromLexemeId / derivedViaRuleId / rootOnlyViaDerivations columns defined
- [x] `if (from < 9)` onUpgrade block with InflectionalRulePOS backfill
- [x] v9 beforeOpen safety-net (CREATE TABLE IF NOT EXISTS + try/catch ALTERs)
- [x] lib/db/app_database.g.dart regenerated with `$MarkersTable`, `$InflectionalRulePOSTable`, `$LexemeParentsTable` classes
- [x] test/integration/migration_v8_to_v9_test.dart exists and is GREEN (17/17 passing)
- [x] test/integration/migration_v7_to_v8_test.dart still GREEN (9/9 passing)
- [x] Commits: 46ad226, a5490ba, aefaf4f all present in `git log`
