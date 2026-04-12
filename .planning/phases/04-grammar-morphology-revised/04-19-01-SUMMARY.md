---
phase: 04-grammar-morphology-revised
plan: 19-01
subsystem: grammar/morphology
tags: [schema-migration, marker-names, binding-display, rules-list]
dependency_graph:
  requires: [04-18-05]
  provides: [marker-name-persistence, level-abbr-binding-summaries, rule-binding-display]
  affects: [lib/db/app_database.dart, lib/features/grammar/domain/marker.dart, lib/features/grammar/data/marker_dao.dart, lib/features/morphology/presentation/rules/rule_editor_dialog.dart, lib/features/morphology/presentation/rules/rules_page.dart]
tech_stack:
  added: []
  patterns: [Drift schema migration, domain model extension, Riverpod provider composition]
key_files:
  created: []
  modified:
    - lib/db/app_database.dart
    - lib/features/grammar/domain/marker.dart
    - lib/features/grammar/data/marker_dao.dart
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/morphology/presentation/rules/rules_page.dart
    - lib/db/app_database.g.dart
decisions:
  - Schema v11 adds Markers.name TextColumn (default 'Unmarked') — addColumn migration + beforeOpen safety net
  - levelAbbrMap built once per build from dimensionsForPosProvider across all POS, no extra DB queries
  - bindingSummary() falls back to 'lv$id' notation if level not in map (defensive)
metrics:
  duration: 18min
  completed: 2026-04-12T17:50:13Z
  tasks: 2
  files: 6
requirements: [GRAM-01, GRAM-02, GRAM-03]
---

# Phase 04 Plan 19-01: Marker Names + Binding Summaries Summary

**One-liner:** Schema v11 persists user-given marker names; rules list resolves level IDs to abbreviations (PRS · PFV) for both marker and rule rows.

## What Was Built

Closed gaps 4, 5, and 6 from `04-18-VERIFICATION.md`:

**Gap 6 — Marker name persistence:**
- Added `TextColumn get name` to the `Markers` Drift table with default `'Unmarked'`
- Schema bumped from v10 to v11 with `if (from < 11)` migration block (`m.addColumn(markers, markers.name)`)
- Added v11 `beforeOpen` safety net (`ALTER TABLE markers ADD COLUMN "name" TEXT NOT NULL DEFAULT 'Unmarked'`)
- `MarkerDecl` domain class gains `final String name` field and `required this.name` constructor parameter
- `MarkerDao.watchMarkersForPos` passes `name: r.name` in the map callback
- `MarkerDao.insertMarker` and `updateMarker` accept a `required String name` / `String name` parameter
- `rule_editor_dialog.dart _saveMarker()` reads `_nameCtrl.text.trim()` (falling back to `'Unmarked'`) and passes it to both DAO calls

**Gap 4 — Level abbreviation resolution in binding summaries:**
- `rules_page.dart` builds a `Map<int, String> levelAbbrMap` from `dimensionsForPosProvider` + `decodeLevelsJson` across all POS after the `markersByPosId` loop
- `bindingSummary()` now uses `levelAbbrMap[id] ?? 'lv$id'` — shows `'PRS · PFV'` instead of `'lv42 · lv18'`
- Import for `dimension_level.dart` added

**Gap 5 — Feature bindings under regular rule names:**
- Rule card `Expanded` child replaced with a `Column` containing the rule name + an optional secondary `Text` showing `bindingSummary(rule.featureBindings)` when bindings are non-empty

**Gap 6 (display) — Marker row name:**
- Hardcoded `'Unmarked'` in marker row replaced with `marker.name`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed wrong controller name in `_saveMarker()`**
- **Found during:** Task 1 verification (`dart analyze`)
- **Issue:** Plan specified `_nameController.text` but the actual field is `_nameCtrl` (declared as `final _nameCtrl = TextEditingController()` at line 256 of `rule_editor_dialog.dart`)
- **Fix:** Replaced both occurrences of `_nameController` with `_nameCtrl`
- **Files modified:** `lib/features/morphology/presentation/rules/rule_editor_dialog.dart`
- **Commit:** c39e699

## Commits

| Hash | Message |
|------|---------|
| fa00dfa | feat(04-19-01): schema v11 + MarkerDecl name + MarkerDao name parameter |
| b38c083 | feat(04-19-01): level abbreviation resolution + binding display under rules |
| c39e699 | fix(04-19-01): correct controller name _nameCtrl in _saveMarker |

## Known Stubs

None — all three gaps are fully wired end-to-end.

## Threat Flags

None — changes are confined to schema migration (safe default value) and UI display logic; no new network endpoints, auth paths, or trust boundary crossings.

## Self-Check: PASSED

- `lib/db/app_database.dart` — FOUND, contains `TextColumn get name`, `schemaVersion => 11`, `if (from < 11)` block
- `lib/features/grammar/domain/marker.dart` — FOUND, contains `final String name`
- `lib/features/grammar/data/marker_dao.dart` — FOUND, contains `required String name`, `name: r.name`
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — FOUND, contains `_nameCtrl` usage in `_saveMarker()`
- `lib/features/morphology/presentation/rules/rules_page.dart` — FOUND, contains `levelAbbrMap`, `marker.name`, `bindingSummary(rule.featureBindings)`
- Commits fa00dfa, b38c083, c39e699 — all present in git log
