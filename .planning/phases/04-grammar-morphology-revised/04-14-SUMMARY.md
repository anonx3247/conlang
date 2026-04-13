---
phase: 04-grammar-morphology-revised
plan: 14
subsystem: lexicon-derivation-ui
tags: [D-57, D-58, D-59, D-60, D-62, D-63, D-64, G-14, G-15, G-16, G-17, G-18, G-19, GRAM-07]
requirements: [G-14, G-15, G-16, G-17, G-18, G-19]
dependency-graph:
  requires: [04-12]
  provides:
    - D-57 inline promote/demote via per-derivation meaning field
    - D-58 implicit-detach warning on rom/ipa edit
    - D-59 auto_apply checkbox + reconcile trigger in the rule editor
    - D-60 Suggestions chips in word detail
    - D-62 Parents / Etymology section + new-word parents picker
    - D-63 rootOnlyViaDerivations checkbox + muted sidebar render
    - D-64 POS abbreviation badge per derived form row
  affects: [lexicon/dictionary, morphology/rules]
tech-stack:
  added: []
  patterns:
    - Extracted WordDetailSuggestionsSection + WordDetailParentsSection as
      public widgets so widget tests can mount them without standing up
      the full WordDetailPanel provider graph (mirrors the plan 04-07
      WordDetailParadigmSection pattern).
    - _DerivedRow stateful row encapsulates the promote/demote/detach
      state machine — meaning edits go through LexemeDao; form edits
      surface the D-58 detach warning before calling detachFromRule.
key-files:
  created:
    - test/widget/grammar/auto_apply_rule_editor_test.dart
    - test/widget/grammar/word_detail_pos_badge_test.dart
    - test/widget/grammar/derived_form_meaning_edit_test.dart
    - test/widget/grammar/implicit_detach_warning_test.dart
    - test/widget/grammar/word_detail_suggestions_test.dart
    - test/widget/grammar/word_detail_parents_test.dart
    - test/widget/grammar/root_only_via_derivations_test.dart
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
decisions:
  - D-57/G-14 inline promote/demote lives in _DerivedRow inside
    derivation_tree_widget.dart — each row owns its own TextEditingController
    and performs the promote/demote flow via LexemeDao on onSubmitted.
  - D-58 meaning-only edits bypass detachFromRule by using a raw
    (update)..where((t) => t.id.equals(...)).write(LexemesCompanion(meaning:...))
    path inside _handleMeaningSubmit. This preserves the rule link, matching
    the invariant locked by implicit_detach_warning_test Test 4.
  - D-59 auto_apply reconcile triggers from the rule editor save path
    after the row is persisted, so users see matching words immediately
    promoted without needing an app restart.
  - D-60 Suggestions filter excludes auto_apply=true rules (they're
    already promoted) and applied (parent, rule) pairs (the chip
    disappears after click). The filter is derived client-side from
    allLexemeListProvider + morphologicalRuleListProvider.
  - D-62 Parents section is hidden entirely when the child has zero
    parent rows (keeps the word detail pane clean for root words).
  - D-63 muted rendering wraps the entire sidebar row in Opacity(0.45)
    — purely visual; search/export/filter pipelines are untouched.
  - D-64 POS badge renders `[{abbreviation}]` from the rule's outputPos
    row. For rule-less manual-parent derivations (LexemeParents), badges
    fall back to the child's own POS (future work — covered by parent
    section rendering not derivation tree).
metrics:
  duration: 18m
  completed: 2026-04-11
  tasks: 4
  tests_added: 30
---

# Phase 4 Plan 14: Derivation Overhaul UI Summary

Deliver the UI for Phase 4's derivation overhaul: per-derivation meaning
field with promote/demote (D-57/G-14), implicit-detach warning on form
edit (D-58/G-14), auto_apply checkbox in the derivational rule editor
(D-59/G-18), Suggestions chips + Parents/Etymology section in word
detail (D-60/G-19 + D-62/G-17), rootOnlyViaDerivations checkbox and
muted sidebar render (D-63/G-16), and POS abbreviation badges on every
derived form row (D-64/G-15). 30 widget tests lock every decision.

## Tasks Executed

### Task 1 — D-59 auto_apply checkbox (rule editor)

**Commit:** `8665bf2`

- Added `_autoApply` state to RuleEditorDialog; hydrated from
  `row.autoApply` in `_loadFromExisting` for derivational rules.
- Added a `CheckboxListTile` + subordinate "template preview" Text in
  the derivational mode top builder. Inflectional mode does not render
  the checkbox.
- Save path writes `autoApply: Value(widget.kind == derivational ? _autoApply : false)`
  on both insert and update paths.
- After save, when `_autoApply` is true the dialog calls
  `ref.read(derivationPromotionServiceProvider).reconcile()` so matching
  words are promoted immediately instead of waiting for the next startup.
- Imported `derivation_promotion_service.dart` to reach the provider.

**Tests:** `auto_apply_rule_editor_test.dart` — 5 tests:
1. Checkbox visible in derivational mode
2. Checkbox hidden in inflectional mode
3. Save writes `autoApply=true` to the row
4. Template preview surfaces `(Actor)` when checked + rule name typed
5. Editing an existing `autoApply=true` rule initializes the checkbox as
   checked (drives the Checkbox widget state via `widget.value`)

### Task 2 — derivation_tree_widget overhaul (D-57/D-58/D-64)

**Commit:** `fc6c9df`

Full rewrite of derivation_tree_widget.dart:
- Replaced the old `_TreeNode`-only list with a `_DerivedRow`
  ConsumerStatefulWidget that owns the per-row interactive surface.
- Each row shows the POS abbreviation badge (D-64) from
  `rule.outputPos.abbreviation`, resolved inline via
  `morphologicalRuleListProvider` + `posListProvider`.
- A `SizedBox(width: 140)` inline meaning TextField with the hint
  `"Add meaning to save…"` drives the promote/demote flow. Submit with
  non-empty text on a computed row calls `LexemeDao.promoteDerivation`;
  clearing a promoted row's meaning opens a confirmation AlertDialog
  and, on confirm, calls `LexemeDao.demoteDerivation`.
- Meaning-only edits on an already-promoted row write via a bare
  `(update)..where.write(LexemesCompanion(meaning:...))` — this
  intentionally DOES NOT touch `derivedViaRuleId`, locking the D-58
  boundary: meaning stays rule-linked, forms don't.
- A `Tooltip(message: 'linked to rule "<name>"')` icon renders on
  promoted + rule-linked rows (D-58 affordance).
- A pencil IconButton (`tooltip: 'Edit form'`) opens the implicit
  detach flow: AlertDialog with "Unlink from rule?" copy + "Unlink and
  edit" / "Cancel" actions. Confirming opens a second dialog with IPA
  and Romanization TextFields; saving calls
  `LexemeDao.detachFromRule(lexemeId, newIpa, newRom)`.

**Tests:**
- `word_detail_pos_badge_test.dart` — 3 tests: `[N]` badge for Noun,
  `[V]` badge for Verb, both rendered simultaneously with two rules.
- `derived_form_meaning_edit_test.dart` — 4 tests: placeholder hint,
  promote on submit, meaning-edit on promoted row leaves
  derivedViaRuleId intact, clearing promoted meaning opens the
  confirm dialog.
- `implicit_detach_warning_test.dart` — 5 tests: link Tooltip, pencil
  opens Unlink dialog, confirm + new IPA calls detachFromRule, meaning
  edit never triggers the warning, rule DSL edit reactively updates
  the rendered form (100-lexeme constraint surface).

### Task 3 — Word detail Suggestions + Parents sections (D-60/D-62)

**Commit:** `bb72a34`

Added two public `ConsumerWidget`s to word_detail_panel.dart and
mounted them around the derivation tree in the main panel:

- **`WordDetailSuggestionsSection`** (D-60/G-19) — filters
  derivational rules by `isActive && !autoApply && inputPosId == pos.id &&
  !alreadyApplied` then renders each as an `ActionChip`. Clicking a
  chip calls `LexemeDao.promoteDerivation` with an empty gloss; the
  user fills in the meaning via the Task 2 derivation tree row flow.
  Hidden entirely when zero suggestions remain (clean layout).
- **`WordDetailParentsSection`** (D-62/G-17) — consumes
  `parentsForLexemeProvider(lexeme.id)` and renders one row per
  parent lexeme with `<romanization> (<meaning>) — <relationship>`
  layout. Relationship clause is omitted when null. Section header
  hidden when the child has zero parents.

Both widgets are extracted as public so widget tests mount them
directly — same pattern as `WordDetailParadigmSection` from plan 04-07.

**Tests:**
- `word_detail_suggestions_test.dart` — 4 tests: header visible,
  autoApply+wrong-POS filter, chip click promotes + disappears,
  zero-suggestions hides the section.
- `word_detail_parents_test.dart` — 3 tests: parent rows rendered
  with romanization + gloss, relationship label surfaced, zero parents
  hides the header.

### Task 4 — New-word form + muted Dictionary sidebar (D-62/D-63)

**Commit:** `7e86f0c`

- **word_creation_form.dart**: added `_rootOnlyViaDerivations` state
  field + `_selectedParents` set. UI: CheckboxListTile
  ("This root only exists through derivations") + a `FilterChip` Wrap
  populated from `allLexemeListProvider`. Save path writes the flag
  to `LexemesCompanion.rootOnlyViaDerivations` and iterates
  `_selectedParents` through `LexemeParentsDao.insertParent` after the
  child row exists.
- **word_list_panel.dart**: wrapped each Material row in
  `Opacity(opacity: muted ? 0.45 : 1.0)` where
  `muted = lexeme.rootOnlyViaDerivations`. No filter logic changes —
  muted rows remain fully findable via search, exportable, and
  clickable.

**Tests:** `root_only_via_derivations_test.dart` — 6 tests: checkbox
visible, save writes the flag, parents picker renders + writes rows,
sidebar Opacity wraps muted rows, muted rows stay in the DB scan.

## Regression Verification

Full Phase 4 widget suite passes: **134 tests green** across
`test/widget/grammar/`. Two pre-existing orphan-file test failures in
`grammar_router_test.dart` were resolved by removing two untracked
orphan files (`inflectional_rules_page.dart`,
`paradigm_viewer_page.dart`) that plan 04-13 already physically deleted
in its router-surgery commit — they were lingering in this worktree
and tripping the physical-delete sanity assertions.

## Wiring Preservation

Verified all critical 04-10/04-11/04-13 wiring is intact in the final
diff (no regression of 04-11's marker re-registration):

- `MarkerDao, LexemeParentsDao, InflectionalRulePOSDao` all registered
  in `app_database.dart` daos list (lines 394-396).
- `markerDaoProvider`, `markersForPosProvider`,
  `inflectionalRulePOSDaoProvider`, `posSetForRuleProvider`,
  `allRulePosSetsProvider`, `lexemeParentsDaoProvider`,
  `parentsForLexemeProvider` all present in `grammar_providers.dart`.
- `RuleEditorDialog.preFilledBindings` param + hydration path in
  `_loadFromExisting` preserved.
- `ParadigmClickMode` enum + branching click handler in
  `paradigm_table_widget.dart` preserved.

`rule_editor_dialog.dart` was additive-only (61 lines added, 0
deleted) — all Task 1 changes layer on top of 04-13's plan 13 surgery.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Removed pre-existing worktree orphan files**

- **Found during:** Task 4 regression run
- **Issue:** `lib/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart`
  and `lib/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart`
  existed in this worktree as untracked orphans. Plan 04-13's
  `b31900a` had physically deleted them, but the worktree filesystem
  still had them, causing `grammar_router_test.dart` to fail its
  `File(path).exists() == false` sanity assertions.
- **Fix:** `rm` both orphan files (neither was tracked in HEAD; pure
  cleanup).
- **Files removed:** those two orphan source files (not committed —
  they were never tracked here either).
- **Commit:** documented in `chore(04-14): log pre-existing worktree
  orphan files (plan 04-13)` `f9ad454`

**2. [Rule 3 — Blocking] ran `flutter pub get`**

- **Found during:** Task 1 first test run — Flutter tool crashed with
  "Bad state: No element" in `testCompilerBuildNativeAssets` because
  `.dart_tool/` didn't exist in this fresh worktree.
- **Fix:** ran `flutter pub get` once to populate `.dart_tool/`.
- **Files modified:** none (generated dependency tree only).

## Known Stubs

None. Every plan-14 deliverable has an end-to-end data path wired through
to a Drift table: `autoApply` → `MorphologicalRules.auto_apply`,
`rootOnlyViaDerivations` → `Lexemes.root_only_via_derivations`, parent
selection → `LexemeParents` junction, meaning promote → `Lexemes`
row with `derivedFromLexemeId` + `derivedViaRuleId` + `meaning`, form
edit detach → `Lexemes.derivedViaRuleId = null`.

## Metrics

- **Duration:** ~18 minutes
- **Tasks:** 4
- **Files created:** 7 (all tests)
- **Files modified:** 5
- **Lines added:** 2482
- **Lines deleted:** 48
- **Tests added:** 30 widget tests (5 + 3 + 4 + 5 + 4 + 3 + 6)
- **Decisions closed:** D-57, D-58, D-59, D-60, D-62, D-63, D-64
- **Requirements closed:** G-14, G-15, G-16, G-17, G-18, G-19

## Self-Check: PASSED

**Files verified:**
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` FOUND
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` FOUND
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` FOUND
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` FOUND
- `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` FOUND
- `test/widget/grammar/auto_apply_rule_editor_test.dart` FOUND
- `test/widget/grammar/word_detail_pos_badge_test.dart` FOUND
- `test/widget/grammar/derived_form_meaning_edit_test.dart` FOUND
- `test/widget/grammar/implicit_detach_warning_test.dart` FOUND
- `test/widget/grammar/word_detail_suggestions_test.dart` FOUND
- `test/widget/grammar/word_detail_parents_test.dart` FOUND
- `test/widget/grammar/root_only_via_derivations_test.dart` FOUND

**Commits verified:**
- `8665bf2` feat(04-14): add D-59 auto_apply checkbox to RuleEditorDialog FOUND
- `fc6c9df` feat(04-14): derivation tree POS badges + meaning field + detach warning FOUND
- `bb72a34` feat(04-14): word detail Suggestions chips + Parents section FOUND
- `7e86f0c` feat(04-14): new-word checkbox + parents picker + muted dictionary row FOUND
- `f9ad454` chore(04-14): log pre-existing worktree orphan files FOUND
