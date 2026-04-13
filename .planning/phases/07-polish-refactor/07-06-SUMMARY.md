---
phase: 07-polish-refactor
plan: "06"
subsystem: lexicon-ui
tags: [uat, datatable, selection-mode, anki-export]
dependency_graph:
  requires: []
  provides: [NIT-04]
  affects: [lexicon/dictionary]
tech_stack:
  added: []
  patterns: [DataTable.showCheckboxColumn, DataCell.onTap]
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
decisions:
  - Use DataTable.showCheckboxColumn instead of conditional rendering to toggle checkbox column visibility
  - Use DataCell.onTap for row navigation in normal mode since onSelectChanged must be null
metrics:
  duration: "5m"
  completed: "2026-04-12"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
---

# Phase 7 Plan 06: Lexicon DataTable Checkbox Fix Summary

One-liner: Hide DataTable checkbox column outside Anki export mode and restore cell-tap navigation via `DataCell.onTap`.

## What Was Built

Fixed two related UAT issues (UAT items 8-9 / NIT-04) in the lexicon table view:

1. **No checkbox column in normal mode** — Flutter's `DataTable` renders a leading checkbox column whenever any `DataRow.onSelectChanged` is non-null. Setting `onSelectChanged: null` in normal mode (combined with `showCheckboxColumn: widget.isSelectionMode`) eliminates the spurious checkbox column entirely when the user is not in Anki export selection mode.

2. **Row navigation preserved** — Since `onSelectChanged: null` removes the built-in tap handler, `DataCell.onTap` was added to all four columns (Word, IPA, POS, Meaning) so clicking any cell navigates to the word detail panel in normal mode.

3. **No auto-selection on load confirmed** — `_selectedLexemeId` already initializes to `null` in `dictionary_page.dart` and nothing in `initState` auto-selects a word. No change needed there.

## Changes

### `lib/features/lexicon/presentation/dictionary/word_list_panel.dart`

- Added `showCheckboxColumn: widget.isSelectionMode` to `DataTable` constructor
- Changed `DataRow.onSelectChanged` from always-non-null callback to `null` when `!widget.isSelectionMode`
- Added `onTap: widget.isSelectionMode ? null : () => widget.onWordSelected(lexeme.id)` to all four `DataCell` widgets in the table row

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `flutter analyze --no-pub lib/features/lexicon/presentation/dictionary/` — 0 issues in modified file (9 pre-existing issues in other files, out of scope)
- `showCheckboxColumn: widget.isSelectionMode` present in DataTable
- `onSelectChanged` is `null` outside selection mode
- All four DataCell widgets have `onTap` for normal-mode navigation

## Known Stubs

None.

## Threat Flags

None — pure UI state change, no new trust boundaries.

## Self-Check: PASSED

- File modified: `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` — FOUND
- Commit `1ff316c` — FOUND
