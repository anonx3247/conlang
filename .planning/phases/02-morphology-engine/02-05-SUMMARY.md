---
phase: 02-morphology-engine
plan: 05
subsystem: morphology
tags: [petitparser, dsl, flutter, dart, tdd]

# Dependency graph
requires:
  - phase: 02-01
    provides: morphology_dsl.dart with InfixOp domain class and _buildOperationParser()
provides:
  - InfixOp DSL round-trip: infix:um:1 serializes and parses back losslessly
  - ROADMAP.md Phase 2 SC4 formally deferred to Phase 3 with rationale
affects: [02-06, 02-07, 02-08, 02-09, 02-10, 03-lexicon]

# Tech tracking
tech-stack:
  added: []
  patterns: [TDD RED-GREEN — proved bug with failing test before fixing parser]

key-files:
  created: []
  modified:
    - lib/features/morphology/domain/morphology_dsl.dart
    - test/morphology_engine_test.dart
    - .planning/ROADMAP.md

key-decisions:
  - "02-05: infix: parser uses pattern('^|:').plus() for affix and pattern('0-9').plus() for position — mirrors redup pattern exactly; placed after redup and before supplete in choice order"
  - "02-05: Exception UI (Phase 2 SC4) formally deferred to Phase 3 — schema + DAO complete, UI entry point is word detail page which belongs in Phase 3 Lexicon"

patterns-established:
  - "TDD pattern: RED proves bug exists before GREEN fixes it — infix: parse error confirmed at position 10 before fix"

# Metrics
duration: 2min
completed: 2026-04-09
---

# Phase 2 Plan 05: InfixOp DSL Fix + Exception UI Deferral Summary

**petitparser infix: case added to _buildOperationParser() — InfixOp rules now survive save/reload with lossless DSL round-trip (16/16 tests green)**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-09T09:24:43Z
- **Completed:** 2026-04-09T09:26:05Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed data-loss blocker: InfixOp rules written to DB can now be reloaded — serializer emitted `infix:um:1` but parser had no `infix:` case (silently dropped operation on reload)
- TDD proof: RED test confirmed parse failure at position 10, GREEN added parser case, all 16 tests now pass
- Formally documented Phase 2 SC4 exception UI deferral in ROADMAP.md with schema/DAO completion status and Phase 3 rationale

## Task Commits

Each task was committed atomically:

1. **Task 1: InfixOp DSL round-trip fix (TDD)** — `b249a8c` (feat)
2. **Task 2: Defer exception UI to Phase 3 in ROADMAP.md** — `83527ac` (docs)

**Plan metadata:** (final commit after SUMMARY + STATE updates)

_Note: TDD task had single commit combining RED test + GREEN fix per plan (no refactor needed)._

## Files Created/Modified
- `/Users/neosapien/dev/conlang/lib/features/morphology/domain/morphology_dsl.dart` — Added `infix:` parser case in `_buildOperationParser()`, inserted between `redup` and `supplete` in choice order
- `/Users/neosapien/dev/conlang/test/morphology_engine_test.dart` — Added test group `'InfixOp DSL round-trip'` (test 16): serializes to `infix:um:1`, parses back to `InfixOp(affix:'um', position:1)`
- `/Users/neosapien/dev/conlang/.planning/ROADMAP.md` — Phase 2 SC4 updated with deferral note and rationale

## Decisions Made
- `infix:` parser uses `pattern('^|:').plus()` for affix (stops at space or colon) and `pattern('0-9').plus()` for position — directly mirrors the `redup:scope:position` pattern already in the file
- Exception UI (Phase 2 SC4) formally deferred to Phase 3 — the MorphologicalRuleExceptions table, insertException/deleteException/watchExceptionsForRule/findStaleExceptions DAO, and schema v4 migration are all complete; only the UI entry point is missing and it naturally belongs in the word detail page (Phase 3 Lexicon, plan 03-02)

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None — the bug was exactly as described. Parser had no `infix:` case, causing petitparser to fall through to `prefix` which expected a `+` suffix and failed at position 10.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- InfixOp DSL gap is closed; morphology engine is fully round-trip safe for all 8 operation types
- Phase 2 gap closure continues: plans 06–10 remain (jargon clarity, rule reordering, POS filtering, condition redesign, preview enhancements)
- Phase 3 Lexicon can proceed once gap closure plans complete — exception UI entry point will be 03-02 (word detail panel)

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*

## Self-Check: PASSED

- morphology_dsl.dart — FOUND
- morphology_engine_test.dart — FOUND
- ROADMAP.md — FOUND
- 02-05-SUMMARY.md — FOUND
- Commit b249a8c — FOUND
- Commit 83527ac — FOUND
