---
phase: 04-grammar-morphology-revised
plan: 18-03
subsystem: grammar/presentation
tags: [flutter, riverpod, paradigm-viewer, intrinsic-dimensions, uat-fix]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised (plan 04-17)
    provides:
      - D-94/D-95 stacked-slice paradigm viewer infrastructure
      - D-88/D-89 intrinsic dimension engine filter
      - intrinsic_levels_codec.dart
      - lexemesByIntrinsicCombinationProvider
      - firstMatchingLexemeForPosProvider
provides:
  - 1-dim paradigm rendering (issues 37a)
  - Word-detail intrinsic filter — shows only that word's slice (issues 37b, 39b)
  - Multi-word intrinsic selection in grammar tab (issue 37c)
affects:
  - Any future consumer of ParadigmTableWidget that passes lexemeIds
  - Word detail paradigm embed (now properly filtered to word's intrinsic slice)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-dim paradigm: header row + one data row (no row-header column)"
    - "Word-detail intrinsic mode: decode lexeme.intrinsicLevelsJson to select single slice"
    - "Multi-word intrinsic selection: FilterChip list + lexemeIds param filters stacked slices"

key-files:
  created: []
  modified:
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
    - lib/features/grammar/presentation/inflections/inflections_page.dart

key-decisions:
  - "lexemeIds param is List<int>? on ParadigmTableWidget — null = template/single-word behavior unchanged; non-null filters stacked-slice pool per combo and skips empty combos"
  - "Word-detail mode detects lexemeId != -1 and decodes intrinsicLevelsJson directly, no provider needed beyond lexemeByIdProvider"
  - "_IntrinsicSliceSection gains lockedLexemeId param — when set, skips dropdown and renders the paradigm for exactly that word"
  - "1-dim non-intrinsic: _buildSingleDimTable renders column headers + one data row with no row-header column"
  - "1-dim within intrinsic slice: _IntrinsicSliceTable._buildSingleDimSliceTable same pattern"
  - "0 non-intrinsic dims: _buildBaseFormDisplay lists words by IPA, shows explanatory message"

patterns-established:
  - "lockedLexemeId sentinel pattern for word-detail mode in intrinsic slice sections"
  - "Builder inside Expanded for hasIntrinsic detection without introducing extra ConsumerStatefulWidget"

requirements-completed: [GRAM-04, GRAM-05]

# Metrics
duration: 12min
completed: 2026-04-12
---

# Phase 04 Plan 18-03: Paradigm Viewer Intrinsic Dimension Fixes Summary

**1-dim paradigm rendering, word-detail intrinsic filter, and multi-word selection in grammar tab — closes UAT issues 37a/37b/37c/39b**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-04-12
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

**Task 1 — 1-dim rendering + word-detail intrinsic filter (`paradigm_table_widget.dart`)**

- Issue 37a: removed hard `dims.length < 2` guard in `_buildSingleParadigmTable`. A POS with 1 non-intrinsic dimension now renders a flat single-row table via `_buildSingleDimTable` (column headers + one data row).
- Issue 37a: `_IntrinsicSliceTable` now handles `nonIntrinsicDims.length == 1` via `_buildSingleDimSliceTable`, same flat-row pattern inside each intrinsic slice.
- Issue 37a: `nonIntrinsicDims.length == 0` (all dims intrinsic) now shows `_buildBaseFormDisplay` — lists words by IPA with an explanatory message instead of erroring.
- Issues 37b/39b: `_buildStackedIntrinsicSlices` detects `lexemeId != -1` (word-detail mode). Decodes the lexeme's `intrinsicLevelsJson`, selects exactly one matching combination, renders a single `_IntrinsicSliceSection` with `lockedLexemeId` set so no dropdown appears.
- Issue 37c: added optional `List<int>? lexemeIds` to `ParadigmTableWidget`. In the stacked-slice path, each combination's pool is filtered to the provided IDs; combinations with no matching word are skipped via `SizedBox.shrink()`.
- Added imports for `IntrinsicLevelsCodec` and `pos_resolver.dart`.

**Task 2 — Multi-word intrinsic selection (`inflections_page.dart`)**

- Issue 37c: added `Set<int> _selectedLexemeIds` state field, cleared on POS change.
- `_buildWordPicker` detects `hasIntrinsic` from `dimensionsForPosProvider`. When true, replaces the single `DropdownButton` with a horizontal `Wrap` of `FilterChip`s (one per word of the POS). Tapping toggles word in/out of `_selectedLexemeIds`.
- Grammar tab `build` passes `lexemeIds: _selectedLexemeIds.toList()` to `ParadigmTableWidget` when the POS has intrinsic dims and the selection is non-empty.
- Non-intrinsic POSes retain the existing single-select dropdown — no behavior change.

## Task Commits

1. **Task 1: 1-dim rendering + word-detail intrinsic filter** — `c27901f`
2. **Task 2: Multi-word intrinsic selection** — `ab51986`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — rendering-only changes, no new trust boundaries or data mutations.

## Self-Check: PASSED

- paradigm_table_widget.dart: FOUND
- inflections_page.dart: FOUND
- Commit c27901f: FOUND
- Commit ab51986: FOUND
- All 176 unit + widget grammar tests: PASSED
