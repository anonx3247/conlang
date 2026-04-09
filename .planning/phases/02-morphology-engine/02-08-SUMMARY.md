---
phase: 02-morphology-engine
plan: 08
subsystem: database, ui
tags: [drift, flutter, riverpod, parts-of-speech, morphology, go_router]

# Dependency graph
requires:
  - phase: 02-morphology-engine
    provides: MorphologicalRules Drift table, MorphologyDao, RulesPage, morphology_providers.dart

provides:
  - PartsOfSpeech Drift table (id, name, abbreviation) at schema v5
  - posId nullable FK on MorphologicalRules referencing PartsOfSpeech
  - watchAllPos / insertPos / updatePos / deletePos DAO methods on MorphologyDao
  - posListProvider StreamProvider in morphology_providers.dart
  - PosPage with full CRUD (add/edit/delete dialogs, card list, empty state)
  - 'Parts of Speech' sidebar item in MorphologyShell
  - /morphology/pos GoRouter route in app_router.dart
  - POS filter DropdownButton above rules list in RulesPage

affects: [02-morphology-engine, 04-grammar]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PartsOfSpeechData naming: Drift generates Data suffix for tables whose name doesn't end in a simple singular (same as NaturalClassesData)"
    - "Safety-net beforeOpen try/catch for ALTER TABLE ADD COLUMN — column already exists is silently ignored"
    - "asData?.value pattern for AsyncValue null-safe access — riverpod 3.x has no valueOrNull getter"

key-files:
  created:
    - lib/features/morphology/presentation/pos/pos_page.dart
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/morphology/data/morphology_dao.dart
    - lib/features/morphology/data/morphology_dao.g.dart
    - lib/features/morphology/data/morphology_providers.dart
    - lib/features/morphology/presentation/morphology_shell.dart
    - lib/features/morphology/presentation/rules/rules_page.dart
    - lib/router/app_router.dart
    - lib/router/app_router.g.dart

key-decisions:
  - "02-08: Drift generates PartsOfSpeechData (not PartOfSpeech) — table class name + Data suffix, matches NaturalClassesData precedent from 01-05"
  - "02-08: beforeOpen ALTER TABLE for pos_id wrapped in try/catch — column already exists error is safe to ignore (same safety-net pattern as other tables)"
  - "02-08: RulesPage reorder arrows reference unfiltered list index when POS filter is active — preserves correct swap semantics across filtered views"

# Metrics
duration: 20min
completed: 2026-04-09
---

# Phase 2 Plan 08: Parts of Speech Summary

**PartsOfSpeech Drift table (schema v5) + POS management page + POS filter dropdown on rules list — UAT gap 4 closed**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-09T09:28:08Z
- **Completed:** 2026-04-09T09:48:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Added PartsOfSpeech table to Drift schema with onUpgrade migration from v4->v5 and beforeOpen safety-net
- Added nullable posId FK on MorphologicalRules; DAO exposes watchAllPos/insertPos/updatePos/deletePos
- Created PosPage with create/edit/delete dialogs, abbreviation badge in cards, and empty state
- Added 'Parts of Speech' sidebar item and /morphology/pos route in MorphologyShell + app_router
- Converted RulesPage to ConsumerStatefulWidget; POS filter dropdown shows All + each defined POS

## Task Commits

1. **Task 1: PartsOfSpeech table + posId column + DAO + providers** - `9d20847` (feat)
2. **Task 2: POS page + sidebar + router + rules filter** - `0efa840` (feat)

## Files Created/Modified
- `lib/db/app_database.dart` - PartsOfSpeech table class, posId on MorphologicalRules, schema v5, migration, safety-net
- `lib/db/app_database.g.dart` - Drift regenerated (PartsOfSpeechData, PartsOfSpeechCompanion)
- `lib/features/morphology/data/morphology_dao.dart` - @DriftAccessor adds PartsOfSpeech; POS CRUD methods
- `lib/features/morphology/data/morphology_dao.g.dart` - Drift DAO mixin regenerated
- `lib/features/morphology/data/morphology_providers.dart` - posListProvider added
- `lib/features/morphology/presentation/pos/pos_page.dart` - NEW: full CRUD POS management page
- `lib/features/morphology/presentation/morphology_shell.dart` - 'Parts of Speech' sidebar item added
- `lib/features/morphology/presentation/rules/rules_page.dart` - ConsumerStatefulWidget + POS filter dropdown
- `lib/router/app_router.dart` - /morphology/pos StatefulShellBranch + PosPage import
- `lib/router/app_router.g.dart` - Router regenerated

## Decisions Made
- Drift generated `PartsOfSpeechData` (not `PartOfSpeech`) — same `TableName + Data` suffix pattern as `NaturalClassesData` (decision from 01-05 applied here)
- beforeOpen ALTER TABLE for pos_id wrapped in try/catch — column already exists is safe to ignore silently
- RulesPage reorder arrows reference unfiltered list index when filter is active — correct swap semantics preserved across filtered views
- `asData?.value` used instead of `valueOrNull` — riverpod 3.x pattern for this project (established in 01-12)

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed generated data class name from PartOfSpeech to PartsOfSpeechData**
- **Found during:** Task 1 verification (flutter analyze)
- **Issue:** Plan specified `PartOfSpeech` as generated class name, but Drift 2.31 generates `PartsOfSpeechData` for a table class named `PartsOfSpeech`
- **Fix:** Replaced all `PartOfSpeech` references in dao and providers with `PartsOfSpeechData`
- **Files modified:** morphology_dao.dart, morphology_providers.dart
- **Verification:** flutter analyze — no errors related to these types
- **Committed in:** 9d20847 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed missing app_database.dart import in pos_page.dart**
- **Found during:** Task 2 verification (flutter analyze)
- **Issue:** PartsOfSpeechData and PartsOfSpeechCompanion not in scope — pos_page.dart only imported morphology_dao and morphology_providers
- **Fix:** Added `import '../../../../db/app_database.dart'`
- **Files modified:** pos/pos_page.dart
- **Verification:** flutter analyze — undefined_class errors resolved
- **Committed in:** 0efa840 (Task 2 commit)

**3. [Rule 1 - Bug] Fixed valueOrNull to asData?.value in RulesPage**
- **Found during:** Task 2 verification (flutter analyze)
- **Issue:** `posAsync.valueOrNull` invalid — riverpod 3.x AsyncValue has no valueOrNull getter in this project
- **Fix:** Changed to `posAsync.asData?.value ?? []`
- **Files modified:** rules/rules_page.dart
- **Verification:** flutter analyze — undefined_getter error resolved
- **Committed in:** 0efa840 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bugs)
**Impact on plan:** All three were type/import correctness fixes. No scope creep.

## Issues Encountered
- Pre-existing analyze errors in morphology_engine.dart and rule_editor_dialog.dart (condition type refactoring from plan 02-09) were present before this plan and remain unchanged — confirmed by git stash verification.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- UAT gap 4 (POS filtering) fully closed
- Conlangers can now define Noun/Verb/Adjective/etc. and filter the rules list by POS
- posId FK on MorphologicalRules is ready for Phase 4 Grammar use (declension/conjugation grouping)
- Next: plan 02-09 (condition pattern redesign — UAT gap 5) already committed; plan 02-10 remaining

## Self-Check: PASSED

- FOUND: lib/features/morphology/presentation/pos/pos_page.dart
- FOUND: .planning/phases/02-morphology-engine/02-08-SUMMARY.md
- FOUND: lib/db/app_database.dart (schemaVersion => 5)
- FOUND: PartsOfSpeech in app_database.dart (3 occurrences)
- Commits 9d20847 and 0efa840 verified in git log

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
