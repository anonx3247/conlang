---
phase: 01-foundation
plan: 12
subsystem: database, ui, phonology
tags: [drift, riverpod, flutter, phonology, romanization, upsert, schema-migration]

# Dependency graph
requires:
  - phase: 01-11
    provides: phoneme_edit_dialog with unified Add Phoneme + reverse IPA derivation
  - phase: 01-13
    provides: app_database at schemaVersion 2 with RewriteRules table + migration strategy
provides:
  - ProjectSettings key/value table (schema v3) for project-scoped settings
  - romanizationEnabledProvider watching project_settings with upsert setter
  - Romanization section on/off toggle persisted per project
  - Auto-create phoneme when romanization mapping added for unknown IPA symbol
  - Prompt user to add romanization when new phoneme is saved
affects: [02-morphology, lexicon-features, romanization-consumer-pages]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ProjectSettings key/value table for per-project feature flags — generic enough for future toggles"
    - "insertOnConflictUpdate for upsert on unique key column"
    - "Drift schema migration: onUpgrade with from < N guards, schemaVersion incremented"
    - "StreamProvider watching full table then filtering key — simple, no custom DAO needed"
    - "asData?.value for null-safe AsyncValue access in riverpod 3.x (no valueOrNull getter)"

key-files:
  created: []
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/phonology/data/romanization_providers.dart
    - lib/features/phonology/presentation/inventory/romanization_section.dart
    - lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart

key-decisions:
  - "01-12: romanizationEnabledProvider watches full project_settings stream then filters by key — avoids a dedicated DAO method for a single-row fetch"
  - "01-12: asData?.value used for AsyncValue access (riverpod 3.x has no valueOrNull getter)"
  - "01-12: Feature-to-string reverse maps inlined in romanization_section as private static methods — avoids extracting shared code for 4 simple switch expressions"
  - "01-12: insertOnConflictUpdate on ProjectSettings.key unique column — standard Drift upsert"
  - "01-12: schema bumped to v3 with from < 3 guard in onUpgrade — compatible with both fresh installs (onCreate) and existing dbs at v1 or v2"

patterns-established:
  - "ProjectSettings table: generic store for project-level boolean/string settings"
  - "Bidirectional sync pattern: add romanization -> auto-create phoneme; add phoneme -> prompt for romanization"

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 01 Plan 12: Romanization Toggle and Bidirectional Sync Summary

**ProjectSettings table (schema v3) with romanization on/off toggle, auto-phoneme creation from romanization mappings, and romanization prompt when adding new phonemes**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T04:51:31Z
- **Completed:** 2026-04-09T04:55:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `ProjectSettings` key/value Drift table (schema v3) with `from < 3` migration guard
- Romanization section now has an Enabled switch in the header that persists per project via upsert
- Adding a romanization mapping for a new IPA symbol auto-creates the phoneme with pre-filled features from IpaSound static data
- Adding a new phoneme shows a "Add romanization for /x/?" dialog (skippable) when romanization is enabled and no mapping exists

## Task Commits

1. **Task 1: Add project settings table and romanization toggle** - `a877800` (feat)
2. **Task 2: Implement bidirectional phoneme-romanization sync** - `3bf401f` (feat)

**Plan metadata:** (included in final docs commit)

## Files Created/Modified

- `lib/db/app_database.dart` - Added ProjectSettings table, bumped schemaVersion to 3, added v3 migration
- `lib/db/app_database.g.dart` - Regenerated Drift code (ProjectSetting data class, ProjectSettingsCompanion)
- `lib/features/phonology/data/romanization_providers.dart` - Added romanizationEnabledProvider (stream) and setRomanizationEnabled() (upsert)
- `lib/features/phonology/presentation/inventory/romanization_section.dart` - Enabled switch, auto-phoneme creation with IpaSound feature lookup
- `lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart` - _promptRomanization() dialog after new phoneme save

## Decisions Made

- `romanizationEnabledProvider` watches the full `project_settings` stream and filters by key — no custom DAO method needed for a single-row read
- `asData?.value` used for null-safe `AsyncValue` access since riverpod 3.x removed the `valueOrNull` getter present in earlier versions
- Feature-to-string reverse maps (manner, place, height, backness) inlined as private `static` methods in `_RomanizationSectionState` — avoids extracting shared code for 4 simple switch expressions
- Schema bumped to v3 with `from < 3` guard: works for fresh installs (onCreate) and existing databases at v1 or v2

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `valueOrNull` getter does not exist on `AsyncValue` in riverpod 3.0.3 (only in older versions). Used `asData?.value` instead throughout. Caught by analyzer on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phoneme and romanization inventories are now synced bidirectionally
- ProjectSettings table available for future per-project feature flags
- Phase 1 fully complete — ready for Phase 2 (morphology engine)

---
*Phase: 01-foundation*
*Completed: 2026-04-09*
