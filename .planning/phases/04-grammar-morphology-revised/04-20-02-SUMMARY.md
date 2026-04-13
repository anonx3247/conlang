---
phase: 04-grammar-morphology-revised
plan: 20-02
subsystem: lexicon-derivation
tags: [derivation, search, navigation, gap-closure]
dependency_graph:
  requires:
    - 04-12 (DerivationPromotionService.reconcile)
    - 04-14 (derivedFromLexemeId / derivedViaRuleId fields on Lexeme)
  provides:
    - auto-apply fires on new word creation and meaning edits
    - derived word click navigation in derivation tree
    - rule-derived parent pill in Parents section
    - romanized derived form search matching
  affects:
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
    - lib/features/lexicon/data/lexeme_providers.dart
tech_stack:
  added: []
  patterns:
    - reconcile() called after insertLexeme and updateLexeme for idempotent auto-apply
    - ValueChanged<int>? onNavigateToWord callback threaded through widget tree
    - GestureDetector with TextDecoration.underline + open_in_new icon for tappable derived rows
    - romanize(form) called alongside IPA comparison in filteredLexemeListProvider
key_files:
  created: []
  modified:
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
    - lib/features/lexicon/data/lexeme_providers.dart
decisions:
  - reconcile() placed after parent link writes in _save() so the new lexeme row is fully committed before auto-apply runs
  - Rule-derived parent pill rendered before manual parents in WordDetailParentsSection — shows derivation origin prominently
  - GestureDetector used over InkWell for tappable derived label — simpler for a Row child alongside existing Row children
  - romanize() hoisted to filteredLexemeListProvider top-level so it is available in computed derived match block without redundant ref.watch
metrics:
  duration_minutes: 25
  completed_date: "2026-04-12"
  tasks_completed: 3
  files_modified: 4
---

# Phase 04 Plan 20-02: Derivation Lifecycle Gaps Summary

Complete derivation lifecycle from creation through navigation and search — four UAT gaps closed in one plan.

## What Was Built

**Task 1 — Auto-apply reconcile on new word creation and meaning edits (UAT Issue 2 / G-18)**

Added `DerivationPromotionService.reconcile()` calls to two paths:
- `word_creation_form.dart` `_save()`: reconcile fires after `insertLexeme()` and parent link writes, so any new word whose POS matches an `autoApply=true` rule immediately gets derived forms.
- `word_detail_panel.dart` `_saveEdit()`: reconcile fires after `updateLexeme()`, triggering auto-apply when a previously-null meaning is set.

Both files now import `derivation_promotion_service.dart`.

**Task 2 — Derived word click navigation + parent pill (New Gaps 5 and 6)**

`DerivationTreeWidget` gains an optional `onNavigateToWord: ValueChanged<int>?` parameter, threaded down to `_DerivedRow`. When a derived form has been promoted (has a Lexeme row) and the callback is non-null, the display label is wrapped in a `GestureDetector` with underline decoration and a trailing `open_in_new` icon (size 12) to signal navigability.

`WordDetailPanel` passes `widget.onNavigateToWord` to `DerivationTreeWidget`.

`WordDetailParentsSection` updated with:
- Guard changed from `if (parents.isEmpty) return SizedBox.shrink()` to also check `lexeme.derivedFromLexemeId != null`
- New `_buildRuleDerivedParentRow()` method renders an `ActionChip` with "via RuleName" relationship text, inserted before manual parents
- Rule name resolved by watching `morphologicalRuleListProvider` (already imported)

**Task 3 — Search matches romanized derived forms (New Gap 7)**

In `filteredLexemeListProvider`, hoisted `romanize = ref.watch(romanizeProvider)` to the provider top-level. In the computed-on-the-fly derivation match block, after computing `form` via `engine.applyRule`, also compute `romForm = romanize(form)` and match against both `form.toLowerCase()` and `romForm.toLowerCase()`. Searching "cimoma" (a romanized derived form) now returns the root word.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `1e0d10e` | feat(04-20-02): trigger auto-apply reconcile on new word creation and meaning edits |
| 2 | `0f632b2` | feat(04-20-02): add click navigation on derived words + parent pill for rule-derived words |
| 3 | `59090ef` | feat(04-20-02): search matches romanized derived forms (New Gap 7) |

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed unnecessary null assertion on `promoted` in `_DerivedRow`**
- Found during: Task 2 analysis
- Issue: `promoted!.id` inside `if (promoted != null)` block — redundant `!` was a warning
- Fix: removed `!`, using `promoted.id` (Dart flow analysis already narrowed the type)
- Files modified: `derivation_tree_widget.dart`
- Commit: `0f632b2`

**2. [Rule 1 - Bug] Fixed unnecessary null assertion on `ruleDerivedParent` in `WordDetailParentsSection`**
- Found during: Task 2 analysis
- Issue: `ruleDerivedParent!` inside `if (hasRuleDerivedParent && ruleDerivedParent != null)` — redundant `!`
- Fix: removed `!`
- Files modified: `word_detail_panel.dart`
- Commit: `0f632b2`

## Known Stubs

None. All four gaps are fully wired.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| word_creation_form.dart | FOUND |
| word_detail_panel.dart | FOUND |
| derivation_tree_widget.dart | FOUND |
| lexeme_providers.dart | FOUND |
| commit 1e0d10e | FOUND |
| commit 0f632b2 | FOUND |
| commit 59090ef | FOUND |
