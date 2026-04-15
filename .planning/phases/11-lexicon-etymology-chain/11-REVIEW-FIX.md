---
phase: 11-lexicon-etymology-chain
fixed_at: 2026-04-15T00:00:00Z
review_path: .planning/phases/11-lexicon-etymology-chain/11-REVIEW.md
fix_scope: critical_warning
findings_in_scope: 3
fixed: 3
skipped: 0
iteration: 1
status: all_fixed
---

# Phase 11: Code Review Fix Report

**Fixed at:** 2026-04-15
**Source review:** `.planning/phases/11-lexicon-etymology-chain/11-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: `updateParent` silently overwrites existing data when optional parameters are omitted

**Files modified:** `lib/features/grammar/data/lexeme_parents_dao.dart`
**Commit:** a02f04c
**Applied fix:** Added `clearRelationship` and `clearNotes` boolean parameters (defaulting to `false`). The companion now uses `Value(x)` only when the caller explicitly passes a non-null value, `const Value(null)` when a clear flag is set, and `const Value.absent()` otherwise — so omitting an optional parameter no longer issues a `SET column = NULL` in the SQL update. Updated the doc comment to document the new semantics.

---

### WR-02: Truncation check fires before cycle detection — deep cycles misreported as truncations

**Files modified:** `lib/features/lexicon/data/lexeme_providers.dart`
**Commit:** 0ec3b80
**Applied fix:** Swapped the guard order in `buildAncestryNode` so the `visited.contains(lexemeId)` cycle check runs before the `depth >= 10` truncation check. A cyclic node encountered at depth 10 or deeper is now correctly reported as `isCycle: true` rather than `isTruncated: true`. Updated the comments on both guards to explain the priority.

---

### WR-03: `_save` in `WordCreationForm` has no `catch` — DB errors are unhandled

**Files modified:** `lib/features/lexicon/presentation/dictionary/word_creation_form.dart`
**Commit:** 5a9cc05
**Applied fix:** Added a `catch (e)` block between the `try` body and the existing `finally` block. On any exception the catch checks `mounted` and shows a `SnackBar` with `'Failed to save word: $e'`. The existing `finally` block (`setState(() => _saving = false)`) is preserved unchanged.

---

## Skipped

None — all in-scope findings were fixed.

---

_Fixed: 2026-04-15_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
