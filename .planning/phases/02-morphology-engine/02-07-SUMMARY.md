---
phase: 02-morphology-engine
plan: 07
subsystem: ui
tags: [flutter, drift, morphology, reordering]

# Dependency graph
requires:
  - phase: 02-morphology-engine
    provides: MorphologyDao, MorphologicalRules table with ordering column, RulesPage ListView

provides:
  - swapOrdering(ruleIdA, ruleIdB) on MorphologyDao — atomic swap in DB transaction
  - nextOrdering() on MorphologyDao — max(ordering)+1 for end-of-list insertion
  - Up/down arrow buttons on every rule card in RulesPage

affects:
  - 02-morphology-engine gap closure plans (rule ordering now user-controllable)
  - Phase 3 lexicon authoring (morphological rule order affects derivation results)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Swap ordering values in a transaction to avoid mid-swap constraint violations"
    - "Disabled state via null onPressed + Opacity(opacity: 0.2) for icon buttons"

key-files:
  created: []
  modified:
    - lib/features/morphology/data/morphology_dao.dart
    - lib/features/morphology/presentation/rules/rules_page.dart

key-decisions:
  - "02-07: swapOrdering uses drift transaction() to atomically exchange ordering values — no temp value needed; Drift handles the intermediate state"
  - "02-07: Disabled arrow buttons shown at 20% opacity via Opacity widget rather than hiding — provides affordance that reordering exists even for boundary items"
  - "02-07: New rules get ordering=0 default; users can move them down — avoids touching rule_editor_dialog.dart scope"

patterns-established:
  - "Compact IconButton pattern: visualDensity: VisualDensity.compact + BoxConstraints(minWidth: 28, minHeight: 28) + icon size 18"

# Metrics
duration: 1min
completed: 2026-04-09
---

# Phase 02 Plan 07: Rule Reordering Summary

**Up/down arrow buttons on rule cards backed by atomic DB transaction swap of ordering column values — morphological rule application order is now user-controllable and persisted**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-04-09T09:24:49Z
- **Completed:** 2026-04-09T09:25:43Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `swapOrdering(ruleIdA, ruleIdB)` method added to `MorphologyDao` — wraps two updates in a Drift `transaction()` to atomically exchange ordering values between two rules
- `nextOrdering()` method added to `MorphologyDao` — returns `max(ordering)+1` via raw SQL for inserting new rules at the end of the list
- Up/down `IconButton` widgets added to each rule card in `RulesPage`, positioned between the name/source column and the active Switch
- Boundary conditions handled: up button disabled at index 0, down button disabled at last index; both shown at 20% opacity to communicate state

## Task Commits

Each task was committed atomically:

1. **Task 1: DAO reorder method + nextOrdering** - `66603e1` (feat)
2. **Task 2: Up/down reorder buttons on rule cards** - `ef69e1e` (feat)

## Files Created/Modified
- `lib/features/morphology/data/morphology_dao.dart` — added `swapOrdering()` and `nextOrdering()`
- `lib/features/morphology/presentation/rules/rules_page.dart` — added up/down `IconButton` widgets in `ListView.builder` itemBuilder

## Decisions Made
- `swapOrdering` uses `transaction()` to swap ordering values — no need for a temp/sentinel value since Drift handles intermediate state within a transaction
- Disabled arrows rendered at 20% `Opacity` rather than hidden — preserves layout stability and signals the affordance exists at boundaries
- New rules retain `ordering=0` default — acceptable since users can reorder after creation; avoids expanding scope to `rule_editor_dialog.dart`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `test/widget_test.dart` (untracked flutter scaffold file, never committed) reports `MyApp isn't a class` — pre-existing, not introduced by this plan. All `lib/` files analyze clean.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Rule reordering (UAT gap 3) is now closed — users can control morphological rule application order and it persists to the database
- Remaining gap closure plans: 05 (preview live update), 06 (conditions redesign), 08 (empty-state hints), 09 (preview tab improvements), 10 (misc polish)
- Ready for Phase 3 lexicon authoring — morphological rule order is now a controllable user variable

## Self-Check: PASSED

- lib/features/morphology/data/morphology_dao.dart — FOUND
- lib/features/morphology/presentation/rules/rules_page.dart — FOUND
- .planning/phases/02-morphology-engine/02-07-SUMMARY.md — FOUND
- Commit 66603e1 (Task 1) — FOUND
- Commit ef69e1e (Task 2) — FOUND

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
