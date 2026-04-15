---
phase: 11-lexicon-etymology-chain
fixed_at: 2026-04-14T00:00:00Z
fix_scope: critical_warning
findings_in_scope: 3
fixed: 3
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 11: Code Review Fix Report

**Fixed at:** 2026-04-14
**Source review:** `.planning/phases/11-lexicon-etymology-chain/11-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed

### WR-01: Search field not cleared after selecting a parent

**Files modified:** `lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart`
**Commit:** 17685d5 — `fix(11): WR-01 clear autocomplete field after parent selection`

**Applied fix:** Removed `_searchController` (a disconnected parallel controller) and replaced it with a nullable `_autocompleteController` field. In `fieldViewBuilder`, the Autocomplete-owned `controller` argument is now captured into `_autocompleteController`. In `onSelected`, `_autocompleteController?.clear()` is called instead of the old `_searchController.clear()`. The owned controller is not disposed by the state (Autocomplete manages its own lifecycle).

---

### WR-02: Children connector hardcodes `nodeCount: 1`

**Files modified:** `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart`
**Commit:** 42ddea4 — `fix(11): WR-02 use actual child count for children connector nodeCount`

**Applied fix:** Replaced the hardcoded `nodeCount: 1` in the children `_connector` call with `nodeCount: ruleDerivedChildren.length + manualChildren.length`. This allows `_ConnectorPainter` to draw a proper fan shape when a word has two or more children.

---

### WR-03: Unawaited Futures from DAO mutations in `_buildAddParentSection`

**Files modified:** `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart`
**Commit:** c0aa6c9 — `fix(11): WR-03 await DAO mutations in etymology parent onChanged`

**Applied fix:** Extracted the DAO mutations into a new private async method `_updateManualParents(Set<int> oldIds, Set<int> newIds)` which awaits each `insertParent`/`deleteParent` call inside a `try/catch` that logs failures via `debugPrint`. The synchronous `onChanged` callback now delegates to this method via `(newIds) => _updateManualParents(manualParentIds, newIds)` — the fire-and-forget is now intentional and explicit, and errors are no longer silently swallowed. The argument order was also corrected so the diff direction matches the original logic (inserts for `newIds.difference(oldIds)`, deletes for `oldIds.difference(newIds)`).

---

## Skipped

None — all in-scope findings were fixed.

---

_Fixed: 2026-04-14_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
