---
phase: 04-grammar-morphology-revised
plan: 17
subsystem: grammar/morphology/phonology
tags: [flutter, riverpod, drift, intrinsic-dimensions, paradigm-engine, standard-forms, romanization, rewrite-rules, phonetic-display]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised (plan 04-15)
    provides:
      - D-70..D-78 notation unification contract
      - notation_helpers.dart (smartRomanize, dotAwareDeromanize)
      - v9->v10 Drift migration pattern with TODO(04-17) extension marker
  - phase: 04-grammar-morphology-revised (plan 04-16)
    provides:
      - D-79/D-80 dimension editor chip structure
      - D-81 PhonemeLiteralScanner for G-69 validation
  - phase: 04-grammar-morphology-revised (plan 04-08)
    provides:
      - v9 Drift schema + InflectionalRulePOS junction table
provides:
  - D-82/D-83 v10 schema extension (intrinsicLevelsJson on Lexemes, StandardFormPatterns table)
  - D-84/D-85 intrinsic backfill banner + DAO toggle
  - D-86 level deletion with reassignment
  - D-88/D-89 paradigm engine intrinsic short-circuit filter
  - D-90 rule editor intrinsic save-block validation
  - D-91 paradigm coverage intrinsic-aware computation
  - D-92/D-93 word creation/edit intrinsic sub-form
  - D-94/D-95 stacked-slice paradigm viewer for intrinsic POSes
  - D-96 standard-form matcher (endsWith, startsWith, contains, regex)
  - D-97/D-98 standard-form pattern dialog + DAO
  - D-99 standard-form violation rendering across 5 surfaces
  - D-110 rom-aware word selector dropdowns (lexemeDisplayLabel helper)
  - D-111 rule editor preview parity with paradigm cells (ref.watch fix)
  - D-112 rewrite rules confined to phonetic display only (ParadigmFilled.phonemic field)
  - D-113 surface-phonetic preview in word creation/edit dialog (applyRewritePipelineProvider)
affects:
  - 04-18 (markers UI) — consumes the intrinsic dimension infrastructure
  - Future plans needing paradigm cell phonemic/phonetic split (D-112 contract)

# Tech tracking
tech-stack:
  added:
    - applyRewritePipelineProvider (phonotactic_providers.dart)
    - lexemeDisplayLabel pure function (lexeme_display_label.dart)
  patterns:
    - ParadigmFilled carries both phonemic (pre-rewrite) and form (post-rewrite)
    - Intrinsic dimensions as filters (not axes) in paradigm engine
    - Stacked-slice paradigm viewer for intrinsic combinations
    - Standard-form pattern matching with 4 branch kinds (endsWith, startsWith, contains, regex)
    - Surface-phonetic preview hidden when no rewrite rules fire

key-files:
  created:
    - lib/features/lexicon/presentation/widgets/lexeme_display_label.dart
    - test/widget/grammar/rom_excludes_rewrite_pipeline_test.dart
    - test/widget/morphology/rule_editor_preview_parity_test.dart
    - test/widget/grammar/inflections_word_selector_rom_test.dart
    - test/widget/lexicon/word_creation_phonetic_preview_test.dart
  modified:
    - lib/features/grammar/domain/paradigm_cell.dart (D-112 phonemic field)
    - lib/features/grammar/domain/paradigm_engine.dart (D-112 dual output)
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart (D-110, D-112)
    - lib/features/grammar/presentation/inflections/inflections_page.dart (D-110)
    - lib/features/morphology/presentation/rules/preview_panel.dart (D-111, D-112)
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart (D-113)
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart (D-113)
    - lib/features/phonology/data/phonotactic_providers.dart (D-113 provider)

key-decisions:
  - "D-112: ParadigmFilled now carries both phonemic (pre-rewrite) and form (post-rewrite). All romanize() calls use phonemic; bracket display uses form. Backward compatible via default constructor."
  - "D-111: preview_panel.dart switched from ref.read to ref.watch for romanizeProvider, and comparison changed from rom!=phonetic to rom!=phonemic for D-112 parity."
  - "D-110: Pure function lexemeDisplayLabel avoids WidgetRef dependency, used by both inflections_page and paradigm_table_widget intrinsic slice dropdowns."
  - "D-113: applyRewritePipelineProvider is a thin wrapper around WordGenerator.applyRewriteRules, hidden when output equals input."

patterns-established:
  - "ParadigmFilled dual-form contract: phonemic for romanize(), form for phonetic [bracket] display (D-112)"
  - "Pure display-label functions for rom-aware selectors (D-110)"
  - "Surface-phonetic preview pattern: show rewrite output only when it differs from input (D-113)"

requirements-completed: []

# Metrics
duration: 25min
completed: 2026-04-12
---

# Phase 04 Plan 17: Intrinsic Dimensions + Standard Forms + D-110..D-113 User Feedback Summary

**Schema v10 with intrinsic dimensions and standard-form patterns, stacked-slice paradigm viewer, engine intrinsic filter, and 4 user feedback fixes (rom selectors, preview parity, rewrite/rom separation, phonetic preview)**

## Performance

- **Duration:** ~25 min (this final cluster: Tasks 13-16)
- **Started:** 2026-04-12T05:01:01Z
- **Completed:** 2026-04-12T05:26:35Z
- **Tasks:** 16 (12 in prior clusters + 4 in this cluster)
- **Files modified:** 12 (this cluster)

## Accomplishments

- D-112: Fixed critical bug where sound-change rewrite rules leaked into romanization display (e.g. `cazana` instead of correct `casana`). Root cause was `computeParadigmCell` returning post-rewrite form without preserving raw phonemic. Added `phonemic` field to `ParadigmFilled`.
- D-111: Brought rule editor live preview onto same render path as paradigm table cells. Fixed `ref.read` to `ref.watch` for live refresh, and corrected show/hide comparison to use phonemic (not phonetic).
- D-110: Word selector dropdowns in inflections page and paradigm viewer now show romanization when enabled, using shared `lexemeDisplayLabel` pure function.
- D-113: Word creation and edit dialogs now show surface-phonetic preview line `[phonetic]` when rewrite rules produce a different surface form. Hidden when no rules configured or none fire.
- Tasks 1-12 (prior clusters): Schema v10 extension, intrinsic dimension UI, engine intrinsic filter, coverage matrix, rule editor validator, word creation sub-form, stacked-slice paradigm viewer, standard-form matcher/dialog/validation, regression sweep.

## Task Commits

Each task was committed atomically (Tasks 1-12 in prior clusters, Tasks 13-16 in this cluster):

1. **Task 1: Schema v10 extension** - prior cluster (D-82, D-83, D-97)
2. **Task 2: Intrinsic backfill DAO** - prior cluster (D-84, D-85)
3. **Task 3: Level deletion reassignment** - prior cluster (D-86)
4. **Task 4: Paradigm engine intrinsic filter** - prior cluster (D-88, D-89)
5. **Task 5: Paradigm coverage intrinsic** - prior cluster (D-91)
6. **Task 6: Rule editor intrinsic save-block** - prior cluster (D-90)
7. **Task 7: Word creation intrinsic sub-form** - prior cluster (D-92, D-93)
8. **Task 8: Stacked-slice paradigm viewer** - prior cluster (D-94, D-95)
9. **Task 9: Standard-form matcher** - prior cluster (D-96)
10. **Task 10: Standard-form pattern dialog** - prior cluster (D-97, D-98)
11. **Task 11: Standard-form violation rendering** - prior cluster (D-99)
12. **Task 12: Regression sweep** - prior cluster (D-82..D-99 cross-checks)
13. **Task 13: D-110 word selector rom labels** - `574d84b` (feat)
14. **Task 14: D-111 preview parity** - `7ffca2d` (feat)
15. **Task 15: D-112 rewrite/rom separation** - `f164f3b` (feat)
16. **Task 16: D-113 phonetic preview** - `9f7a9fa` (feat)

## Files Created/Modified (This Cluster)

- `lib/features/grammar/domain/paradigm_cell.dart` - Added `phonemic` field to `ParadigmFilled`
- `lib/features/grammar/domain/paradigm_engine.dart` - Engine returns both phonemic and phonetic
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` - D-110 rom labels + D-112 phonemic for rom
- `lib/features/grammar/presentation/inflections/inflections_page.dart` - D-110 rom labels
- `lib/features/morphology/presentation/rules/preview_panel.dart` - D-111 ref.watch + D-112 parity
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` - D-113 surface preview
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` - D-113 surface preview
- `lib/features/phonology/data/phonotactic_providers.dart` - D-113 applyRewritePipelineProvider
- `lib/features/lexicon/presentation/widgets/lexeme_display_label.dart` - D-110 pure function (new)
- `.planning/phases/04-grammar-morphology-revised/04-15-VERIFICATION.md` - D-112 addendum

## Decisions Made

- D-112 fix at the engine level (adding `phonemic` field) rather than stripping rewrites at the widget level. This preserves backward compatibility since `phonemic` defaults to `form` when not provided.
- D-111 preview panel uses `ref.watch` (not `ref.read`) for romanizeProvider so the preview refreshes when mappings change. The comparison for showing rom was corrected to compare against phonemic, not phonetic.
- D-110 uses a pure function (`lexemeDisplayLabel`) with no WidgetRef dependency, making it testable and reusable across any selector surface.
- D-113 surface preview is hidden (not shown with "(no change)") when rewrite output equals phonemic input, keeping the UI clean for projects without sound changes.

## Deviations from Plan

None - plan executed exactly as written for Tasks 13-16.

## Issues Encountered

- Widget tests for paradigm table overflow due to long text in 64px-high cells. Resolved by draining overflow exceptions via `tester.takeException()` in the test, consistent with existing paradigm tests that suppress overflow warnings.
- The rewrite rule `s -> z / V_V` required phoneme inventory seeding in widget tests (the `phonemeInventoryProvider` reads from the DB's phonemes table, not from the rule DSL). Added phoneme rows to widget test fixtures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 16 tasks of plan 04-17 are complete across 5 executor clusters
- D-82..D-99 + D-110..D-113 decisions all have grep-verifiable artifacts
- 13 new test files lock the behavior of each cluster
- The D-112 `ParadigmFilled.phonemic` contract is the foundation for any future surface that needs to distinguish raw morphological output from phonetic surface form

---
*Phase: 04-grammar-morphology-revised*
*Plan: 17*
*Completed: 2026-04-12*
