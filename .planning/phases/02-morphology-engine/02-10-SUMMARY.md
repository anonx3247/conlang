---
phase: 02-morphology-engine
plan: 10
subsystem: ui
tags: [flutter, riverpod, morphology, phonotactics, preview]

# Dependency graph
requires:
  - phase: 02-morphology-engine
    provides: "MorphologyEngine, preview panel, phonotactic constraints via parsedConstraintsProvider"
  - phase: 02-06-SUMMARY
    provides: "IpaTextField in condition fields, regenerate button in preview panel"
provides:
  - "Phonotactic violation highlighting (wavy red underline + tooltip) on derived forms in preview"
  - "Multi-rule stack mode toggle in preview panel showing sequential application of all active rules"
affects:
  - phase-03-lexicon

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ref.read(parsedConstraintsProvider).asData?.value for sync constraint reads inside evaluate()"
    - "ref.read(morphologicalRuleListProvider).asData?.value for stack mode rule list access"
    - "ValidationResult from WordGenerator.validateWord used in UI layer for phonotactic feedback"

key-files:
  created: []
  modified:
    - lib/features/morphology/presentation/rules/preview_panel.dart

key-decisions:
  - "ValidationResult read via ref.read (not ref.watch) inside _evaluate() — avoid unnecessary rebuilds; _evaluate is already debounce-driven"
  - "Stack mode uses ref.read(morphologicalRuleListProvider) instead of widget param — ConsumerStatefulWidget already in scope, avoids threading param through calling sites"
  - "MorphNoMatch in stack mode skips rule and continues with current form (no abort) — matches plan spec, avoids one non-matching rule destroying the whole chain"
  - "Tasks 1 and 2 committed together as single atomic commit — both modify only preview_panel.dart and _PreviewRow class design is shared"

patterns-established:
  - "ValidationResult.violations used to add wavy error decoration — pattern can be reused in lexicon word detail views"

# Metrics
duration: 10min
completed: 2026-04-09
---

# Phase 2 Plan 10: Preview Panel Phonotactics & Stacking Summary

**Wavy-red violation underlines on derived forms using WordGenerator.validateWord, plus a layers-icon stack mode that chains all active rules sequentially in the preview panel**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-09T09:28:14Z
- **Completed:** 2026-04-09T09:38:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Derived forms that violate phonotactic constraints now show a wavy red underline with a tooltip listing each violation and its position
- Stack mode toggle (layers icon in preview header) switches between single-rule and multi-rule chain preview
- Stack mode reads all active rules from `morphologicalRuleListProvider`, replaces the current rule with the in-progress edit, and applies the chain left-to-right
- `MorphNoMatch` rules are silently skipped so a non-matching rule in the chain doesn't abort the whole preview

## Task Commits

Both tasks modify only `preview_panel.dart` — committed atomically:

1. **Task 1 + Task 2: Violation highlighting and stack mode** - `1ad7eb2` (feat)

## Files Created/Modified
- `lib/features/morphology/presentation/rules/preview_panel.dart` - Added `violations`/`rulesApplied`/`stackMode` to `_PreviewRow`; wavy-red underline logic in `_buildRow`; `_stackMode` state variable and layers toggle in header; stack evaluation path in `_evaluate()`

## Decisions Made
- `ref.read` inside `_evaluate()` for constraints and rule list — avoids triggering extra rebuilds; `_evaluate` is already on a 300ms debounce timer
- Stack mode silently skips `MorphNoMatch` rules rather than aborting — matches plan spec and is the correct linguistic semantics (a rule that doesn't apply is a no-op, not an error)
- Both tasks committed as one: single file, shared class design makes them inseparable at the diff level

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
- First `git commit` attempt failed because the previous `git add` ran in a shell context that didn't persist the staging. Re-ran `git add` + `git commit` in a single chained command and it succeeded.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- UAT gaps 8 and 9 (phonotactic violation preview, multi-rule stacking) are now closed
- All 10 plans in Phase 2 are complete
- Phase 3 (Lexicon) can begin; word detail views can reuse the `ValidationResult` pattern from this plan

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
