---
phase: 04-grammar-morphology-revised
plan: 18-01
subsystem: lexicon/dictionary
tags: [uat-gap-closure, word-detail, word-list, promoted-derivation, phonetic, intrinsic, parents]
dependency_graph:
  requires: [04-17]
  provides: [promoted-edit-fix, phonetic-bracket, intrinsic-pos-badge, clickable-parents]
  affects: [word_detail_panel, word_list_panel, dictionary_page]
tech_stack:
  added: []
  patterns:
    - promotedDerivedFormProvider in _startEditing for display form resolution
    - applyRewritePipelineProvider for phonetic bracket display
    - _IntrinsicPosBadge ConsumerWidget resolving dim/level names reactively
    - ActionChip with onNavigateToWord callback for parent navigation
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
decisions:
  - Bracket bracket display switched from ViolationText to plain Text — phonetic form after rewrite may have different character positions than phonemic, making violation offsets invalid; plain Text is correct for post-rewrite display
  - _IntrinsicPosBadge as private ConsumerWidget — keeps viewMode builder clean while allowing reactive dim/level resolution without threading additional data down
  - onNavigateToWord as nullable callback on WordDetailPanel/WordDetailParentsSection — allows tests and other callers to opt-out of navigation while production path wires _onWordSelected
metrics:
  duration: 45 min
  completed: 2026-04-12T16:45:06Z
  tasks: 2
  files_modified: 3
---

# Phase 04 Plan 18-01: UAT Gap Closure — Promoted Edit, Phonetic Brackets, Intrinsic POS Badge, Clickable Parents

Closed 4 UAT-reported issues in the word detail and word list panels: promoted derivation edit pre-filling from root IPA, bracket notation showing phonemic instead of phonetic form, POS badge lacking intrinsic level names, and parent pills being non-navigable plain text.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix promoted derivation edit + phonetic bracket display | ba6e1e7 | word_detail_panel.dart, word_list_panel.dart |
| 2 | POS badge with intrinsic levels + clickable parent pills | b6d7193 | dictionary_page.dart |

## What Was Built

**Issue 13 — Promoted derivation edit shows root IPA (fixed):**
`_startEditing()` previously read `lexeme.ipa` / `lexeme.romanization` directly. For promoted derivations these fields store the parent root's values as placeholders. Fixed by reading `promotedDerivedFormProvider` + `resolveDisplayForms` at the start of `_startEditing`, seeding controllers with the resolved derived form. The `_ipaManuallyEdited` flag now correctly returns `false` for promoted rows (the placeholder diverges from deromanize output, which would wrongly set the override flag).

**Issue 35b — Bracket display shows phonemic not phonetic (fixed):**
Both list view and table view in `word_list_panel.dart` rendered `[display.ipa]` using `ViolationText`. IPA brackets `[...]` are linguistically PHONETIC notation (post-rewrite), not phonemic `/.../.`. Fixed by:
- Adding `applyRewritePipelineProvider` watch hoisted above the item loop
- Replacing `Text.rich` + `ViolationText` bracket rendering with `Text('[${applyRewrite(display.ipa)}]')`
- Removing now-unused `violations`, `itemViolations`, `standardFormViolationsProvider`, `ViolationText`, and `Violation` imports

**Issue 39a — POS pill doesn't show intrinsic level (fixed):**
Extracted `_IntrinsicPosBadge` ConsumerWidget that:
- Watches `posListProvider` + calls `posForLexeme` to resolve POS id
- Watches `dimensionsForPosProvider(pos.id)` for intrinsic dims
- Decodes `IntrinsicLevelsCodec.decode(lexeme.intrinsicLevelsJson)` for dim→level id mapping
- Calls `decodeLevelsJson(dim.levelsJson)` to resolve level names
- Renders "Noun (Masculine)" when intrinsic levels are assigned, plain "Verb" otherwise

**Enhancement — Clickable parent pills (done):**
`WordDetailParentsSection` now accepts an optional `onNavigateToWord` callback. When provided, parent rows render as `ActionChip` with an `Icons.arrow_upward` avatar; tapping calls `onNavigateToWord(parent.id)`. `DictionaryPage` passes `_onWordSelected` so the master-detail view navigates to the parent. Falls back to plain `Text` when callback is null (test isolation).

## Deviations from Plan

**[Rule 1 - Bug] Removed now-invalid violation underlines from bracket cells**
- **Found during:** Task 1 bracket fix
- **Issue:** `ViolationText` uses character offsets from the phonemic form. After applying the rewrite pipeline, the phonetic form may have different character positions, making violation highlighting incorrect on the post-rewrite text.
- **Fix:** Switched both list and table bracket cells to plain `Text` with the phonetic form. Violation highlighting remains on the phonemic IPA display above the bracket (where offsets are valid).
- **Files modified:** word_list_panel.dart

**[Rule 3 - Blocking] Worktree had stale working tree from pre-plan-09 commit**
- **Found during:** Initial setup
- **Issue:** Worktree `worktree-agent-aa180193` was branched from `2593fd3` (pre-intrinsic-levels), missing `intrinsic_levels_codec.dart`, `parentsForLexemeProvider`, schema v9+ fields, etc. `git reset --soft` moved HEAD to `2e5a245` but left working tree at old state.
- **Fix:** `git checkout 2e5a245 -- .` restored all working tree files to the correct HEAD state, then applied plan changes on top.
- **Impact:** No functional impact — all changes were applied correctly to the current codebase.

## Known Stubs

None. All plan goals fully implemented and wired to live data providers.

## Self-Check

PASSED

- FOUND: lib/features/lexicon/presentation/dictionary/word_detail_panel.dart (_IntrinsicPosBadge, onNavigateToWord, _startEditing fix)
- FOUND: lib/features/lexicon/presentation/dictionary/word_list_panel.dart (applyRewrite bracket fix)
- FOUND: lib/features/lexicon/presentation/dictionary/dictionary_page.dart (onNavigateToWord: _onWordSelected)
- FOUND: ba6e1e7 (Task 1 commit)
- FOUND: b6d7193 (Task 2 commit)
- FOUND: 04-18-01-SUMMARY.md
