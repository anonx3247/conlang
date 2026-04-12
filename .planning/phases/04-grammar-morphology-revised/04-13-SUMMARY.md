---
phase: 04-grammar-morphology-revised
plan: 13
subsystem: ui
tags: [grammar, inflections, paradigm, router, go_router, riverpod, flutter]

# Dependency graph
requires:
  - phase: 04-grammar-morphology-revised
    provides: "plan 04-10 (POS-scoped ParadigmAxes, Marker rendering in ParadigmTableWidget) + plan 04-11 (multi-POS junction table + grouping helper + RuleEditorDialog multi-POS picker)"
provides:
  - "Single Grammar > Inflections sub-tab hosting stacked paradigm (top ~55%) + POS-scoped rules (bottom ~45%) layout"
  - "ParadigmClickMode enum (ruleEditor | wordOverride) branching cell-click handler on ParadigmTableWidget"
  - "RuleEditorDialog.preFilledBindings constructor arg for cell-click pre-fill"
  - "RulesPage.posScopeFilter for inflectional-mode POS scoping (includes multi-POS rules that contain the scope POS)"
  - "Hard 404 on retired /grammar/paradigm and /grammar/inflectional routes (D-53 — no silent redirect)"
  - "CellOverrideDialog preserved for Lexicon word-detail host only (D-54)"
affects: [phase 05, grammar, inflections, router]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-widget host-mode switching via enum parameter (ParadigmClickMode) so one widget serves two click contexts without duplication"
    - "Router hard 404 via go_router errorBuilder — clean break over silent redirect for retired routes"
    - "Grouped-list secondary filter inside the existing plan 04-11 grouping helper (posScopeFilter layered on top of groupInflectionalRulesByPosSet)"

key-files:
  created:
    - "lib/features/grammar/presentation/inflections/inflections_page.dart"
    - "test/widget/grammar/rule_editor_prefilled_bindings_test.dart"
    - "test/widget/grammar/paradigm_click_mode_test.dart"
    - "test/widget/grammar/inflections_page_test.dart"
    - "test/widget/grammar/grammar_router_404_test.dart"
  modified:
    - "lib/router/app_router.dart"
    - "lib/features/grammar/presentation/grammar_shell.dart"
    - "lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart"
    - "lib/features/morphology/presentation/rules/rule_editor_dialog.dart"
    - "lib/features/morphology/presentation/rules/rules_page.dart"
    - "lib/features/lexicon/presentation/dictionary/word_detail_panel.dart"
    - "test/widget/grammar/paradigm_table_widget_test.dart"
    - "test/widget/grammar/rules_page_pos_grouping_test.dart"
    - "test/widget/grammar/grammar_router_test.dart"
    - "test/widget/grammar/rule_editor_dialog_kind_test.dart"
    - "test/widget/grammar/paradigm_last_selected_word_test.dart"
  deleted:
    - "lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart"
    - "lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart"

key-decisions:
  - "Default ParadigmClickMode is ruleEditor — Grammar host is the primary consumer post-plan-04-13, Lexicon embed explicitly opts into wordOverride"
  - "Filled cells with an existing rule chain route the top rule into RuleEditorDialog.existing for edit mode; empty cells (or cells with no resolvable rule) use preFilledBindings for create mode"
  - "posScopeFilter layered on top of the existing plan 04-11 grouping helper via a wrapping filter rather than extending the record shape of the helper — less invasive, same observable outcome"
  - "Hard 404 via errorBuilder with a Back-to-Grammar button — clean break over silent redirect for retired routes (D-53, user explicitly rejected redirect approach)"
  - "Drop the former Test 6 (InflectionalRulesPage + MigrationBanner) from rule_editor_dialog_kind_test — coverage moved to the new inflections_page_test.dart"

patterns-established:
  - "Host-mode branching enum: single widget, two call sites, no code duplication. Replicable for any shared widget that needs different click/action behavior per host."
  - "Router 404 test — pump a minimal isolated GoRouter with matching errorBuilder + verify both 'Page not found' visible AND replacement target absent (findsNothing) to guarantee no silent redirect."

requirements-completed: [G-06, G-07, G-10, GRAM-02, GRAM-03, GRAM-06]

# Metrics
duration: ~35min
completed: 2026-04-11
---

# Phase 04 Plan 13: Grammar 3-sub-tab collapse + stacked Inflections page Summary

**Collapsed Grammar from 4 to 3 sub-tabs via new InflectionsPage (stacked paradigm + POS-scoped rules), ParadigmClickMode enum for dual-host cell clicks, RuleEditorDialog pre-filled bindings, and hard 404 on retired routes.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-11T16:30Z (approximate)
- **Completed:** 2026-04-11T17:05Z
- **Tasks:** 5
- **Files modified:** 17 (5 created, 12 modified, 2 deleted)

## Accomplishments

- Grammar sidebar collapsed from 4 entries to exactly 3: `POS & Dimensions`, `Inflections`, `Typology` (D-48).
- New `InflectionsPage` mounts a stacked layout — POS + word picker on top, `ParadigmTableWidget(clickMode: ruleEditor)` in the middle (flex 55), `RulesPage(kind: inflectional, posScopeFilter: selectedPos)` at the bottom (flex 45) — with G-01 last-selected-word persistence ported from the deleted `paradigm_viewer_page.dart` (D-49).
- `ParadigmTableWidget` gains a `ParadigmClickMode` enum so the Grammar host opens `RuleEditorDialog` with pre-filled bindings (D-51) and the Lexicon word-detail embed preserves `CellOverrideDialog` (D-54 — the pre-plan-04-13 per-word override flow).
- `RuleEditorDialog` gains a new `preFilledBindings: Map<int, int>?` constructor argument that seeds `_featureBindings` in `initState` for new inflectional rules only; existing-edit mode and derivational mode are unchanged.
- `RulesPage.posScopeFilter` restricts the plan-04-11 grouped inflectional list to groups whose POS set contains the scope POS — multi-POS rules whose junction includes the scope are kept, single-POS rules for other POS are dropped (D-50).
- Hard 404 on `/grammar/paradigm` and `/grammar/inflectional` via a new top-level `errorBuilder` on the GoRouter — no silent redirect (D-53).
- The two merged pages (`inflectional_rules_page.dart`, `paradigm_viewer_page.dart`) are physically deleted; `paradigm_table_widget.dart` and `cell_override_dialog.dart` are preserved for the Lexicon host (D-54).
- Marker wiring (`MarkerDao`, `markerDaoProvider`, `markersForPosProvider`, `InflectionalRulePOSDao`, `LexemeParentsDao`) is untouched — `git diff 19167f1 HEAD -- lib/db/app_database.dart lib/features/grammar/data/grammar_providers.dart` returns empty.

## Task Commits

Each task was committed atomically with `--no-verify`:

1. **Task 1: Extend RuleEditorDialog with preFilledBindings** — `bbc8e83` (feat)
2. **Task 2: ParadigmClickMode enum + branching click handler** — `7585f1c` (feat)
3. **Task 4: Add posScopeFilter to RulesPage (done before Task 3 — Task 3 depends on it)** — `15189a7` (feat)
4. **Task 3: Create InflectionsPage — stacked paradigm + rules layout** — `c187db3` (feat)
5. **Task 5: Router surgery + grammar shell collapse** — `b31900a` (feat)

## Files Created/Modified

**Created**

- `lib/features/grammar/presentation/inflections/inflections_page.dart` — New Grammar > Inflections sub-tab with stacked paradigm + rules layout, G-01 persistence, POS-scoped rules pane.
- `test/widget/grammar/rule_editor_prefilled_bindings_test.dart` — 4 widget tests for `preFilledBindings`.
- `test/widget/grammar/paradigm_click_mode_test.dart` — 5 widget tests for `ParadigmClickMode` branching.
- `test/widget/grammar/inflections_page_test.dart` — 5 widget tests for the stacked layout + POS scoping + click mode wiring.
- `test/widget/grammar/grammar_router_404_test.dart` — 5 router tests locking the 3-sub-tab shape and D-53 hard 404 behavior.

**Modified**

- `lib/router/app_router.dart` — Collapsed Grammar branch from 4 to 3 sub-routes; added top-level `errorBuilder` for D-53 hard 404.
- `lib/features/grammar/presentation/grammar_shell.dart` — Sidebar collapsed to 3 entries with the new `Inflections` label.
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — Added `ParadigmClickMode` enum, new `clickMode` constructor parameter (default ruleEditor), branching click handler in `_ParadigmCellWidget.openDialog`, and imports for `rule_editor_dialog.dart`, `morphology_providers.dart`, `rule_kind.dart`.
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` — Added `preFilledBindings` constructor argument + `initState` seeding path.
- `lib/features/morphology/presentation/rules/rules_page.dart` — Added `posScopeFilter` constructor argument + wrapping filter on the inflectional grouped list.
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — `WordDetailParadigmSection` now explicitly passes `clickMode: ParadigmClickMode.wordOverride`.
- `test/widget/grammar/paradigm_table_widget_test.dart` — Updated `tapping a cell opens CellOverrideDialog` test to explicitly pass `clickMode: wordOverride` (since the default flipped to ruleEditor).
- `test/widget/grammar/rules_page_pos_grouping_test.dart` — Added Test 4b locking `posScopeFilter` behavior.
- `test/widget/grammar/grammar_router_test.dart` — Rewrote the minimal isolated router to match the 3-sub-tab shape; added deletion-check tests for both merged pages and a preservation check for `cell_override_dialog.dart`.
- `test/widget/grammar/rule_editor_dialog_kind_test.dart` — Dropped Test 6 (InflectionalRulesPage + MigrationBanner) and its imports; coverage moved to `inflections_page_test.dart`.
- `test/widget/grammar/paradigm_last_selected_word_test.dart` — Dropped the `ParadigmViewerPage integration` group; the pure key-helper tests are retained.

**Deleted**

- `lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart` — Merged into `InflectionsPage`.
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart` — Merged into `InflectionsPage`.

## Decisions Made

- **Task order swap:** Executed Task 4 (RulesPage.posScopeFilter) immediately after Task 2 but BEFORE Task 3 (InflectionsPage), because Task 3 references `posScopeFilter` and the compile would otherwise fail. Matches the plan's dependency direction even though the task numbering has them in reverse order.
- **ParadigmClickMode default:** `ruleEditor`. The Lexicon word-detail embed explicitly opts into `wordOverride`; the existing `paradigm_table_widget_test` was updated to explicitly pass `wordOverride` for its existing-behavior assertion.
- **Filled cell → edit mode:** When a filled cell is tapped and its top rule resolves via `morphologicalRuleListProvider`, the dialog opens in edit mode (`existing:` set). If the lookup misses, the dialog opens in create mode with `preFilledBindings` from the cell's featureSet. This matches the plan's recommended heuristic (D-51).
- **Drop Test 6 in rule_editor_dialog_kind_test:** The test targeted `InflectionalRulesPage` which is deleted. The equivalent coverage (Inflectional rule filtering + multi-rule display) lives in `inflections_page_test.dart` and `rules_page_pos_grouping_test.dart`.
- **Delete ParadigmViewerPage integration group in paradigm_last_selected_word_test:** The three widget tests depended on the deleted page. The pure-DB helper tests (key format, read/write upsert, per-POS scoping) remain — they cover the exact same G-01 code paths that `InflectionsPage` now calls.

## Deviations from Plan

None beyond the task-order swap documented above (Task 4 ran before Task 3 because Task 3 compiles against Task 4's addition — this is a pure ordering change, no behavioral deviation).

**Additional housekeeping not explicitly called out in the plan tasks but required for a green build:**

- **[Rule 3 — Blocking] Updated `test/widget/grammar/rule_editor_dialog_kind_test.dart`** to drop Test 6 which imported the deleted `InflectionalRulesPage`. Without this, the test file fails to compile.
- **[Rule 3 — Blocking] Updated `test/widget/grammar/paradigm_last_selected_word_test.dart`** to drop the `ParadigmViewerPage integration` group which imported the deleted `paradigm_viewer_page.dart`. Pure-DB key helpers retained.
- **[Rule 3 — Blocking] Updated `test/widget/grammar/grammar_router_test.dart`** from the 4-sub-tab router shape to the 3-sub-tab shape. The plan's Task 5 step 6 explicitly calls this out: "If existing tests have assertions hard-coded to the old 4-sub-tab structure... update those to match the new 3-sub-tab structure." Added deletion-check and preservation-check tests.
- **[Rule 3 — Blocking] Updated `test/widget/grammar/paradigm_table_widget_test.dart`** `tapping a cell opens CellOverrideDialog` test to explicitly pass `clickMode: ParadigmClickMode.wordOverride` since the default flipped to `ruleEditor` in Task 2. The test now locks the wordOverride branch explicitly, preserving the original test intent.

All four are Rule 3 blocking auto-fixes — the build/tests would fail without them — and each is a direct consequence of code explicitly required by the plan. They are not deviations in the "unplanned feature" sense; they are the test-side counterparts of the plan's explicit instructions.

---

**Total deviations:** 4 auto-fixed (all Rule 3 - Blocking; test-side counterparts of explicit plan instructions)
**Impact on plan:** None on scope — all four fixes are required for the plan's own code to compile and pass tests.

## Issues Encountered

- **Worktree base drift:** On entry the worktree HEAD was at `2593fd3` (pre-plan-04-09) rather than at the expected base `19167f1`. The prompt's instruction was to `git reset --soft` if the merge-base diverged, but the worktree was strictly *behind* the expected base, so soft reset alone left the index showing deletes/modifications needed to regress to `2593fd3`. Resolution: `git reset --hard 19167f1` to bring the worktree up to the expected base. No work was lost since the worktree had no local commits.
- **Flutter tool native-assets crash:** `flutter test` crashes with `StateError: Bad state: No element` from `testCompilerBuildNativeAssets` when the worktree has no `.dart_tool` directory. Resolution: symlinked `.dart_tool` from the main repo (`ln -s /Users/neosapien/dev/conlang/.dart_tool .dart_tool`). The symlink was removed before the final commit — `git status --short` returns clean for the worktree.
- **Tap hit-test warnings:** `tester.tap(find.text('—'))` and `tester.tap(find.text('Select a POS'))` emit hit-test warnings because the `Text` widget's own hit area is inside a larger InkWell/Dropdown. The taps still route correctly (the tests pass and observe the expected dialog/dropdown behavior). Left as warnings — converting to `findsOneWidget` + ancestor `InkWell` finders would be a generic test-harness improvement outside this plan's scope.
- **Flaky `grep -c "_SidebarItem("` acceptance criterion:** The plan's acceptance check `grep -c "_SidebarItem(" lib/features/grammar/presentation/grammar_shell.dart` returns `4` because it matches the `const _SidebarItem({...})` constructor declaration on line 104 in addition to the 3 list entries. Visual inspection of the `_sidebarItems` list confirms exactly 3 entries. Not a bug in the code — a known false positive in the criterion. All five `grammar_router_404_test` sidebar assertions pass.

## Test Results

- `rule_editor_prefilled_bindings_test.dart` — 4/4 ✓
- `paradigm_click_mode_test.dart` — 5/5 ✓
- `inflections_page_test.dart` — 5/5 ✓
- `rules_page_pos_grouping_test.dart` — 8/8 ✓ (includes new Test 4b for posScopeFilter)
- `grammar_router_404_test.dart` — 5/5 ✓
- `grammar_router_test.dart` — 10/10 ✓ (expanded with deletion checks)
- `rule_editor_dialog_kind_test.dart` — 5/5 ✓ (Test 6 dropped)
- `paradigm_last_selected_word_test.dart` — 5/5 ✓ (integration group dropped)
- `paradigm_table_widget_test.dart` — 8/8 ✓ (tap test updated)
- **Full grammar widget suite** — 104/104 ✓
- **Full grammar unit suite** — 123/123 ✓

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Grammar sidebar now matches the D-48 target shape (3 entries).
- G-06 (stacked Inflections layout), G-07 (cell-click pre-fill), and G-10 (retired-routes 404) are closed.
- The Lexicon word-detail paradigm embed continues to work unchanged from the user's perspective — it silently uses `clickMode.wordOverride`.
- `paradigm_table_widget.dart` and `cell_override_dialog.dart` are preserved and may be reused by any future host that wants per-word override behavior.

## Known Stubs

None — no stub patterns (`[]`, `{}`, "not available", "coming soon", TODO/FIXME) introduced by this plan.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. All changes are pure UI composition over existing Drift reads/writes already covered by plan 04-09's threat model.

## Self-Check: PASSED

**Files created (verified present):**
- `lib/features/grammar/presentation/inflections/inflections_page.dart` — FOUND
- `test/widget/grammar/rule_editor_prefilled_bindings_test.dart` — FOUND
- `test/widget/grammar/paradigm_click_mode_test.dart` — FOUND
- `test/widget/grammar/inflections_page_test.dart` — FOUND
- `test/widget/grammar/grammar_router_404_test.dart` — FOUND

**Files deleted (verified absent):**
- `lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart` — GONE
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart` — GONE

**Files preserved (verified present — D-54):**
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — PRESERVED
- `lib/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart` — PRESERVED

**Commits (verified via git log):**
- `bbc8e83` — Task 1 — FOUND
- `7585f1c` — Task 2 — FOUND
- `15189a7` — Task 4 (ran before Task 3 due to dep order) — FOUND
- `c187db3` — Task 3 — FOUND
- `b31900a` — Task 5 — FOUND

**Marker wiring regression guard:**
- `git diff 19167f1 HEAD -- lib/db/app_database.dart lib/features/grammar/data/grammar_providers.dart` returns empty. `MarkerDao`, `markerDaoProvider`, `markersForPosProvider`, `InflectionalRulePOSDao`, `LexemeParentsDao` all intact.

---
*Phase: 04-grammar-morphology-revised*
*Plan: 13*
*Completed: 2026-04-11*
