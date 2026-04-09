---
phase: 01-foundation
plan: 05
subsystem: database, ui
tags: [drift, riverpod, flutter, ipa, phonology, inventory]

requires:
  - phase: 01-02
    provides: currentDatabaseProvider, AppDatabase with Phonemes and NaturalClasses tables
  - phase: 01-04
    provides: IpaTextField with IPA keyboard popup for phoneme symbol entry

provides:
  - PhonemeDao with full CRUD + reactive streams (watchConsonants, watchVowels, watchAllPhonemes)
  - NaturalClassDao with watchAllClasses, insertClass, updateClass, deleteClass, resolveClass
  - Riverpod providers: phonemeDaoProvider, naturalClassDaoProvider, consonantListProvider, vowelListProvider, allPhonemesProvider, naturalClassListProvider
  - InventoryPage with consonant grid (manner x place) and vowel chart (height x backness)
  - PhonemeEditDialog for creating and editing phonemes with IPA keyboard integration
  - NaturalClassEditor for defining named phoneme sets with chip multi-select
  - confirmDeletePhoneme and confirmDeleteNaturalClass helpers

affects:
  - 01-06 (romanization providers now using same manual-provider pattern)
  - 01-07 (DSL will reference natural class names from naturalClassListProvider)
  - Phase 2 (phonotactic engine reads phonemes and natural classes)

tech-stack:
  added: []
  patterns:
    - "Manual flutter_riverpod Providers (not riverpod_generator codegen) for Drift-returning streams — riverpod_generator 3.x cannot resolve types defined in drift part files at codegen time"
    - "StreamProvider<List<DriftType>> with Stream.value([]) fallback for null DAO (no project open)"
    - "Phoneme grid cells display voiceless/voiced pairs (consonants) or unrounded/rounded pairs (vowels) sorted within each cell"

key-files:
  created:
    - lib/features/phonology/data/phoneme_dao.dart
    - lib/features/phonology/data/phoneme_dao.g.dart
    - lib/features/phonology/data/natural_class_dao.dart
    - lib/features/phonology/data/natural_class_dao.g.dart
    - lib/features/phonology/data/phoneme_providers.dart
    - lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart
    - lib/features/phonology/presentation/inventory/natural_class_editor.dart
  modified:
    - lib/db/app_database.dart (added PhonemeDao, NaturalClassDao to daos list)
    - lib/db/app_database.g.dart (regenerated with new DAO accessors)
    - lib/features/phonology/presentation/inventory/inventory_page.dart (replaced placeholder with full grid UI)
    - build.yaml (fixed invalid apply_builders field)

key-decisions:
  - "Manual flutter_riverpod Providers used instead of riverpod_generator for Drift-type streams: riverpod_generator 3.x cannot resolve types from drift part files (Phoneme, NaturalClassesData, RomanizationMapping) at codegen analysis time, causing InvalidTypeException"
  - "NaturalClasses drift table generates NaturalClassesData (not NaturalClass) as the data class type — naming follows Drift 2.30 convention for tables with plural names"
  - "build.yaml apply_builders field was invalid (unsupported key) — replaced with minimal drift_dev + riverpod_generator enabled config"
  - "Consonant grid shows only rows/columns that have at least one phoneme (sparse display) rather than full IPA chart — cleaner for small inventories"
  - "phonemeIds JSON decoded with jsonDecode in NaturalClassEditor; manual string parsing fallback removed in favor of try/catch around jsonDecode"

patterns-established:
  - "DAO pattern: DriftAccessor accessing AppDatabase tables, exposed via db.phonemeDao / db.naturalClassDao accessor"
  - "Provider pattern: Provider<DaoType?> derived from currentDatabaseProvider, returns null when no project open"
  - "Stream pattern: StreamProvider<List<T>> with Stream.value([]) when DAO is null"

duration: 11min
completed: 2026-04-09
---

# Phase 01 Plan 05: Phoneme Inventory Editor Summary

**Drift DAOs + Riverpod providers for phoneme CRUD with consonant grid, vowel chart, and natural class management dialogs using IPA keyboard integration**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-09T00:28:08Z
- **Completed:** 2026-04-09T00:39:03Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- PhonemeDao and NaturalClassDao registered in AppDatabase with full CRUD + reactive watch streams
- Riverpod StreamProviders expose consonants/vowels/all-phonemes/natural-classes scoped to current project
- InventoryPage replaced placeholder with consonant grid (manner x place) and vowel chart (height x backness), both reactive to database changes
- PhonemeEditDialog: IPA keyboard for symbol entry, type dropdown switches between consonant/vowel property fields
- NaturalClassEditor: chip multi-select from current inventory, validates reserved C/V names, saves phoneme IDs as JSON array
- All data persists in per-project SQLite via drift

## Task Commits

1. **Task 1: Phoneme and natural class DAOs with Riverpod providers** - `167a9f7` (feat)
2. **Task 2: Inventory page UI with phoneme editing and natural class management** - `19f3d8d` (feat)

## Files Created/Modified

- `lib/features/phonology/data/phoneme_dao.dart` - Drift DAO for phoneme CRUD + reactive streams
- `lib/features/phonology/data/natural_class_dao.dart` - Drift DAO for natural class CRUD + resolveClass
- `lib/features/phonology/data/phoneme_providers.dart` - Manual Riverpod providers for all phoneme and natural class streams
- `lib/db/app_database.dart` - Added daos: [PhonemeDao, NaturalClassDao] to @DriftDatabase annotation
- `lib/features/phonology/presentation/inventory/inventory_page.dart` - Full inventory editor (grid + chart + natural classes), replaces empty placeholder
- `lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart` - Phoneme create/edit/delete dialog with IPA keyboard
- `lib/features/phonology/presentation/inventory/natural_class_editor.dart` - Natural class create/edit/delete dialog

## Decisions Made

- **Manual providers over riverpod_generator:** riverpod_generator 3.x fails with `InvalidTypeException` when provider return types reference drift-generated types (`Phoneme`, `NaturalClassesData`) from part files. Manual `Provider`/`StreamProvider` definitions bypass this analysis limitation entirely.
- **NaturalClassesData type:** Drift 2.30 generates `NaturalClassesData` (not `NaturalClass`) for the `NaturalClasses` table — the generated name appends `Data` to the table name, pluralized from `NaturalClasses`.
- **Sparse grid display:** Grid shows only rows/columns containing phonemes. Full IPA chart (11 places x 8 manners = 88 cells) would be mostly empty for small inventories; sparse view is cleaner.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed invalid build.yaml apply_builders field**
- **Found during:** Task 1 (build_runner execution)
- **Issue:** build.yaml had `apply_builders` under a builder config — this key is not supported in build_runner; caused exit code 255 crash
- **Fix:** Replaced with standard `enabled: true` fields for both drift_dev and riverpod_generator
- **Files modified:** build.yaml
- **Verification:** build_runner runs without exception
- **Committed in:** `167a9f7` (Task 1 commit)

**2. [Rule 1 - Bug] Switched from riverpod_generator to manual providers**
- **Found during:** Task 1 (build_runner code generation)
- **Issue:** riverpod_generator 3.x throws `InvalidTypeException: The type is invalid and cannot be converted to code` for any provider returning `Stream<List<Phoneme>>` or `Stream<List<NaturalClassesData>>` — drift-generated types live in part files which riverpod_generator cannot traverse during analysis
- **Fix:** Rewrote phoneme_providers.dart and romanization_providers.dart using manual `flutter_riverpod` `Provider`/`StreamProvider`/`FutureProvider` without `@riverpod` annotation or part directive — no generated file needed
- **Files modified:** lib/features/phonology/data/phoneme_providers.dart, lib/features/phonology/data/romanization_providers.dart
- **Verification:** build_runner exits 0, dart analyze lib/ reports no errors
- **Committed in:** `167a9f7` (Task 1 commit)

**3. [Rule 1 - Bug] Fixed NaturalClass -> NaturalClassesData type name mismatch**
- **Found during:** Task 1 (linter/analyzer feedback)
- **Issue:** Plan specified `NaturalClass` as the DAO return type, but Drift 2.30 generates `NaturalClassesData` for the `NaturalClasses` table
- **Fix:** Updated all references in natural_class_dao.dart and phoneme_providers.dart to use `NaturalClassesData`
- **Files modified:** lib/features/phonology/data/natural_class_dao.dart, lib/features/phonology/data/phoneme_providers.dart
- **Verification:** dart analyze reports no type errors
- **Committed in:** `167a9f7` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (1 blocking build config, 1 systematic codegen bug, 1 generated type name mismatch)
**Impact on plan:** All fixes required for compilation. Pattern discovered for drift+riverpod integration: use manual providers. No scope creep.

## Issues Encountered

- `const Stream.empty()` is not a valid const — changed to `Stream.value([])` for null-DAO fallback
- romanization_providers.dart had same riverpod_generator issue (added during a prior plan run) — fixed as part of this plan's Rule 1 fix

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phoneme inventory fully functional; Plan 01-07 (phonotactic DSL) can reference natural class names via `naturalClassListProvider`
- Pattern established for drift+riverpod: use manual providers (`Provider<DaoType?>`, `StreamProvider<List<DriftType>>`) — apply to all future DAO-consuming providers
- Phase 2 morphology engine can query phonemes and natural classes via the same DAO/provider pattern

---
*Phase: 01-foundation*
*Completed: 2026-04-09*
