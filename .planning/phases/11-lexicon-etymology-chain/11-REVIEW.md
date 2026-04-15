---
phase: 11-lexicon-etymology-chain
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/features/grammar/data/lexeme_parents_dao.dart
  - lib/features/grammar/data/lexeme_parents_dao.g.dart
  - lib/features/lexicon/data/lexeme_providers.dart
  - lib/features/lexicon/domain/ancestry_node.dart
  - lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart
  - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
  - test/unit/lexicon/ancestry_chain_test.dart
  - test/unit/lexicon/promoted_derivation_chain_test.dart
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 11 delivers the etymology chain feature: the `AncestryNode` domain model,
recursive `buildAncestryNode` traversal, the `LexemeParentsDao` DAO, ancestry +
promoted-derivation providers, `SearchableParentSelector`, and integration into
`WordCreationForm`. The core domain logic (`buildAncestryNode`,
`promotedDerivedFormProvider`) is correct, well-commented, and thoroughly tested.
The DAG-vs-cycle distinction is properly handled via per-branch visited sets.

Three issues were found: a data-loss bug in `updateParent` where omitting optional
parameters silently erases existing database content; a priority inversion where
the truncation guard fires before cycle detection (deep cycles are misreported
as truncations); and missing user-facing error handling in `WordCreationForm._save`
where database failures propagate as unhandled exceptions. Three informational
items cover API inconsistency in `StreamProvider` null-case handling, a type
inconsistency between two parallel ID sets in the filter provider, and incomplete
depth assertion in the truncation unit test.

---

## Warnings

### WR-01: `updateParent` silently overwrites existing data when optional parameters are omitted

**File:** `lib/features/grammar/data/lexeme_parents_dao.dart:83-97`

**Issue:** In Drift, `Value(x)` in an `UPDATE` means "write `x` to this column"
while `Value.absent()` means "leave this column unchanged." `updateParent`
accepts `String? relationship` and `String? notes` with default values of `null`,
then unconditionally wraps them as `Value(relationship)` and `Value(notes)` in
the companion. Any caller that omits either parameter (i.e., passes the default
`null`) will issue an SQL `UPDATE … SET relationship = NULL, notes = NULL`, erasing
any previously stored content. Because the method is the only way to edit an
existing link's metadata, this is a silent data-loss path that activates on
what looks like a "partial update" call.

**Fix:** Use `Value.absent()` when the caller does not provide a value:
```dart
Future<void> updateParent({
  required int childLexemeId,
  required int parentLexemeId,
  String? relationship,
  String? notes,
  bool clearRelationship = false,
  bool clearNotes = false,
}) {
  return (update(lexemeParents)
        ..where((t) =>
            t.childLexemeId.equals(childLexemeId) &
            t.parentLexemeId.equals(parentLexemeId)))
      .write(LexemeParentsCompanion(
    relationship: relationship != null
        ? Value(relationship)
        : (clearRelationship ? const Value(null) : const Value.absent()),
    notes: notes != null
        ? Value(notes)
        : (clearNotes ? const Value(null) : const Value.absent()),
  ));
}
```
Alternatively, use a simpler sentinel pattern: require explicit `Value<String?>`
arguments from the caller so the intent (set / clear / preserve) is unambiguous.

---

### WR-02: Truncation check fires before cycle detection — deep cycles misreported as truncations

**File:** `lib/features/lexicon/data/lexeme_providers.dart:535-557`

**Issue:** `buildAncestryNode` checks `depth >= 10` (truncation) before checking
`visited.contains(lexemeId)` (cycle). When a cyclic node is first encountered at
depth 10 or deeper, it returns `isTruncated: true` instead of `isCycle: true`.
The renderer for the truncated sentinel shows "↑ N more ancestors" rather than a
cycle warning, hiding a data integrity problem (a word appearing in its own
ancestor chain) behind a benign-looking depth indicator.

**Fix:** Swap the guard order so cycle detection takes priority:
```dart
AncestryNode? buildAncestryNode({ ... }) {
  final lexeme = lexemeById[lexemeId];
  if (lexeme == null) return null;

  // Cycle detection first — a cycle at depth 10 should be flagged as a cycle,
  // not as a truncation.
  if (visited.contains(lexemeId)) {
    return AncestryNode(
      lexemeId: lexemeId,
      lexeme: lexeme,
      edgeLabel: '',
      isRuleDerived: false,
      isCycle: true,
    );
  }

  // Truncation only after cycle check.
  if (depth >= 10) {
    return AncestryNode(
      lexemeId: lexemeId,
      lexeme: lexeme,
      edgeLabel: '',
      isRuleDerived: false,
      isTruncated: true,
    );
  }

  // ... rest of function unchanged
}
```

---

### WR-03: `_save` in `WordCreationForm` has no `catch` — DB errors are unhandled

**File:** `lib/features/lexicon/presentation/dictionary/word_creation_form.dart:205-246`

**Issue:** The `_save` method wraps its async DB work in `try { … } finally { … }`
but has no `catch` block. If `dao.insertLexeme`, any `parentsDao.insertParent`, or
`derivationPromotionServiceProvider.reconcile()` throws (e.g. a DB constraint
violation, a closed connection during navigation, or a storage I/O error), the
exception propagates as an unhandled `Future` error. Flutter will log it to
`FlutterError.onError` but the user sees nothing — the spinner stops, the form
remains open, and the word may or may not have been saved. A partial save is also
possible: the lexeme row is inserted successfully but the parent-link inserts fail,
leaving the new word without its intended etymology links (there is no wrapping
transaction).

**Fix:** Add a `catch` block that surfaces the error to the user:
```dart
try {
  // ... existing logic ...
  widget.onSaved();
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save word: $e')),
    );
  }
} finally {
  if (mounted) setState(() => _saving = false);
}
```
For the partial-save risk, consider wrapping the lexeme insert and parent-link
inserts in a single `db.transaction(...)` call via the DAO.

---

## Info

### IN-01: Inconsistent null-project sentinel between `allParentLinksProvider` and sibling providers

**File:** `lib/features/lexicon/data/lexeme_providers.dart:459-462` and
`lib/features/grammar/data/grammar_providers.dart:129-131, 138-140`

**Issue:** `allParentLinksProvider` (in `lexeme_providers.dart`) returns
`Stream.value(const [])` when no project is open, which immediately emits an
empty list and transitions the `AsyncValue` to `AsyncData`. The sibling providers
`parentsForLexemeProvider` and `childrenForLexemeProvider` (defined in
`grammar_providers.dart`, not in scope but consumed by the in-scope widgets)
return `const Stream<List<LexemeParentRow>>.empty()`, which never emits and leaves
the `AsyncValue` in `AsyncLoading`. Consumers guard with `.asData?.value ?? []`
so there is no functional bug, but the inconsistency means the provider's
`when(loading: …)` path is permanently triggered for those two providers while the
project is closed — a subtle difference if a caller ever switches to `when()`
instead of `.asData`.

**Fix:** Align the no-project sentinel to `Stream.value(const [])` in
`grammar_providers.dart`:
```dart
// parentsForLexemeProvider — change:
if (dao == null) return const Stream<List<LexemeParentRow>>.empty();
// to:
if (dao == null) return Stream.value(const []);
```
Apply the same change to `childrenForLexemeProvider`.

---

### IN-02: Two parallel ID sets use different element types for the same concept

**File:** `lib/features/lexicon/data/lexeme_providers.dart:143-202`

**Issue:** `filteredLexemeListProvider` builds two sets to track roots whose
derived forms match the search query. `derivedMatchRootIds` is `Set<String>`
(because `Lexeme.rootId` is a `TextColumn`). `computedDerivedMatchRootIds` is
`Set<int>` (because `root.id` is an `IntColumn`). The final filter at line 201
checks membership with `derivedMatchRootIds.contains(l.id.toString())` and
`computedDerivedMatchRootIds.contains(l.id)` — the `toString()` conversion is
correct but fragile: it relies on the implicit assumption that `rootId` strings
are always decimal integer representations of `id` values. If a `rootId` is ever
stored with a leading zero, whitespace, or other format difference, the lookup
silently fails. The asymmetry also makes the code harder to follow.

**Fix:** Normalise both sets to `Set<int>` by parsing `rootId` on insertion:
```dart
final derivedMatchRootIds = <int>{};
// ...
final parsedRootId = int.tryParse(l.rootId!);
if (parsedRootId != null && (matchesIpa || matchesRom || matchesMeaning)) {
  derivedMatchRootIds.add(parsedRootId);
}
// ...
// Then the filter becomes:
derivedMatchRootIds.contains(l.id) ||
computedDerivedMatchRootIds.contains(l.id)
```

---

### IN-03: Truncation test does not assert the exact depth at which truncation fires

**File:** `test/unit/lexicon/ancestry_chain_test.dart:364-407`

**Issue:** The `'chain of 12 words truncates at 10 levels'` test walks the tree
until it finds a node whose first parent is truncated, but never asserts the `depth`
counter value at that point. The test therefore passes regardless of whether
truncation fires at depth 10, depth 5, or depth 8 — as long as truncation fires
somewhere before depth 15. A regression that changes the constant from 10 to 5
would go undetected.

**Fix:** Assert the depth counter at the stopping point:
```dart
expect(depth, equals(9),
    reason: 'Truncation must fire at depth 10 (9 steps from the leaf)');
expect(current.parents.first.isTruncated, isTrue,
    reason: 'Ancestry must truncate at depth 10');
```
Also add a companion test for the cycle-at-depth-10 case once WR-02 is fixed, to
ensure cycles at the max depth are reported as `isCycle` not `isTruncated`.

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
