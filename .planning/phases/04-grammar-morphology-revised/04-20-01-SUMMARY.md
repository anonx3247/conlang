---
phase: 04-grammar-morphology-revised
plan: 20-01
subsystem: grammar/morphology
tags: [rule-editor, paradigm, derivation, intrinsic, uat-gap-closure]
dependency_graph:
  requires: []
  provides: [preFilledPosIds-parameter, outputIntrinsic-featureBindings, derivational-intrinsic-picker]
  affects: [rule_editor_dialog, paradigm_table_widget, feature_bindings]
tech_stack:
  added: []
  patterns: [DropdownButtonFormField-initialValue, Riverpod-ref.watch-in-Builder, backward-compat-JSON-key]
key_files:
  created: []
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
    - lib/features/grammar/domain/feature_bindings.dart
decisions:
  - preFilledPosIds passed as Set<int>? to avoid coupling to single-POS assumption; cleared on edit mode to prevent stale seeding
  - outputIntrinsic stored in existing featureBindings JSON column under reserved key to avoid schema migration
  - _outputIntrinsicLevels cleared whenever _outputPosId changes to prevent stale level bindings from prior POS
metrics:
  duration: 20min
  completed: "2026-04-12T19:07:00Z"
  tasks_completed: 2
  files_modified: 3
requirements: [GRAM-02, GRAM-03]
---

# Phase 04 Plan 20-01: RuleEditorDialog Gap Closure Summary

RuleEditorDialog now pre-selects POS on paradigm cell click and shows intrinsic level pickers for derivational output POS.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Pass posId from paradigm cell click to RuleEditorDialog | 85fb9d4 | paradigm_table_widget.dart, rule_editor_dialog.dart |
| 2 | Add output intrinsic level picker to derivational rule editor | 7436b1e | rule_editor_dialog.dart, feature_bindings.dart |

## What Was Built

**Task 1 — POS pre-fill on paradigm cell click (UAT Issue 1 / G-07 regression):**
- Added `preFilledPosIds` (`Set<int>?`) constructor parameter to `RuleEditorDialog`
- `initState()` seeds `_inflectionalPosSet` and `_selectedPosIds` from `preFilledPosIds` when opening in create mode for inflectional rules
- Added `posId` field to `_ParadigmCellWidget` and updated all 4 instantiation sites to pass it through
- The `ruleEditor` cell click handler now passes `preFilledPosIds: {posId}` when creating a new rule (edit mode excluded to avoid overwriting loaded data)

**Task 2 — Output intrinsic level picker for derivational rules (UAT New Gap 1):**
- Extended `FeatureBindings` with `outputIntrinsic: Map<int,int>` field (defaults to `const {}` — backward-compatible with all pre-existing DB rows)
- `FeatureBindingsConverter.fromJson` parses `outputIntrinsic` key; `toJson` emits it only when non-empty
- Added `_outputIntrinsicLevels: Map<int,int>` state to `RuleEditorDialog`
- Derivational mode now renders a `DropdownButtonFormField` per intrinsic dimension of the selected output POS (watched via `dimensionsForPosProvider`)
- `_outputIntrinsicLevels` is cleared when `_outputPosId` changes to prevent stale bindings from a previous POS
- Save path persists to `featureBindings.outputIntrinsic`; load path reads from it on edit

## Deviations from Plan

None — plan executed exactly as written, with one minor correction:
- Plan interface comment used `isIntrinsic` but actual Drift-generated `Dimension` field is `intrinsic` — used the correct field name.

## Verification

- `flutter analyze` on all 3 modified files: no issues
- `flutter test test/unit/grammar/feature_bindings_converter_test.dart`: 8/8 passed
- `flutter test test/unit/grammar/`: all non-pre-existing tests passed; 2 pre-existing compilation failures in `marker_dao_test.dart` and `marker_resolution_test.dart` (missing `name` param on `insertMarker` — confirmed pre-existing via git stash check, unrelated to this plan)

## Known Stubs

None — the intrinsic level picker is fully wired: UI renders from live Riverpod stream, state updates on selection, save persists to DB, load restores on edit.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes at trust boundaries. Output intrinsic data flows only through the existing `featureBindings` TEXT column.

## Self-Check: PASSED

- SUMMARY.md: FOUND
- rule_editor_dialog.dart: FOUND
- paradigm_table_widget.dart: FOUND
- feature_bindings.dart: FOUND
- Commit 85fb9d4 (Task 1): FOUND
- Commit 7436b1e (Task 2): FOUND
