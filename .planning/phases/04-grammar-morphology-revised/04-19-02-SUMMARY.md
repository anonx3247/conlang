---
phase: 04-grammar-morphology-revised
plan: 19-02
subsystem: grammar/morphology
tags: [gap-closure, standard-form, paradigm-viewer, romanization]
dependency_graph:
  requires: [04-18-02, 04-18-03]
  provides: [correct-standard-form-validation, tight-single-dim-paradigm-table]
  affects: [standard_form_validation_provider, paradigm_table_widget]
tech_stack:
  added: []
  patterns: [romanizeProvider, IntrinsicWidth]
key_files:
  created: []
  modified:
    - lib/features/grammar/data/standard_form_validation_provider.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
decisions:
  - "Use romanizeProvider to convert lexeme.ipa before passing to StandardFormMatcher — patterns are entered as romanized text, not phonemic IPA"
  - "IntrinsicWidth wraps Column inside SingleChildScrollView in _buildSingleDimTable to constrain table width to content (N levels x 80px)"
metrics:
  duration: 8 min
  completed: 2026-04-12T17:47:34Z
  tasks: 2
  files: 2
requirements: [GRAM-03, GRAM-05]
---

# Phase 04 Plan 19-02: Standard Form Validation + Single-Dim Paradigm Fix Summary

**One-liner:** Standard form patterns now match against romanized lexeme forms via `romanizeProvider`, and single-dimension paradigm tables are constrained to content width via `IntrinsicWidth`.

## What Was Built

Closed gaps 1 and 2 from `04-18-VERIFICATION.md`:

**Gap 1 — Standard form validation used phonemic IPA instead of romanized form:**
- `standardFormViolationsProvider` previously called `matcher.matches(lexeme.ipa, ...)` — patterns entered as e.g. "ar" or "Vr" (romanized) never matched phonemic IPA stored in the database.
- Fixed by importing `romanization_providers.dart`, watching `romanizeProvider`, and converting `lexeme.ipa → romForm` before the matcher call. Violation length also updated to `romForm.length`.

**Gap 2 — Single-row paradigm table had excessive trailing empty space:**
- `_buildSingleDimTable` wrapped content in `SingleChildScrollView(scrollDirection: Axis.horizontal)` but its `Column` child expanded to parent full width.
- Fixed by inserting `IntrinsicWidth(child: Column(...))` between the scroll view and the column, constraining the scroll view's internal width to the actual content.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix standard form validation to use romanized form | 0ff52e7 | standard_form_validation_provider.dart |
| 2 | Fix single-row paradigm table trailing empty space | b0b0667 | paradigm_table_widget.dart |

## Decisions Made

1. **romanizeProvider approach:** Watch `romanizeProvider` (a `Provider<String Function(String)>`) inside the `FutureProvider.family` body — this is the established pattern in the codebase for obtaining the romanization function.

2. **IntrinsicWidth vs Align:** Chose `IntrinsicWidth` per plan specification. It tightly constrains to actual child measurement width, more precise than `Align(widthFactor: 1.0)` which would also work but measures differently.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — both changes are internal rendering/validation with no new trust boundaries.

## Self-Check: PASSED

- `lib/features/grammar/data/standard_form_validation_provider.dart` — exists, contains `romanizeProvider`, `romanize(lexeme.ipa)`, `romForm.length`
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — exists, contains `IntrinsicWidth(` at line 580
- Commit 0ff52e7 — verified in git log
- Commit b0b0667 — verified in git log
- `dart analyze` — no issues on both files
