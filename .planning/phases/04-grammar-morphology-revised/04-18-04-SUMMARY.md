---
phase: 04-grammar-morphology-revised
plan: 18-04
subsystem: lexicon/dictionary, grammar/dimensions
tags: [uat-gap-closure, validation, pos, intrinsic, word-creation, word-edit, dimension-editor]
dependency_graph:
  requires: [04-18-01, 04-18-02]
  provides: [pos-mandatory-validation, intrinsic-validation-edit-mode, phonetic-preview-edit-mode, missing-intrinsic-warning]
  affects: [word_creation_form, word_detail_panel, grammar_providers, dimension_editor_panel]
tech_stack:
  added: []
  patterns:
    - _posError state field pattern for inline dropdown validation (mirrors _ipaError)
    - Provider.family<int, ({int posId, int dimId})> for reactive missing-count computation
    - helperText in IPA field InputDecoration for phonetic preview (replaces standalone Builder block)
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/grammar/data/grammar_providers.dart
    - lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart
decisions:
  - missingIntrinsicAssignmentCountProvider placed in grammar_providers.dart not lexeme_providers.dart — grammar_providers.dart already imports lexeme_providers.dart; adding the reverse import would create a circular dependency
  - rootOnlyViaDerivations exemption for POS validation — these words never surface standalone so requiring a POS is unnecessary
metrics:
  duration: 25 min
  completed: 2026-04-12T17:30:00Z
  tasks: 2
  files_modified: 4
---

# Phase 04 Plan 18-04: POS Mandatory Validation + Missing Intrinsic Warning Icons

Enforced POS + intrinsic level mandatory validation on word save (creation and edit), integrated phonetic preview into word detail edit mode IPA field, and added reactive warning icons in the dimension editor when intrinsic dimensions have unassigned words.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | POS + intrinsic level mandatory validation | 7f7d32a | word_creation_form.dart, word_detail_panel.dart |
| 2 | Missing intrinsic assignment warning icons | 3edeca1 | grammar_providers.dart, dimension_editor_panel.dart |

## What Was Built

**Task 1 — POS mandatory validation (word_creation_form.dart):**
Added `_posError` state field. In `_save()`, after IPA validation, checks `!_rootOnlyViaDerivations && (_selectedPos == null || _selectedPos!.isEmpty)` and sets `_posError = 'Part of speech is required'`. Wired `_posError` to the POS `DropdownButtonFormField` via `errorText`. Clears `_posError` on POS selection change.

**Task 1 — POS mandatory validation (word_detail_panel.dart):**
Added `_posError` state field. In `_saveEdit()`, after IPA check, applies same POS mandatory check using `lexeme.rootOnlyViaDerivations` for the exemption. Added `_posError = null` in `_startEditing()` to reset error on each new edit session. Wired `_posError` to the POS dropdown `errorText`.

**Task 1 — Integrated phonetic preview in edit mode (word_detail_panel.dart):**
Replaced the standalone `Builder` block that rendered `'Surface: [$phonetic]'` below the IPA field with helperText integration. Wrapped the IPA section in a single `Builder` that reads `applyRewritePipelineProvider` once, computes `showPhonetic = phonemic.isNotEmpty && phonetic != phonemic`, and passes `helperText: showPhonetic ? '[$phonetic]' : null` into the IPA `InputDecoration`. Applies in both romanization-enabled and IPA-only paths. Matches the pattern already established in `word_creation_form.dart` by plan 04-18-02.

**Task 2 — missingIntrinsicAssignmentCountProvider (grammar_providers.dart):**
Provider.family parameterized by `({int posId, int dimId})` record. Watches `allLexemeListProvider` and `posListProvider`. Filters to non-`rootOnlyViaDerivations` lexemes of the target POS via `posForLexeme`. Counts those where `IntrinsicLevelsCodec.decode(l.intrinsicLevelsJson)[dimId] == null`. Reactive: recomputes when any lexeme changes.

**Task 2 — Warning icons in dimension editor (dimension_editor_panel.dart):**
In `_dimensionCard`, when `dim.intrinsic == true`, watches `missingIntrinsicAssignmentCountProvider((posId: posId, dimId: dim.id))`. When count > 0, renders `Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange)` wrapped in a `Tooltip` with message `'{count} word(s) missing {dimName} assignment'` in the card header Row, between the dimension name and the action buttons. Collapses to nothing when count == 0 or dim is not intrinsic.

## Deviations from Plan

**[Rule 3 - Blocking] missingIntrinsicAssignmentCountProvider placed in grammar_providers.dart**
- **Found during:** Task 2
- **Issue:** The plan specified placing the provider in `lexeme_providers.dart`, but `grammar_providers.dart` already imports `lexeme_providers.dart`. Adding the reverse import would create a circular dependency since the provider needs `dimensionsForPosProvider` (from grammar_providers), `allLexemeListProvider` (from lexeme_providers), and `IntrinsicLevelsCodec` (from grammar/data).
- **Fix:** Placed the provider in `grammar_providers.dart` instead, which already has all required dependencies. `dimension_editor_panel.dart` already imports `grammar_providers.dart`, so no extra import needed in the consumer.
- **Files modified:** grammar_providers.dart
- **Commit:** 3edeca1

## Known Stubs

None. All plan goals fully implemented and wired to live data providers.

## Threat Surface Scan

No new trust boundaries or network endpoints introduced. Validation logic runs client-side before DB write, mitigating T-18-04-01 (I — validation bypass).

## Self-Check

PASSED

- FOUND: lib/features/lexicon/presentation/dictionary/word_creation_form.dart (_posError field, POS check in _save, errorText on dropdown)
- FOUND: lib/features/lexicon/presentation/dictionary/word_detail_panel.dart (_posError field, POS check in _saveEdit, helperText IPA preview, _posError clear in _startEditing)
- FOUND: lib/features/grammar/data/grammar_providers.dart (missingIntrinsicAssignmentCountProvider)
- FOUND: lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart (missingCount watch, warning Icon + Tooltip in card header)
- FOUND: 7f7d32a (Task 1 commit)
- FOUND: 3edeca1 (Task 2 commit)
- FOUND: 04-18-04-SUMMARY.md
