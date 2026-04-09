---
phase: 02-morphology-engine
plan: 04
subsystem: ui
tags: [flutter, morphology, dsl, ux, verification]

# Dependency graph
requires:
  - phase: 02-03
    provides: Morphology tab, RulesPage, RuleEditorDialog, PreviewPanel, full rule editor UI
provides:
  - Human-verified end-to-end morphology engine (all 6 test cases passing)
  - Documented UX gap list (9 items) for gap closure planning
affects: [phase-03-lexicon, phase-04-grammar, gap-closure-plans]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "9 UX improvement items identified during UAT will be addressed as gap closure plans, not inline fixes — scope boundary kept clean"
  - "Suppletive strategy and remove-suffix DSL notation need UX clarification (jargon and operation labeling)"
  - "Condition system will be redesigned around phonological pattern syntax: [nasal]Vk(l) style with multiple conditions per branch"

patterns-established: []

# Metrics
duration: checkpoint
completed: 2026-04-09
checkpoint_result: approved
---

# Phase 2 Plan 04: Morphology Engine Verification Summary

**End-to-end morphology engine verified by user — all 6 test cases approved, 9 UX gaps identified for gap closure**

## Performance

- **Duration:** Checkpoint (human-verify gate)
- **Started:** 2026-04-09
- **Completed:** 2026-04-09
- **Tasks:** 1 of 2 (Task 2 "Apply UI fixes" skipped — no blocking fixes needed)
- **Files modified:** 0 (verification-only plan)

## Accomplishments

- User confirmed all 6 morphology engine verification tests pass end-to-end
- Suffix/concatenative, branching environment-sensitive, template (Semitic root-and-pattern), and ablaut strategies all produce correct output in preview
- Rule CRUD (create, read, update, delete) confirmed working
- Error handling confirmed: missing-default-branch shows inline error in preview
- 9 UX improvement items captured for gap closure planning

## Task Commits

1. **Task 1: Checkpoint — human verification gate** — no code commit (human approval step)
2. **Task 2: Apply UI fixes** — skipped (no blocking fixes reported; 9 items deferred to gap closure)

**Plan metadata:** (this commit)

## Files Created/Modified

None — verification-only plan; no code changes made.

## Decisions Made

- Task 2 skipped as "No fixes needed" per plan instructions — the 9 user-identified items are UX improvements, not blockers for Phase 2 completion.
- All 9 items will be tracked as gap closure plans before Phase 3 begins or alongside it, per user direction.

## Deviations from Plan

None — plan executed exactly as written. Checkpoint approved; Task 2 skip path invoked because no blocking UI issues were reported.

## Issues Encountered

None — engine works as designed. The 9 items below are UX gaps, not defects.

## User Feedback — UX Gaps for Gap Closure

The following 9 items were identified during UAT. They are NOT bugs in the current implementation; they are UX improvements to be addressed as dedicated gap closure plans.

1. **Jargon clarity** — "Suppletive" operation name unclear; "remove o" operation label does not communicate that it targets the final `o` specifically. Labels need plain-language rewording.
2. **Missing IPA keyboards in morphology** — Affix input fields, condition literal fields, and ablaut from/to fields lack the IPA keyboard popup available elsewhere in the app.
3. **Rule reordering** — Rules list has no drag-to-reorder or up/down buttons; application order is fixed by creation order.
4. **POS-based rule filtering** — No way to restrict a rule to a specific part of speech. Requires: (a) POS definition tab in the Morphology section, (b) optional POS filter on each rule.
5. **Condition pattern redesign** — Current condition types (EndsWithLiteral, StartsWithLiteral, phoneme-class variants) are insufficient. Needed: pattern-based conditions using phonological notation `[nasal]Vk(l)`, with multiple conditions combinable per branch.
6. **Preview font** — Preview panel uses default font; should use monospace to match the app's DSL/code aesthetic.
7. **Preview regen button** — Preview panel has no manual regenerate button (unlike the Word Generator panel). Should add a regen button alongside the debounce.
8. **Phonotactic violation highlighting** — Preview derived forms should flag words that violate the project's phonotactic templates (highlight or annotate violations).
9. **Multi-rule stacking preview** — Preview currently applies one rule at a time. Conlangers need to see plural + gender (or other stacked rules) applied together to catch interaction bugs.

## Next Phase Readiness

- Phase 2 (Morphology Engine) is complete from a functional standpoint. All ROADMAP.md success criteria are met.
- Before or alongside Phase 3 (Lexicon), gap closure plans should address items 1-9 above.
- Phase 3 depends on: morphological rules being stable so lexicon entries can link to rules for derivation. Items 3-5 (reordering, POS, condition redesign) are the highest-priority gaps before lexicon authoring begins.
- Items 2, 6, 7 are polish — can be addressed in parallel with Phase 3.
- Items 8, 9 require PreviewPanel changes only — no schema impact.

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
