---
phase: 04-grammar-morphology-revised
plan: 18-05
subsystem: grammar-morphology
tags: [markers, rule-editor, paradigm, CRUD, UI]
dependency_graph:
  requires: [18-03]
  provides: [marker-CRUD-UI, marker-mode-dialog, rules-list-markers, cell-click-marker-edit]
  affects: [paradigm_table_widget, rule_editor_dialog, rules_page]
tech_stack:
  added: []
  patterns: [MarkerDao write path, _leaveAsUnmarked boolean gate, merged rules+markers list]
key_files:
  created: []
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/morphology/presentation/rules/rules_page.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
decisions:
  - "_leaveAsUnmarked boolean strictly gates which DAO path executes — no dual-write path possible"
  - "Marker rows show 'Unmarked' as the display name (no per-marker name field exists in schema)"
  - "renderedMarkerPosIds guard prevents duplicate marker rows in multi-POS groups"
  - "Binding summary in list uses level IDs (lv42 style) — full dim name lookup would require extra provider reads not worth it for a list row"
  - "ParadigmUnmarked.source.id already present from plan 04-10; no schema/engine changes needed"
metrics:
  duration: ~18min
  completed: 2026-04-12T17:00:26Z
  tasks: 3
  files_modified: 3
---

# Phase 04 Plan 18-05: Markers UI (D-100 through D-103) Summary

**One-liner:** Full marker CRUD UI via "Leave as unmarked" checkbox in RuleEditorDialog + merged rules+markers list with ∅ badge + cell-click-to-edit marker from paradigm table.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | D-100/D-101 — RuleEditorDialog marker mode + MarkerDao save | 0339f94 | rule_editor_dialog.dart |
| 2 | D-102 — Merged rules+markers list with ∅ badge | dd56982 | rules_page.dart |
| 3 | D-103 — Cell click to edit existing marker | fd3d75e | paradigm_table_widget.dart |

## What Was Built

### Task 1: RuleEditorDialog marker mode (D-100/D-101)

- Added `markerId` and `markerBindings` constructor parameters to `RuleEditorDialog`
- Added `_leaveAsUnmarked` state field (bool, default false)
- "Leave as unmarked (no rule, just a ∅ cell)" checkbox rendered for inflectional mode only, after the rule name field
- When `_leaveAsUnmarked == true`: operations section (branch cards + add-branch button) and preview panel are hidden; bindings picker remains visible
- Title bar shows "Edit Marker" / "New Marker" when in marker mode
- `_saveMarker()` method writes to `MarkerDao.insertMarker` / `updateMarker`; never touches `MorphologyDao`
- Validates: at least one binding + at least one POS required for marker save (inline error shown)
- `initState` pre-loads marker bindings from `markerBindings` param when `markerId != null`

### Task 2: Merged rules+markers list (D-102)

- `_buildInflectionalGroupedList` in `rules_page.dart` now pulls `markersForPosProvider` for each POS in the current groups
- Marker rows appear after rules within each POS group, styled with:
  - ∅ badge (small rounded Container with muted styling)
  - "Unmarked" label in muted text (`alpha: 0.6`)
  - Binding summary in smaller muted text
- Tap opens `RuleEditorDialog` with `markerId` + `markerBindings` set (marker edit mode)
- Delete calls `markerDaoProvider.deleteMarker(marker.id)` with confirmation dialog
- `renderedMarkerPosIds` set prevents duplicate marker rows when a POS appears in multiple multi-POS groups

### Task 3: Cell click → edit marker (D-103)

- In `_ParadigmCellWidget.openDialog()`, added `ParadigmUnmarked` case in the `ruleEditor` click mode branch
- Clicking a ∅ cell opens `RuleEditorDialog` with `markerId: source.id` and `markerBindings: source.bindings`
- `ParadigmUnmarked.source` was already populated by the engine from plan 04-10; no engine or data-model changes needed
- Uncovered (em-dash) and filled cell click behavior unchanged

## Deviations from Plan

### Auto-fixed Issues

None.

### Notes

- The binding summary in the rules list shows level IDs (`lv42`) rather than level abbreviations. A full dim-name lookup would require watching `dimensionsForPosProvider` for each marker in the list body — adding per-marker Consumer widgets for a secondary label is overkill for the list row. The dialog's FilterChip picker shows the full detail when the user taps to edit.
- `paradigm_cell.dart` and `paradigm_engine.dart` required no changes — `ParadigmUnmarked.source` was already wired in plan 04-10 as documented in the plan context.

## Known Stubs

None. Marker CRUD is fully functional end-to-end: create from dialog checkbox, view in rules list, edit from list tap, edit from paradigm cell click, delete from list.

## Threat Flags

None — all writes go through existing `MarkerDao` at the same trust level as `MorphologyDao`. The `_leaveAsUnmarked` boolean strictly gates which DAO path executes, satisfying T-18-05-02 (I — marker/rule confusion).

## Self-Check: PASSED

- rule_editor_dialog.dart: FOUND
- rules_page.dart: FOUND
- paradigm_table_widget.dart: FOUND
- SUMMARY.md: FOUND
- Commit 0339f94 (Task 1): FOUND
- Commit dd56982 (Task 2): FOUND
- Commit fd3d75e (Task 3): FOUND
