---
phase: 03-lexicon
plan: 05
subsystem: shared-widgets, lexicon-data, phonology-presentation, morphology-presentation
tags: [violation-text, phonotactic-validation, shared-widget, refactor, tdd]
requirements: [PHON-05]

dependency_graph:
  requires:
    - lib/features/phonology/domain/word_generator.dart (Violation, ValidationResult types)
    - lib/features/phonology/data/phonotactic_providers.dart (parsedConstraintsProvider, phonemeInventoryProvider)
  provides:
    - lib/shared/widgets/violation_text.dart (ViolationText — shared widget)
    - lib/features/lexicon/data/phonotactic_validation_provider.dart (phonotacticValidatorProvider)
  affects:
    - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart (refactored to use shared widget)
    - lib/features/morphology/presentation/rules/morphology_preview_panel.dart (refactored to use shared widget)

tech_stack:
  added: []
  patterns:
    - Shared widget extraction from private to public for cross-feature reuse
    - Riverpod Provider wrapping a pure function closure for injectable validation

key_files:
  created:
    - lib/shared/widgets/violation_text.dart
    - lib/features/lexicon/data/phonotactic_validation_provider.dart
    - test/lexicon/phonotactic_validation_test.dart
  modified:
    - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart
    - lib/features/morphology/presentation/rules/morphology_preview_panel.dart

decisions:
  - ViolationText accepts List<Violation> directly (not ValidationResult) — cleaner call sites; callers already have violations list
  - phonotacticValidatorProvider returns a closure function (not ValidationResult) — caller passes word at call time, enabling use in list builders without per-word providers
  - Tooltip uses pipe-separated (' | ') descriptions matching UI-SPEC Copywriting Contract
  - morphology_preview_panel.dart inline violation rendering replaced (not just word_generator_panel) to establish single source of truth

metrics:
  duration: 12 min
  completed: "2026-04-09"
  tasks_completed: 1
  files_changed: 5
---

# Phase 3 Plan 05: Shared ViolationText Widget and Phonotactic Validation Provider Summary

Extracted the private `_ViolationText` widget from the phonology word generator panel into a public shared widget at `lib/shared/widgets/violation_text.dart`, and created a `phonotacticValidatorProvider` at `lib/features/lexicon/data/phonotactic_validation_provider.dart` — delivering the PHON-05 shared infrastructure that Plan 03-06 will wire into the lexicon detail panel.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| TDD RED | Add phonotactic validation unit tests | def6b52 | test/lexicon/phonotactic_validation_test.dart |
| TDD GREEN | Extract shared ViolationText + create validation provider | ee8c387 | lib/shared/widgets/violation_text.dart, lib/features/lexicon/data/phonotactic_validation_provider.dart, word_generator_panel.dart, morphology_preview_panel.dart |

## What Was Built

**`lib/shared/widgets/violation_text.dart`** — `ViolationText extends StatelessWidget`:
- Accepts `text` (IPA word), `violations` (list), optional `style`
- Renders plain `Text` when no violations
- Renders `RichText` with `TextDecoration.underline` + `TextDecorationStyle.wavy` + `decorationColor: cs.error` on violated character ranges
- Wraps in `Tooltip` with pipe-separated violation descriptions when violations present

**`lib/features/lexicon/data/phonotactic_validation_provider.dart`** — `phonotacticValidatorProvider`:
- Riverpod `Provider` returning a `ValidationResult Function({required String word})` closure
- Watches `parsedConstraintsProvider` and `phonemeInventoryProvider`
- Usable from lexicon detail panel, morphology preview, or any text field

**Updated `word_generator_panel.dart`**:
- Removed private `_ViolationText` class (63 lines)
- Replaced `_ViolationText(word: word, violations: violations)` and surrounding `Tooltip` wrapper with single `ViolationText(text: word, violations: violations)`
- Added import of shared widget

**Updated `morphology_preview_panel.dart`**:
- Replaced inline `Tooltip` + conditional `Text`/styled-`Text` violation rendering with `ViolationText(text: derived!, violations: violations)`
- Added import of shared widget

## Deviations from Plan

**1. [Rule 2 - Critical] Updated morphology_preview_panel.dart inline rendering**
- Found during: Task 1 (step 4 check)
- Issue: `morphology_preview_panel.dart` had its own inline violation rendering (Tooltip + conditional styled Text) rather than delegating to any shared widget
- Fix: Replaced inline rendering with `ViolationText` import + usage — establishes single source of truth per plan step 4 instruction
- Files modified: `lib/features/morphology/presentation/rules/morphology_preview_panel.dart`
- Commit: ee8c387

**Pre-existing issue (out of scope):** `test/phonotactic_dsl_smoke_test.dart` line 72 assertion `!c1.rule!.isForbidden` was already failing before this plan's changes. Logged to deferred-items — not caused by this plan.

## Known Stubs

None — all wiring is complete. `phonotacticValidatorProvider` is a fully functional provider ready for consumption. `ViolationText` renders correctly. No placeholder data or TODO stubs.

## Threat Flags

None. No new network endpoints, auth paths, or file access patterns introduced. The `phonotacticValidatorProvider` validates in-memory word strings against in-memory constraint lists — consistent with the existing threat model entry T-03-12 (O(word_length * constraint_count) per call, acceptable for single-word use).

## Self-Check: PASSED

All created files exist on disk. Both commits (def6b52, ee8c387) verified in git log.
