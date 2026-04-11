---
phase: 04-grammar-morphology-revised
plan: 01
subsystem: database
tags: [drift, sqlite, migration, schema, json-converter, grammar, feature-bindings]

# Dependency graph
requires:
  - phase: 02-morphology-engine
    provides: MorphologicalRules table, posIds CSV column, MorphologicalRuleExceptions
  - phase: 03-lexicon
    provides: Lexemes table with isPhonologicalException column (v7)
provides:
  - Drift schema v8 with Dimensions and ParadigmCellOverrides tables
  - MorphologicalRules.kind / featureBindings / inputPosId / outputPosId columns
  - Lexemes.skippedDimensionsJson column for per-word dimension opt-out
  - FeatureBindings value type + FeatureBindingsConverter (Drift JsonTypeConverter2)
  - RuleKind enum (inflectional / derivational)
  - backupProjectDbIfNeeded helper that copies project.db -> project.db.v7.bak
  - Async CurrentProjectId.open() that runs the backup before going live
  - v7->v8 onUpgrade data migration (silent reclassification to derivational)
affects: [04-02, 04-03, 04-04, 04-05, 04-06, 04-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern: Drift TypeConverter via JsonTypeConverter2 mixin for compound JSON value types"
    - "Pattern: legacy column kept-and-ignored (posIds) instead of physically dropped — research recommendation A9"
    - "Pattern: file-level .v7.bak safety backup BEFORE Drift opens, using sqlite3 raw connection to read user_version without triggering onUpgrade"
    - "Pattern: shared file-backed Drift executor across two GeneratedDatabase instances to seed v7 schema then trigger v8 migration in tests"
    - "Pattern: data migration uses customSelect on legacy column names (raw SQL) instead of typed select to avoid v7-row / v8-class shape mismatch"

key-files:
  created:
    - lib/features/grammar/domain/feature_bindings.dart
    - lib/features/grammar/domain/rule_kind.dart
    - lib/features/project/data/project_backup.dart
    - test/unit/grammar/feature_bindings_converter_test.dart
    - test/unit/project/project_backup_test.dart
    - test/integration/migration_v7_to_v8_test.dart
    - .planning/phases/04-grammar-morphology-revised/deferred-items.md
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/project/data/project_providers.dart
    - lib/features/project/data/project_providers.g.dart
    - lib/features/project/presentation/project_selector_dialog.dart
    - lib/features/project/presentation/project_menu.dart
    - lib/router/app_router.g.dart

key-decisions:
  - "FeatureBindings dims map uses int->int (dimensionId -> levelId) but JSON stores stringified keys per JSON spec; toJson/fromJson handle the conversion transparently"
  - "RuleKind.fromDbString defaults to derivational on unknown input (forward-compat with future kinds)"
  - "v8 onUpgrade data migration uses customSelect('SELECT id, pos_ids FROM morphological_rules') instead of select(morphologicalRules) — at migration time the legacy row shape doesn't match the v8 generated class so typed reads would fail"
  - "Lexemes.skippedDimensionsJson is a JSON array TEXT column rather than a junction table — Phase 4 D-A6 hybrid storage convention (parallels NaturalClasses.phonemeIds)"
  - "ParadigmCellOverrides keyed by (lexemeId, featureSetJson) rather than ruleId — supports overriding cells that no rule would have filled (D-22 / D-28 option B)"
  - "CurrentProjectId.open() became Future<void> to await prepareProjectDb before flipping state; both UI callsites already in async context so the change was localized to two await additions"
  - "openWithoutBackup added as escape hatch for tests/hot-reload that bypass the backup step"
  - "Drift TextColumn for featureBindings declared without <FeatureBindings> type argument — the .map(FeatureBindingsConverter()) chain provides the type mapping; explicit type arg is a Drift 3.x syntax not yet in 2.30"

patterns-established:
  - "JSON-as-text columns with Drift JsonTypeConverter2 give value-type ergonomics without an extra table"
  - "Pre-open file-level backup is the recommended safety net for any future destructive migration (Phase 4 research A8)"
  - "v7 seed via raw _SeedStub Drift instance + shared file path is the canonical migration test pattern"

requirements-completed: [GRAM-01, GRAM-06, GRAM-07]

# Metrics
duration: 11min
completed: 2026-04-11
---

# Phase 4 Plan 01: Schema v8 Foundation Summary

**Drift schema v8 with Dimensions/ParadigmCellOverrides tables, FeatureBindings JSON converter, RuleKind enum, kind-aware MorphologicalRules, and a project.db.v7.bak safety net for the first mutating migration.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-11T00:26:58Z
- **Completed:** 2026-04-11T00:38:17Z
- **Tasks:** 3 (Task 0, Task 1, Task 2)
- **Files modified:** 14 (7 created, 7 modified)
- **Tests added:** 22 (8 unit FeatureBindings + 5 unit backup + 9 integration migration)

## Accomplishments

- Drift schema bumped from v7 to v8 with two new tables (Dimensions, ParadigmCellOverrides), four new MorphologicalRules columns (kind, featureBindings, inputPosId, outputPosId), and one new Lexemes column (skippedDimensionsJson)
- v7->v8 onUpgrade silently reclassifies every existing morphological rule as `kind='derivational'`, parses the legacy `pos_ids` CSV into a `FeatureBindings(pos: [...], dims: {})`, and seeds inputPosId/outputPosId with the first parsed POS id
- File-level backup helper `backupProjectDbIfNeeded` produces `project.db.v7.bak` exactly once per project, BEFORE Drift's onUpgrade runs, using a raw `sqlite3` connection to read user_version without triggering a Drift open
- `CurrentProjectId.open()` is now `Future<void>` and awaits `prepareProjectDb` so the backup completes before the projectDatabase family provider materialises an AppDatabase
- `FeatureBindings` value type with `isInflectional`, `isDerivational`, `specificity`, `copyWith`, and structural equality, plus a Drift `JsonTypeConverter2`-based `FeatureBindingsConverter` wired onto the new column
- `RuleKind` enum with `fromDbString` / `dbString` helpers for downstream plans
- beforeOpen safety net (idempotent CREATE TABLE IF NOT EXISTS + try/catch ALTER TABLE) covering every v8 schema element — a hot-restart between user_version bump and table creation cannot leave a half-migrated db
- Pre-existing 163 tests still pass; no regression

## Schema v8 Delta

| Change | Detail |
|--------|--------|
| Added table `dimensions` | id, pos_id (FK PartsOfSpeech ON DELETE CASCADE), name, ordering, levels_json, template_id |
| Added table `paradigm_cell_overrides` | id, lexeme_id (FK Lexemes ON DELETE CASCADE), feature_set_json, override_ipa, override_romanization, notes |
| Extended `morphological_rules` | + kind TEXT NOT NULL DEFAULT 'derivational' |
| Extended `morphological_rules` | + feature_bindings TEXT NOT NULL DEFAULT '{}' (FeatureBindingsConverter) |
| Extended `morphological_rules` | + input_pos_id INTEGER NULLABLE FK parts_of_speech |
| Extended `morphological_rules` | + output_pos_id INTEGER NULLABLE FK parts_of_speech |
| Extended `lexemes` | + skipped_dimensions_json TEXT NULLABLE |
| Preserved | `morphological_rules.pos_ids` (legacy CSV) — kept-and-ignored per research A9 |
| Schema version | 7 -> 8 |

## Migration Data-Mutation Summary

- Strategy: silent reclassification (D-18). Every existing MorphologicalRules row becomes `kind='derivational'` with `feature_bindings.pos == parsed(pos_ids)`.
- Parser: `posIds.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList()` — defensive against `'2,,x,5'` style malformed CSV (keeps `[2, 5]`, drops the empty token and `x`).
- Drives `inputPosId` and `outputPosId` to `parsedList.first` (or `null` if the parsed list is empty).
- Iteration uses `customSelect('SELECT id, pos_ids FROM morphological_rules')` instead of typed `select(morphologicalRules)` because at migration time the row physically lacks the v8 columns and the generated `MorphologicalRule` class would fail to construct.
- MorphologicalRuleExceptions rows are NOT touched — their schema is unchanged in v8.

## Backup Helper Wiring Point

- New helper: `lib/features/project/data/project_backup.dart` exposes `Future<bool> backupProjectDbIfNeeded(String dbPath)`.
- Wired in `lib/features/project/data/project_providers.dart` via the new top-level helper `prepareProjectDb(String dbPath)`.
- `CurrentProjectId.open(String id)` is now `async`: it resolves the docs dir, computes `dbPath = {docsDir}/{id}/project.db`, awaits `prepareProjectDb(dbPath)`, then sets `state = id`.
- Both UI callsites updated to `await widget.ref.read(currentProjectIdProvider.notifier).open(project.id)`:
  - `lib/features/project/presentation/project_selector_dialog.dart::_openProject`
  - `lib/features/project/presentation/project_menu.dart::_createProject`
- Escape hatch `openWithoutBackup` added for tests/hot-reload paths that don't need the backup.

## Task Commits

Each task was committed atomically (TDD: RED test commit, then GREEN implementation commit):

1. **Task 0 RED** - `3cb230d` test(04-01): add failing tests for FeatureBindings and FeatureBindingsConverter
2. **Task 0 GREEN** - `f2cd12a` feat(04-01): implement FeatureBindings, FeatureBindingsConverter, RuleKind
3. **Task 1 RED** - `818b477` test(04-01): add v7 to v8 migration integration test (RED)
4. **Task 1 GREEN** - `16ea288` feat(04-01): bump schema to v8 with grammar feature system tables
5. **Task 2 RED** - `d0f1299` test(04-01): add project backup unit tests (RED)
6. **Task 2 GREEN** - `fb8160e` feat(04-01): add project.db.v7.bak helper and wire into project open path

## Test Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test/unit/grammar/feature_bindings_converter_test.dart | 8 | PASSING |
| test/unit/project/project_backup_test.dart | 5 | PASSING |
| test/integration/migration_v7_to_v8_test.dart | 9 | PASSING |
| **Total new tests** | **22** | **PASSING** |
| Pre-existing test suite (excluding pre-existing failure noted below) | 163 | PASSING |

## Code Generation

- `dart run build_runner build --delete-conflicting-outputs` was run twice during execution:
  - After schema changes in Task 1 to regenerate `lib/db/app_database.g.dart`
  - After provider changes in Task 2 to regenerate `lib/features/project/data/project_providers.g.dart`
- Drift codegen warns about duplicate `morphologicalRulesRefs` field on `$PartsOfSpeechTable` due to three FKs (posId, inputPosId, outputPosId) all pointing to PartsOfSpeech. This is a warning only — Drift skips the manager filter generation for the colliding name. Resolvable in a follow-up via `@ReferenceName()` annotations if downstream code needs the manager filter; not required for v8 functionality.

## Decisions Made

- **Drift TextColumn type argument:** Tried `TextColumn<FeatureBindings>` first; Drift 2.30 rejects with "Expected 0 type arguments". Removed the type arg — the `.map(FeatureBindingsConverter())` chain provides the type mapping. Documented in app_database.dart inline comment.
- **Test seed strategy:** Drift's NativeDatabase.memory() is per-connection; sharing in-memory state across two Drift instances is impossible. Solution: file-backed temp .db so the `_SeedStub` (writes v7 schema + sets user_version=7) can close and the real `AppDatabase` can re-open the same file and trigger onUpgrade. Each test uses a fresh tempDir cleaned in tearDown.
- **`isNull` import collision:** `package:drift/drift.dart` and `package:matcher/src/core_matchers.dart` both export `isNull`. Test file imports drift with `hide isNull` so the matcher version wins.
- **Async open() chain:** Considered keeping `CurrentProjectId.open` sync and firing the backup as fire-and-forget, but that creates a race where the projectDatabase family provider could materialise AppDatabase before backup completes. Made `open` async; both UI callsites were already in async functions and only needed `await` added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Drift TextColumn type-arg syntax incompatible with Drift 2.30**
- **Found during:** Task 1 (verifying migration test compiles after schema changes)
- **Issue:** Plan example `TextColumn<FeatureBindings> get featureBindings => ...` produced `Error: Expected 0 type arguments` from Drift 2.30 codegen
- **Fix:** Removed the explicit type argument; Drift infers the mapped type from `.map(const FeatureBindingsConverter())`
- **Files modified:** lib/db/app_database.dart
- **Verification:** All migration and unit tests pass; row.featureBindings.pos / .dims work as expected
- **Committed in:** 16ea288 (Task 1 GREEN commit)

**2. [Rule 1 - Bug] `isNull` ambiguous import in migration test**
- **Found during:** Task 1 (running migration test)
- **Issue:** drift.dart and flutter_test (via matcher) both export `isNull`, blocking compilation
- **Fix:** Import drift with `hide isNull` so the matcher version is used by `expect(..., isNull)`
- **Files modified:** test/integration/migration_v7_to_v8_test.dart
- **Verification:** Test compiles and all 9 tests pass
- **Committed in:** 16ea288 (Task 1 GREEN commit)

**3. [Rule 3 - Blocking] Migration data-mutation cannot read legacy rows via typed select**
- **Found during:** Task 1 (designing the v7->v8 onUpgrade block)
- **Issue:** At onUpgrade time the morphological_rules row physically lacks the v8 columns, so `select(morphologicalRules).get()` would attempt to construct a v8 generated `MorphologicalRule` data class from missing columns and fail
- **Fix:** Used `customSelect('SELECT id, pos_ids FROM morphological_rules').get()` and read raw fields via `row.read<int>('id')` / `row.read<String>('pos_ids')`. Plan's example used the typed Drift API; this fix preserves intent while being correct against the actual mid-migration row shape.
- **Files modified:** lib/db/app_database.dart
- **Verification:** Migration test 'existing morphological rule gets kind=derivational and pos parsed into feature_bindings' passes
- **Committed in:** 16ea288 (Task 1 GREEN commit)

**4. [Rule 3 - Blocking] CurrentProjectId.open had to become async**
- **Found during:** Task 2 (wiring backup into project open path)
- **Issue:** Plan suggested running backup in a "synchronous peek" pattern, but `backupProjectDbIfNeeded` is necessarily async (file IO + sqlite3 read) and the existing sync `open()` cannot await it. Fire-and-forget would race with the projectDatabase provider materialising AppDatabase.
- **Fix:** Changed `CurrentProjectId.open(String id)` to `Future<void>`. Updated both UI callsites (`project_selector_dialog._openProject` and `project_menu._createProject`) which were already in async functions. Added `openWithoutBackup` escape hatch for tests.
- **Files modified:** lib/features/project/data/project_providers.dart, lib/features/project/presentation/project_selector_dialog.dart, lib/features/project/presentation/project_menu.dart
- **Verification:** flutter analyze clean for project/, all backup tests pass, no regression in existing tests
- **Committed in:** fb8160e (Task 2 GREEN commit)

---

**Total deviations:** 4 auto-fixed (2 bugs in plan-supplied code, 2 blocking issues)
**Impact on plan:** All four fixes were necessary to compile/run correctly. None changed scope. The async open() change is the most visible — it touched two UI files but only added `await` keywords.

## Issues Encountered

- **Pre-existing flutter tool crash on first invocation:** First `flutter test` invocation crashed with `StateError: Bad state: No element` in `testCompilerBuildNativeAssets`. Resolved by running `flutter pub get` to rehydrate dependencies; subsequent runs were stable. Unrelated to plan changes.
- **Pre-existing test failure in `test/phonotactic_dsl_smoke_test.dart`:** Verified to fail on a clean checkout of `ea062a6` BEFORE any 04-01 changes (top-level main() assertion at line 72). Out of scope for this plan; logged in `.planning/phases/04-grammar-morphology-revised/deferred-items.md` for the phonology subsystem owner.

## User Setup Required

None - schema migration is automatic on next project open. The `.v7.bak` file appears next to `project.db` the first time a v7 project is opened under v8 code; users can ignore it or grep for it if they want to verify the migration ran.

## Next Phase Readiness

- Schema foundation is in place. Plans 04-02 through 04-07 can import `feature_bindings.dart` and `rule_kind.dart` directly.
- Dimensions table is queryable but empty — Plan 04-02 (Dimensions Manager) will populate it via UI.
- ParadigmCellOverrides table is queryable but empty — Plan 04-04/04-05 (Paradigm Editor) will use it.
- MorphologicalRules.kind defaults to `derivational` for all existing rules; Plan 04-03 (Rule Kind Toggle) will introduce UI for users to reclassify.
- Lexemes.skippedDimensionsJson is null for all existing lexemes; Plan 04-06 (Lexeme Dimension Skip UI) will use it.

## Threat Flags

None - this plan introduces only the database schema and a local-file backup helper. No new network endpoints, auth paths, or trust boundaries. All threats from the plan's `<threat_model>` are covered by the implementation:
- T-04-01 (data mutation) -> mitigated by .v7.bak (Task 2)
- T-04-02 (malformed CSV DoS) -> mitigated by `int.tryParse + whereType<int>` (Test 3)
- T-04-04 (mid-migration crash) -> mitigated by idempotent beforeOpen safety net
- T-04-06 (SQL injection via posIds) -> mitigated by `int.tryParse` (no concatenation)

## Self-Check: PASSED

All claimed files and commits verified to exist:

**Files (10):**
- FOUND: lib/features/grammar/domain/feature_bindings.dart
- FOUND: lib/features/grammar/domain/rule_kind.dart
- FOUND: lib/features/project/data/project_backup.dart
- FOUND: lib/db/app_database.dart
- FOUND: lib/db/app_database.g.dart
- FOUND: test/unit/grammar/feature_bindings_converter_test.dart
- FOUND: test/unit/project/project_backup_test.dart
- FOUND: test/integration/migration_v7_to_v8_test.dart
- FOUND: .planning/phases/04-grammar-morphology-revised/04-01-SUMMARY.md
- FOUND: .planning/phases/04-grammar-morphology-revised/deferred-items.md

**Commits (6):**
- FOUND: 3cb230d test(04-01): add failing tests for FeatureBindings and FeatureBindingsConverter
- FOUND: f2cd12a feat(04-01): implement FeatureBindings, FeatureBindingsConverter, RuleKind
- FOUND: 818b477 test(04-01): add v7 to v8 migration integration test (RED)
- FOUND: 16ea288 feat(04-01): bump schema to v8 with grammar feature system tables
- FOUND: d0f1299 test(04-01): add project backup unit tests (RED)
- FOUND: fb8160e feat(04-01): add project.db.v7.bak helper and wire into project open path

---
*Phase: 04-grammar-morphology-revised*
*Completed: 2026-04-11*
