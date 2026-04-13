---
phase: 07-polish-refactor
plan: "05"
subsystem: grammar-ui, phonology-ui, lexicon-ui
tags: [bug-fix, uat, ui-layout, resizable-panels]
dependency_graph:
  requires: []
  provides: [clean-paradigm-viewer, functional-resizable-panels]
  affects: [paradigm_table_widget, phonology_shell, ipa_chart_panel, dictionary_page]
tech_stack:
  added: []
  patterns: [ResizableDivider + SizedBox(width: _stateVar) pattern]
key_files:
  created: []
  modified:
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
    - lib/features/phonology/presentation/phonology_shell.dart
    - lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
decisions:
  - IPA chart panel now takes parent-controlled width; parent SizedBox in phonology_shell drives _ipaChartWidth
  - Dictionary word list panel min 200px / max 400px clamp for ResizableDivider
metrics:
  duration: ~10 min
  completed: 2026-04-12
  tasks_completed: 2
  files_modified: 4
---

# Phase 07 Plan 05: Stray Divider + ResizableDivider Fix Summary

**One-liner:** Removed stray `const Divider()` widgets from paradigm viewer and wired all ResizableDivider instances to actually resize their adjacent panels.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove stray Divider from paradigm viewer | 907ca21 | paradigm_table_widget.dart |
| 2 | Fix ResizableDivider panel constraints across all layouts | 1a25aab | phonology_shell.dart, ipa_chart_panel.dart, dictionary_page.dart |

## What Was Done

### Task 1 — Paradigm viewer stray dividers

Removed two `const Divider()` calls from `_IntrinsicSliceSection.build()`:
- Line 1117 (single-lexeme slice path)
- Line 1192 (multi-lexeme slice bottom)

The surrounding `SizedBox(height: 4)` spacing and vertical padding already provided adequate visual separation between slices.

### Task 2 — ResizableDivider panel constraints

**IPA chart panel (phonology_shell + ipa_chart_panel):**

`phonology_shell.dart` already stored `_ipaChartWidth` and updated it on drag, but `IpaChartPanel` was rendered as `const IpaChartPanel()` with no size constraint from the parent. `IpaChartPanel` had a hardcoded `SizedBox(width: 280)` internally, so dragging the divider changed `_ipaChartWidth` in state but the widget ignored it.

Fix: Wrapped `IpaChartPanel()` in `SizedBox(width: _ipaChartWidth, ...)` in phonology_shell, and removed the `SizedBox(width: 280)` wrapper from `ipa_chart_panel.dart` so the panel fills whatever width the parent provides.

**Dictionary word list panel (dictionary_page):**

The word list was a `SizedBox(width: 280)` with a non-interactive `VerticalDivider` alongside it — no resize capability at all.

Fix: Added `double _wordListWidth = 280` to `_DictionaryPageState`, changed `SizedBox` to use `_wordListWidth`, replaced `VerticalDivider` with `ResizableDivider` clamped to 200–400px, and added the `resizable_divider.dart` import.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `flutter analyze --no-pub lib/` — no errors (26 pre-existing info warnings, unchanged)
- No `const Divider()` in paradigm_table_widget.dart
- `_wordListWidth` drives SizedBox + ResizableDivider in dictionary_page.dart
- IPA chart panel has no hardcoded width; phonology_shell drives width via `SizedBox(width: _ipaChartWidth)`

## Self-Check: PASSED

- `907ca21` exists: confirmed
- `1a25aab` exists: confirmed
- paradigm_table_widget.dart modified: confirmed (no const Divider() remains)
- phonology_shell.dart modified: confirmed (SizedBox wraps IpaChartPanel)
- ipa_chart_panel.dart modified: confirmed (no SizedBox width:280)
- dictionary_page.dart modified: confirmed (_wordListWidth + ResizableDivider)
