---
phase: 04-grammar-morphology-revised
plan: 18-02
subsystem: grammar-ui, lexicon-ui
tags: [hit-test-fix, uat-gap, confirmation-dialog, phonetic-preview]
dependency_graph:
  requires: [04-16, 04-17]
  provides: [fixed-chip-hit-test, delete-confirmations, integrated-phonetic-preview]
  affects: [dimension_editor_panel, word_creation_form]
tech_stack:
  added: []
  patterns: [custom-container-chip, inputdecoration-helpertext]
key_files:
  created: []
  modified:
    - lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - test/widget/grammar/dimension_level_edit_test.dart
decisions:
  - "Option A for chip hit-test fix: replaced InputChip with custom _LevelChip Container — gives each interactive element (edit, standard-form, delete) its own InkWell with no parent absorbing taps"
  - "Phonetic preview moved to helperText inside InputDecoration — applies to both romanization-enabled and IPA-primary branches"
  - "Confirmation dialogs use TextButton with foregroundColor error for the destructive action — consistent with Material destructive patterns"
metrics:
  duration: 25min
  completed: 2026-04-12
  tasks: 2
  files: 3
---

# Phase 04 Plan 18-02: Chip Hit-Test Fix + Phonetic Preview Integration Summary

**One-liner:** Replaced InputChip-with-nested-widgets with custom _LevelChip Container (fixing UAT issues 28/38), added confirmation dialogs on deletion (T-18-02-01), and moved phonetic preview to IPA field helperText (UAT issue 35a).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix dimension editor chip hit-test + delete confirmations | `7ba800c` | dimension_editor_panel.dart, dimension_level_edit_test.dart |
| 2 | Integrate phonetic preview into IPA section | `1997c96` | word_creation_form.dart |

## What Was Built

### Task 1: Chip Hit-Test Fix + Delete Confirmations

**Root cause (UAT issues 28 and 38):** `InkWell` (edit icon) and `IconButton` (standard-form icon) were nested inside `InputChip.label`. The `InputChip` absorbed tap events before inner widgets could receive them, making both icons unclickable.

**Fix applied (Option A):** Replaced `InputChip` with a new `_LevelChip` stateless widget — a `Container` with rounded border styled to match a Material chip. Inside, a `Row` gives each interactive element its own `InkWell`:
- Edit icon (left): `InkWell` → opens `_LevelEditDialog` (D-79)
- Label text (center): plain `Text`
- Standard-form icon (right, intrinsic dims only): `InkWell` → opens `StandardFormPatternDialog` (D-98)
- Delete icon (far right): `InkWell` → confirmation dialog → D-86 dependency check

**Confirmation dialogs added (T-18-02-01):**
- Level deletion: `AlertDialog` with "Delete level?" title before the D-86 dependency check and actual delete
- Dimension deletion: `AlertDialog` with "Delete dimension?" title before `dao.deleteDimension`
- Both use `TextButton.styleFrom(foregroundColor: error)` for the destructive action

**Test updates:** `dimension_level_edit_test.dart` updated:
- `levelChipEditInkWellFor` finder updated from `find.ancestor(of InputChip)` to `find.ancestor(of Row)` with Padding > Icon predicate
- D-79 Test 5 ("onDeleted chip affordance still works") rewritten to use the new close InkWell and confirm the dialog before asserting deletion

### Task 2: Phonetic Preview as helperText

**Root cause (UAT issue 35a):** The D-113 phonetic preview was a standalone `Builder` block rendering `Surface: [$phonetic]` as a separate `Text` widget below the IPA field. User wanted it integrated INTO the IPA section.

**Fix applied:** Removed the `Builder` block. Instead, `applyRewritePipelineProvider` is watched at the top of `build()` and `showPhonetic` is computed there. The `helperText` param of `InputDecoration` for both IPA fields (romanization-enabled branch and IPA-primary branch) receives `'[$phonetic]'` when `showPhonetic` is true, null otherwise.

- Preview visible: phonemic non-empty AND phonetic != phonemic
- Preview hidden: IPA empty, or no rewrite rules configured, or rules don't fire on this word
- `helperStyle`: bodySmall + onSurface alpha 0.6 + italic — matches the previous standalone text style

## Verification

- `flutter analyze` on both files: 0 errors, 0 warnings (3 pre-existing info-level deprecation notices in unrelated code)
- `flutter test test/widget/grammar/dimension_level_edit_test.dart`: 10/10 passed
- `flutter test test/widget/lexicon/word_creation_phonetic_preview_test.dart`: 3/3 passed

## Deviations from Plan

### Auto-applied changes

**1. [Rule 2 - Missing critical functionality] Phonetic preview also added to IPA-primary branch**
- **Found during:** Task 2
- **Issue:** Plan only specified fixing the `romanizationEnabled` branch, but the `else` branch (IPA as primary input) had no phonetic preview at all. Since the user wants phonetic feedback during word creation in all modes, the fix was applied to both branches.
- **Fix:** Added `helperText: showPhonetic ? '[$phonetic]' : null` to the IPA-primary `IpaTextField` decoration as well.
- **Files modified:** `word_creation_form.dart`
- **Commit:** `1997c96`

**2. [Rule 1 - Bug] Test finder updated for new chip structure**
- **Found during:** Task 1
- **Issue:** `dimension_level_edit_test.dart` used `find.byType(InputChip)` to locate the edit InkWell and called `pluralChip.onDeleted!()` directly. After replacing `InputChip` with `_LevelChip`, both finders broke.
- **Fix:** Updated `levelChipEditInkWellFor` to search `Row` ancestor instead of `InputChip`; rewrote Test 5 to tap the close `InkWell` and confirm the dialog.
- **Files modified:** `test/widget/grammar/dimension_level_edit_test.dart`
- **Commit:** `7ba800c`

## Known Stubs

None — all interactive elements are wired with real callbacks.

## Threat Flags

None beyond the T-18-02-01 mitigation that was explicitly planned (confirmation dialogs before destructive deletes).

## Self-Check: PASSED

- `lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart` — FOUND
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` — FOUND
- `test/widget/grammar/dimension_level_edit_test.dart` — FOUND
- Commit `7ba800c` — FOUND
- Commit `1997c96` — FOUND
