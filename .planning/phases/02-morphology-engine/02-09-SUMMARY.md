---
phase: 02-morphology-engine
plan: 09
subsystem: morphology
tags: [flutter, dart, petitparser, phonological-patterns, DSL, condition-system]

requires:
  - phase: 02-morphology-engine
    provides: morphology DSL + engine (plans 01, 05, 06)

provides:
  - PatternCond sealed class replacing 4 old condition types
  - Phonological pattern notation parser [class]CVlit(opt)_ in engine
  - Multi-condition branches with AND logic
  - Backward-compatible migration parser for old DSL syntax
  - Pattern-based condition UI in rule editor dialog

affects:
  - 02-10 (final gap closure plan, may reference condition system)
  - Phase 03 (lexicon will use morphology engine with new condition system)

tech-stack:
  added: []
  patterns:
    - "PatternCond: single condition class replaces 4 type-specific variants — pattern string encodes everything"
    - "MorphBranch.conditions is List<MorphCondition> — empty = default, non-empty = AND logic"
    - "DSL parser: new {pattern} syntax + backward-compat migration layer for old [C_]/\"lit\"_ forms"
    - "Pattern matching: left-to-right segment matcher, anchor flags from leading/trailing _"

key-files:
  created: []
  modified:
    - lib/features/morphology/domain/morphology_dsl.dart
    - lib/features/morphology/domain/morphology_engine.dart
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - test/morphology_engine_test.dart

key-decisions:
  - "02-09: PatternCond uses raw string with _ anchors (V_ = ends-with-vowel, _CV = starts-with-CV) — minimal syntax, composable with optional groups (Vk(l)_)"
  - "02-09: MorphBranch.condition (single nullable) replaced by MorphBranch.conditions (list) — AND logic by convention, empty list = default branch"
  - "02-09: Old condition DSL syntax migrated transparently in parser — [C_] -> PatternCond('[C]_'), \"o\"_ -> PatternCond('o_') — no DB migration needed"
  - "02-09: Auto-strip of matched suffix removed from engine — PatternCond is purely a match check; stripping must be done explicitly via RemoveSuffixOp"
  - "02-09: CondType enum removed from rule editor — replaced by condPatternCtrls: List<TextEditingController> for direct pattern entry with IpaTextField"

patterns-established:
  - "Pattern-based conditions: all phonological environments expressed as a single string using [] C V literal (optional) _ notation"
  - "Condition section in rule editor uses Add condition (AND) button pattern — one IpaTextField per condition in the list"

duration: 35min
completed: 2026-04-09
---

# Phase 2 Plan 9: Phonological Pattern Conditions Summary

**PatternCond replaces 4 old condition types with phonological notation ([nasal]V_, _CV, Vk(l)_), multi-condition AND logic per branch, and backward-compatible DSL migration for existing rules**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-09T00:00Z
- **Completed:** 2026-04-09
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Replaced `EndsWithLiteralCond`, `StartsWithLiteralCond`, `EndsWithClassCond`, `StartsWithClassCond` with a unified `PatternCond(pattern)` sealed subclass
- Implemented phonological pattern parser and matcher in engine: `[class]`, `C`/`V` shorthands, literal sequences, `(optional)` groups, `_` start/end anchors
- Changed `MorphBranch.condition: MorphCondition?` to `MorphBranch.conditions: List<MorphCondition>` — empty = default, non-empty = AND logic
- Added backward-compatible DSL migration: old `[C_]`/`[_C]`/`"lit"_`/`_"lit"` forms parsed to equivalent `PatternCond` without DB schema changes
- Replaced `CondType` dropdown + single value field in rule editor with `IpaTextField` list — one field per condition with Add/Remove buttons and syntax help text
- 10 new tests added (17-26): `V_`, `_CV`, `[nasal]V_`, `Vk(l)_`, AND logic, DSL round-trips, migration — all 24 tests pass

## Task Commits

1. **Task 1: Replace condition types with PatternCond in DSL + engine + tests** - `29b33a4` (feat)
2. **Task 2: Update rule editor condition UI for pattern-based input** - `b14ce4e` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `lib/features/morphology/domain/morphology_dsl.dart` — PatternCond class, new `{pattern}` parser, migration parsers, conditions list serializer
- `lib/features/morphology/domain/morphology_engine.dart` — Pattern segment parser (_ClassSegment, _LiteralSegment, _OptionalGroup), patternConditionMatches(), allConditionsMatch(), removed old switch arms
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — Removed CondType enum; added condPatternCtrls list; _buildConditionSection with IpaTextField per condition
- `test/morphology_engine_test.dart` — Updated tests 9/10/13 to PatternCond; added 10 new pattern tests; expanded testInventory with nasal/stop natural classes

## Decisions Made

- `PatternCond` uses a raw string with `_` anchors rather than structured AST — simpler to author, sufficient expressiveness for conlanging, round-trips cleanly through DSL serializer as `{pattern}`
- `MorphBranch.conditions` list (not nested condition AST) — AND logic across the list, users add more conditions via UI or write `{p1}{p2}` in DSL; no nesting required
- Old condition DSL syntax migrated silently in parser — avoids requiring a DB migration script for existing rules; old forms become equivalent PatternCond on parse, then serialize as new `{pattern}` form
- Auto-strip behavior (engine was stripping matched EndsWithLiteralCond suffix) **removed** — `PatternCond` is purely boolean match; stripping is done explicitly by `RemoveSuffixOp` in the operation chain

## Deviations from Plan

None - plan executed exactly as written. The auto-strip removal was specified in the plan (task 1 point 6).

## Issues Encountered

- Two minor analyzer infos fixed inline: `inner_parsed` variable name (renamed to `innerParsed`) and HTML angle brackets in doc comment (reworded). Both caught by `flutter analyze` before commit.

## Next Phase Readiness

- Plan 09 (UAT gap 5: condition pattern redesign) complete
- Plan 10 is the final gap closure plan in phase 02; condition system is stable
- Phase 03 lexicon can use morphology engine with full pattern condition support

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
