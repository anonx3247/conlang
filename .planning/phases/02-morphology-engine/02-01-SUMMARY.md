---
phase: 02-morphology-engine
plan: 01
subsystem: domain
tags: [petitparser, morphology, dsl, parser, tdd, dart]

requires:
  - phase: 01-foundation
    provides: PhonemeInventory class and IPA tokenization logic in word_generator.dart

provides:
  - morphology_dsl.dart: sealed class hierarchy for 8 operation types + 4 condition types, petitparser grammar, DSL serializer
  - morphology_engine.dart: MorphologyEngine.applyRule(), tokenizeIpa(), resolvePhonemeClass(), all operation applier functions
  - test/morphology_engine_test.dart: 15 unit tests covering all op types, branching, chaining, edge cases, DSL round-trip

affects:
  - 02-morphology-engine
  - 03-lexicon (will apply morphological rules to lexicon entries)

tech-stack:
  added: []
  patterns:
    - "TDD with RED commit (stubs + tests) then GREEN commit (implementation)"
    - "Sealed class hierarchy for exhaustive switch coverage of all op/condition variants"
    - "petitparser 7.x sealed Result with case Success()/Failure() pattern matching"
    - "EndsWithLiteralCond branch stripping: engine strips matched suffix before applying ops"

key-files:
  created: []
  modified:
    - lib/features/morphology/domain/morphology_dsl.dart
    - lib/features/morphology/domain/morphology_engine.dart

key-decisions:
  - "RemoveSuffixOp added to sealed class hierarchy — DSL uses -lit (bare) or -\"lit\" (quoted) form; engine strips trailing literal from working form"
  - "EndsWithLiteralCond without trailing underscore accepted by parser — \"o\" parses same as \"o\"_ for usability"
  - "tokenizeIpa and resolvePhonemeClass extracted as public top-level functions in morphology_engine.dart — no modification to word_generator.dart"
  - "EndsWithLiteralCond match causes engine to auto-strip the matched suffix from working form before applying branch ops"

patterns-established:
  - "Condition parser tries underscore forms before bare-literal form to avoid ambiguity"
  - "Operation parser order: ablaut | redup | supplete | removeSuffixQuoted | removeSuffixBare | suffix | template | prefix"

duration: 15min
completed: 2026-04-09
---

# Phase 2 Plan 01: Morphology DSL and Engine Summary

**petitparser-powered morphology DSL with 8 operation types, 4 condition types, and a pure-Dart evaluation engine covering suffix/prefix/infix/ablaut/template/reduplication/suppletive/strip operations**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-09T00:00:00Z
- **Completed:** 2026-04-09T00:15:00Z
- **Tasks:** 2 (Task 1 was pre-committed; Task 2 executed in this session)
- **Files modified:** 2

## Accomplishments

- Full morphology DSL data model: 8 `MorphOperation` subtypes, 4 `MorphCondition` subtypes, `MorphBranch`, `MorphologicalRule`, `ParsedMorphRule`
- petitparser 7.x grammar parsing all operation and condition forms with correct operator precedence
- DSL serializer round-trips all forms; condition and op serialization is exhaustively handled via sealed switch
- `MorphologyEngine.applyRule()` evaluates branches in order, strips `EndsWithLiteralCond` suffix from working form before ops, chains operations sequentially
- Public `tokenizeIpa()` and `resolvePhonemeClass()` extracted without touching `word_generator.dart`
- All 15 unit tests pass; `dart analyze` reports no issues

## Task Commits

1. **Task 1: RED — Write failing tests for all operation types, branching, and edge cases** - `5ae0401` (test)
2. **Task 2: GREEN + REFACTOR — Implement DSL model, parser, serializer, and engine** - `b33262f` (feat)

**Plan metadata:** _(this commit)_

## Files Created/Modified

- `lib/features/morphology/domain/morphology_dsl.dart` — sealed class hierarchy, petitparser grammar, serializer
- `lib/features/morphology/domain/morphology_engine.dart` — tokenizeIpa, resolvePhonemeClass, all applier functions, MorphologyEngine

## Decisions Made

- `RemoveSuffixOp` added to the sealed class hierarchy to make `-o` stripping a first-class operation rather than a parser-only side-effect; enables DSL round-trip for branches with explicit strip ops
- `EndsWithLiteralCond` condition is accepted both with trailing `_` (`"o"_`) and without (`"o"`); the bare form is more natural in multi-branch rules; serializer always emits the `_` form for canonical round-trips
- Engine strips `EndsWithLiteralCond` matched suffix automatically before applying ops, so the branch does not double-strip when `RemoveSuffixOp` is absent

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added RemoveSuffixOp to sealed class hierarchy**
- **Found during:** Task 2 (GREEN — making test 15 pass)
- **Issue:** Test 15 (`[C_] +in | [V_] +ain | "o" -o +in`) requires parsing `-o` as a strip operation. The plan's sealed class listed 7 ops with no remove-suffix type, and the stub comment deferred the decision. Without a proper op type, the exhaustive `_applyOp` switch would be incomplete and the DSL could not round-trip branches containing `-lit`.
- **Fix:** Added `RemoveSuffixOp(suffix)` as the 8th sealed subclass; updated parser to recognise both `-"lit"` (quoted) and `-lit` (bare); updated `_serializeOp` and `_applyOp` switch arms.
- **Files modified:** lib/features/morphology/domain/morphology_dsl.dart, lib/features/morphology/domain/morphology_engine.dart
- **Verification:** All 15 tests pass; dart analyze no issues
- **Committed in:** b33262f (Task 2 commit)

**2. [Rule 2 - Missing Critical] Added bare-quoted condition form "lit" (no trailing underscore)**
- **Found during:** Task 2 (GREEN — making test 15 parse correctly)
- **Issue:** Test 15 uses `"o"` without trailing `_` as a branch condition. The original parser only recognised `"o"_` (with underscore). The bare form is more natural in multi-branch DSL strings.
- **Fix:** Added `endsWithLitBare` parser alternative tried after `endsWithLitUnderscore` in the condition parser; both produce `EndsWithLiteralCond`.
- **Files modified:** lib/features/morphology/domain/morphology_dsl.dart
- **Verification:** Test 15 passes; round-trip test still passes (serializer emits `_` form)
- **Committed in:** b33262f (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 2 — missing critical functionality)
**Impact on plan:** Both required to complete the 15th test and achieve a fully round-trippable DSL. No scope creep; both are direct completions of intended design.

## Issues Encountered

- `[$classRef_]` string interpolation: Dart parser treated `classRef_` as the variable name (underscore valid in identifiers). Required `[${classRef}_]` with explicit braces. Caught by `dart analyze` immediately.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Morphology engine is feature-complete: all 8 operation types, 4 condition types, branch evaluation, DSL parse/serialize
- `MorphologyEngine.applyRule(rule, root, inventory)` ready for use by Plan 03 (UI) and Plan 04 (integration)
- `parseMorphDsl(source)` + `serializeMorphRule(rule)` ready for DB storage/retrieval layer
- No blockers for subsequent plans

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
