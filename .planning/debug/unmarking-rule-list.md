---
status: awaiting_human_verify
trigger: "In the paradigm viewer, when only an unmarking rule exists (no other rule types), the unmarking rule doesn't appear in the rules list."
created: 2026-04-13T00:00:00Z
updated: 2026-04-13T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — early return on `rules.isEmpty` short-circuits before marker rendering
test: Traced `_buildInflectionalGroupedList` execution path
expecting: confirmed
next_action: write regression test, archive

## Symptoms

expected: Unmarking rules should appear in the paradigm viewer's rules list even when they are the only rule configured
actual: When an unmarking rule is the sole rule, the list appears empty / the rule is not shown
errors: No errors — the rule just doesn't appear in the list
reproduction: Create only an unmarking rule (no other rule types), open the paradigm viewer, observe that the rules list is empty
started: Pre-existing bug, just discovered

## Eliminated

- hypothesis: Bug is in the paradigm viewer page or table widget
  evidence: Markers are rendered in RulesPage._buildInflectionalGroupedList, not the viewer
  timestamp: 2026-04-13

- hypothesis: Bug is in how markers are fetched/stored
  evidence: markersForPosProvider works correctly; data is present. The rendering path is the issue.
  timestamp: 2026-04-13

## Evidence

- timestamp: 2026-04-13
  checked: rules_page.dart _buildInflectionalGroupedList (line 516)
  found: `if (rules.isEmpty)` returns empty state BEFORE the markersForPosProvider watch loop
  implication: When only markers exist (no morphological rules), the early return fires before markers are ever read or rendered

- timestamp: 2026-04-13
  checked: marker rendering loop (lines 596-817)
  found: Markers are only rendered by iterating over `groups`, which is produced from `groupInflectionalRulesByPosSet(rules: ...)`. When rules is empty, groups is empty, so the marker loop never runs.
  implication: Two compounding issues: (1) early return, (2) no fallback for orphaned markers with no rule group

- timestamp: 2026-04-13
  checked: Riverpod ref.watch calls for markersForPosProvider and dimensionsForPosProvider
  found: Both are called after the `rules.isEmpty` early return, violating Riverpod's requirement that ref.watch be called unconditionally in the same order every build
  implication: Moving them before the early return is also necessary for correctness

## Resolution

root_cause: In `RulesPage._buildInflectionalGroupedList`, the `ref.watch(markersForPosProvider(...))` loops and the `if (rules.isEmpty)` early-return guard were in the wrong order. When only markers exist (no morphological rules), `rules.isEmpty` is true, causing an early return BEFORE markers are ever fetched or rendered. Even if the early return were removed, `groups` would still be empty (derived only from rules), so the marker-rendering loop inside `for (final group in groups)` would never execute.

fix: |
  Three changes to rules_page.dart:
  1. Moved `markersByPosId` and `levelAbbrMap` construction (the ref.watch loops) BEFORE the early return guard — satisfying Riverpod's unconditional watch requirement.
  2. Changed `if (rules.isEmpty)` → `if (rules.isEmpty && markersByPosId.isEmpty)` — the empty state only fires when both rules AND markers are absent.
  3. Added a fallback loop after the main `for (final group in groups)` loop — iterates markersByPosId.keys for any posId not yet rendered (i.e., POS groups that had no rules), emits a POS header and marker cards for each. Respects the posScopeFilter.

verification: All existing tests pass. Pre-existing failures (unmarked_cell_render_test, rule_editor_intrinsic_save_block_test Case 6) were present before this change.
files_changed:
  - lib/features/morphology/presentation/rules/rules_page.dart
