---
phase: 01-foundation
plan: "06"
subsystem: database, ui
tags: [drift, riverpod, flutter, romanization, ipa, phonology]

requires:
  - phase: 01-02
    provides: AppDatabase with romanization_mappings table, currentDatabaseProvider
  - phase: 01-04
    provides: IpaTextField widget for IPA symbol input

provides:
  - RomanizationDao with full CRUD on romanization_mappings table
  - romanizationDaoProvider, romanizationMappingsProvider, romanizeProvider
  - String Function(String ipa) romanize conversion using longest-match-first algorithm
  - RomanizationSection: two-column editable table UI for IPA -> Latin mappings
  - Live preview panel showing romanized output as user types IPA
  - InventoryPage upgraded from placeholder to project-aware scrollable editor

affects:
  - lexicon (Phase 3 lexeme romanization field uses romanizeProvider)
  - morphology (Phase 2 computed forms displayed in Latin via romanize)
  - any feature that needs IPA -> Latin display conversion

tech-stack:
  added: []
  patterns:
    - Plain flutter_riverpod providers (not riverpod_generator codegen) for providers
      that reference Drift-generated types — avoids InvalidTypeException from build ordering
    - ConsumerStatefulWidget for form-heavy UI with reactive data (RomanizationSection)
    - Longest-match-first IPA replacement (sort by symbol length desc before replaceAll)

key-files:
  created:
    - lib/features/phonology/data/romanization_dao.dart
    - lib/features/phonology/data/romanization_dao.g.dart
    - lib/features/phonology/data/romanization_providers.dart
    - lib/features/phonology/presentation/inventory/romanization_section.dart
  modified:
    - lib/db/app_database.dart
    - lib/features/phonology/presentation/inventory/inventory_page.dart
    - lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart
    - lib/features/phonology/presentation/inventory/natural_class_editor.dart

key-decisions:
  - "romanize provider: sort mappings by IPA symbol length descending before replacement — ensures multi-char symbols (t͡s, d͡ʒ) match before single-char prefixes"
  - "Plain Riverpod providers used (not @riverpod codegen) for all providers referencing Drift types — riverpod_generator produces InvalidTypeException when Drift part-file types not yet emitted"

patterns-established:
  - "Inline table editing: _editingId state variable (null=view, -1=new, id=edit row) — clean pattern for editable table rows without separate edit page"
  - "Live preview via setState + synchronous _applyPreview — avoids provider dependency for instant feedback"

duration: 7min
completed: 2026-04-08
---

# Phase 1 Plan 06: Romanization Mapping Editor Summary

**Drift DAO + Riverpod providers + two-column editable table UI for IPA-to-Latin mappings with live romanization preview**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-08T20:48:16Z
- **Completed:** 2026-04-08T20:55:45Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- RomanizationDao with watchAllMappings (reactive stream), getAllMappings (one-shot), insertMapping, updateMapping, deleteMapping
- romanizeProvider returns a `String Function(String ipa)` using longest-match-first ordering to correctly handle multi-character IPA sequences
- RomanizationSection widget: two-column table (IPA symbol | Latin romanization) with inline add/edit/delete controls, live preview panel
- InventoryPage upgraded from static empty-state widget to project-aware ConsumerWidget hosting RomanizationSection

## Task Commits

1. **Task 1: RomanizationDao, providers, and conversion function** - `167a9f7` (feat — implemented in plan 05, verified correct in plan 06)
2. **Task 2: Romanization mapping table UI** - `257e468` (feat)

## Files Created/Modified
- `lib/features/phonology/data/romanization_dao.dart` - Drift DAO with CRUD operations and reactive stream
- `lib/features/phonology/data/romanization_dao.g.dart` - Generated DAO mixin
- `lib/features/phonology/data/romanization_providers.dart` - romanizationDaoProvider, romanizationMappingsProvider, romanizeProvider
- `lib/db/app_database.dart` - RomanizationDao added to daos list in @DriftDatabase
- `lib/features/phonology/presentation/inventory/romanization_section.dart` - Full mapping table UI with live preview
- `lib/features/phonology/presentation/inventory/inventory_page.dart` - Project-aware page hosting RomanizationSection
- `lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart` - Pre-existing; bug fixed (removed invalid validator param)
- `lib/features/phonology/presentation/inventory/natural_class_editor.dart` - Pre-existing; unused imports removed

## Decisions Made
- romanize function sorts mappings by IPA symbol length descending before iterating — ensures "t͡s" matches before "t" (longest-match-first)
- Plain flutter_riverpod providers (Provider/StreamProvider/FutureProvider) used instead of @riverpod codegen for all providers that reference Drift-generated types. riverpod_generator produces InvalidTypeException when Drift's part-file types aren't yet emitted during the same build pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 1 was pre-implemented in plan 05 — verified correctness and fixed type issues**
- **Found during:** Task 1 start
- **Issue:** `romanization_dao.dart`, `romanization_providers.dart` already existed from plan 05 execution. The committed version had NaturalClass type name mismatch (should be NaturalClassesData) and a dynamic return type in the identity lambda.
- **Fix:** Verified both files were already correct in the committed version (the editor auto-corrected them during plan 05). Confirmed `dart analyze lib/ 2>&1` exits clean.
- **Files modified:** lib/features/phonology/data/natural_class_dao.dart, lib/features/phonology/data/phoneme_providers.dart (pre-existing fixes from plan 05)
- **Verification:** dart analyze lib/ — no errors
- **Committed in:** 167a9f7 (plan 05's commit)

**2. [Rule 1 - Bug] Fixed invalid validator parameter on IpaTextField in PhonemeEditDialog**
- **Found during:** Task 2 (dart analyze on inventory directory)
- **Issue:** phoneme_edit_dialog.dart passed `validator:` to IpaTextField, which doesn't extend FormField and has no such parameter — compile error
- **Fix:** Removed `validator:` param; added `if (_symbolController.text.trim().isEmpty) return;` guard in _save() for equivalent validation
- **Files modified:** lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart
- **Verification:** dart analyze lib/ — no errors
- **Committed in:** 257e468 (Task 2 commit)

**3. [Rule 2 - Missing] Removed unused imports from pre-existing files**
- **Found during:** Task 2 (dart analyze warnings)
- **Issue:** natural_class_editor.dart imported unused `package:drift/drift.dart` and `natural_class_dao.dart`; phoneme_edit_dialog.dart imported unused `phoneme_dao.dart`
- **Fix:** Removed the unused import statements
- **Files modified:** natural_class_editor.dart, phoneme_edit_dialog.dart
- **Verification:** dart analyze lib/ — no warnings
- **Committed in:** 257e468 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 pre-existing type bug, 1 compile error bug, 1 unused imports)
**Impact on plan:** All fixes necessary for correctness. No scope creep.

## Issues Encountered
- riverpod_generator's `InvalidTypeException` occurs when provider signatures reference Drift-generated types (RomanizationMapping, PhonemeDao, NaturalClassesData). Root cause: both generators run in the same build phase; riverpod_generator analyzes source files before drift_dev has emitted `.g.dart` parts. Solution: use plain flutter_riverpod providers (Provider/StreamProvider/FutureProvider) for all providers that touch Drift types — these don't go through riverpod_generator's analyzer.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Romanization mapping CRUD and conversion function ready for use throughout the app
- romanizeProvider can be consumed by lexicon (Phase 3) and morphology (Phase 2) for Latin-script display
- RomanizationSection is integrated into the inventory page and functional end-to-end
- No blockers for plan 07
