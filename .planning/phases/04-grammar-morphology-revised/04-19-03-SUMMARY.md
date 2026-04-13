---
phase: 04-grammar-morphology-revised
plan: 19-03
subsystem: grammar/morphology
tags: [gap-closure, standard-form, derivation, rule-editor]
dependency_graph:
  requires: [04-19-02]
  provides: [standard-form-violation-preview-in-derivation-editor]
  affects: [rule_editor_dialog.dart]
tech_stack:
  added: []
  patterns: [FutureBuilder async DAO lookup, ConsumerWidget inline engine evaluation]
key_files:
  created: []
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
decisions:
  - "Compute sample output form independently in _StandardFormDerivationWarning by running the engine on a generated candidate word — avoids modifying PreviewPanel or adding a shared state channel"
  - "Use decodeLevelsJson (already imported via dimension_level.dart) rather than IntrinsicLevelsCodec.decode — both decode levelsJson but decodeLevelsJson returns typed DimensionLevel objects needed for level.name/level.id"
  - "FutureBuilder wraps async dao.getPattern calls — consistent with existing standard_form_validation_provider pattern; lightweight enough given small branch counts per dimension"
metrics:
  duration: 8 min
  completed: 2026-04-12T17:58:30Z
  tasks: 1
  files: 1
requirements: [GRAM-04, GRAM-06, GRAM-07]
---

# Phase 04 Plan 19-03: Standard Form Violation Preview in Derivation Rule Editor Summary

**One-liner:** Derivation rule editor now shows a warning banner when the computed preview form violates standard-form patterns for the output POS's intrinsic dimensions, using `_StandardFormDerivationWarning` + `StandardFormMatcher`.

## What Was Built

Closed gap 3 from `04-18-VERIFICATION.md`:

**Gap 3 — Derivation rule editor had no standard form violation feedback:**
- Users defining a derivation rule (e.g. "add -or to make actor nouns") had no way to know whether the derived forms would violate standard-form patterns for the output POS until after saving and checking the lexicon.
- Added `_StandardFormDerivationWarning` — a `ConsumerWidget` that:
  1. Applies the live `previewRule` to a generated sample word using `MorphologyEngine`
  2. Romanizes the output via `romanizeProvider`
  3. Fetches intrinsic dimension patterns for `outputPosId` via `standardFormPatternDaoProvider`
  4. Checks the romanized form against all patterns using `StandardFormMatcher`
  5. Renders a warning banner (`errorContainer` background + `Icons.warning_amber_outlined`) listing each violation
- Wired below `PreviewPanel` in the derivational mode right column, guarded by `widget.kind == RuleKind.derivational && _outputPosId != null && previewRule != null`

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Standard form violation preview in derivational rule editor | 24ed7cc | rule_editor_dialog.dart |

## Decisions Made

1. **Independent engine evaluation:** Rather than sharing `PreviewPanel`'s internal `_rows` state (which would require adding a callback parameter to that widget), `_StandardFormDerivationWarning` independently applies the same `previewRule` to a generated sample word. This is functionally equivalent — the same rule produces the same class of outputs — and avoids coupling two widgets via shared state.

2. **`decodeLevelsJson` over `IntrinsicLevelsCodec.decode`:** The check iterates intrinsic dimensions and needs `DimensionLevel` objects (for `level.name` and `level.id`). `decodeLevelsJson` is already imported via `dimension_level.dart` and returns exactly that type. `IntrinsicLevelsCodec.decode` returns `Map<int,int>` which would require an extra lookup step.

3. **FutureBuilder for async DAO:** `dao.getPattern` is async. The `FutureBuilder` approach mirrors the pattern used in `standard_form_validation_provider.dart` and keeps the widget self-contained without needing a new Riverpod provider.

## Deviations from Plan

None — plan executed as written. The plan explicitly offered the `ValueNotifier` callback approach or independent engine evaluation as alternatives; independent evaluation was chosen as the cleaner path (no `PreviewPanel` modification needed).

## Known Stubs

None.

## Threat Flags

None — internal UI preview widget, no new trust boundaries (consistent with plan's threat model T-04-19-03-01 accept disposition).

## Self-Check: PASSED

- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — exists
- Contains `_StandardFormDerivationWarning` class (line 2232)
- Imports `standard_form_matcher.dart`, `standard_form_branch.dart`, `standard_form_pattern_dao.dart`, `morphology_engine.dart`
- Warning wired with `widget.kind == RuleKind.derivational && _outputPosId != null && previewRule != null` guard (lines 1537–1543)
- `Icons.warning_amber_outlined` + `cs.errorContainer` used (lines 2309–2315)
- `dart analyze` — No issues found
- Commit 24ed7cc — verified
