---
phase: 11-lexicon-etymology-chain
reviewed: 2026-04-14T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/features/lexicon/domain/ancestry_node.dart
  - test/unit/lexicon/ancestry_chain_test.dart
  - test/unit/lexicon/promoted_derivation_chain_test.dart
  - lib/features/lexicon/data/lexeme_providers.dart
  - lib/features/grammar/data/lexeme_parents_dao.dart
  - lib/features/grammar/data/lexeme_parents_dao.g.dart
  - lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart
  - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
  - lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart
  - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-04-14
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 11 adds the etymology chain tree (LEX-09): the `AncestryNode` domain
model, recursive `buildAncestryNode` traversal, ancestry/promoted-derivation
providers, `EtymologyChainSection` widget, `SearchableParentSelector`, and
integration into `WordDetailPanel`. The `LexemeParentsDao` is a clean
straightforward Drift accessor.

The domain logic (`buildAncestryNode`, `promotedDerivedFormProvider`) is
correct, well-commented, and thoroughly tested. The DAG-vs-cycle distinction is
properly handled with per-branch visited sets. Two functional bugs were found in
the presentation layer: the search field is not cleared after selection in
`SearchableParentSelector`, and the children connector in
`EtymologyChainSection` ignores the actual child count. One silent data-loss
risk exists in the DAO mutation calls inside `_buildAddParentSection`. Two
informational items round out the findings.

---

## Warnings

### WR-01: Search field not cleared after selecting a parent

**File:** `lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart:93-95`

**Issue:** In `onSelected`, `_searchController.clear()` is called, but
`_searchController` is never linked to the `TextField` rendered in
`fieldViewBuilder`. The `fieldViewBuilder` receives its own `controller`
argument from the `Autocomplete` widget — that controller is what drives the
visible field, and it is never assigned to `_searchController`. As a result,
after the user picks a word from the dropdown the autocomplete text field
retains the search text rather than clearing, which breaks the expected UX and
may confuse users into thinking the selection did not register.

The comment on line 98-100 ("We assign the autocomplete-provided controller to
our internal reference so clear() reaches the rendered field.") describes the
intended behaviour but the implementation is missing.

**Fix:**
```dart
// In _SearchableParentSelectorState — remove _searchController entirely and
// call clear() on the controller provided by fieldViewBuilder instead.

// 1. Remove the field:
//    final TextEditingController _searchController = TextEditingController();
// 2. Remove _searchController.dispose() from dispose().
// 3. Capture the autocomplete controller and expose it via a nullable ref:
TextEditingController? _autocompleteController;

// 4. In fieldViewBuilder, store the reference:
fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
  _autocompleteController = controller;        // <-- add this line
  return TextField(controller: controller, ...);
},

// 5. In onSelected, clear via the stored ref:
onSelected: (lx) {
  widget.onChanged({...widget.selectedIds, lx.id});
  _autocompleteController?.clear();            // was: _searchController.clear()
},
```

---

### WR-02: Children connector hardcodes `nodeCount: 1` regardless of actual child count

**File:** `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart:134`

**Issue:** The connector drawn between the current word and its children is
always rendered with `nodeCount: 1`, so it is always a straight vertical line.
When a word has two or more children (e.g. multiple rule-derived forms plus
manual children), the visual still shows one straight line feeding into a row
of multiple chips. The `_ConnectorPainter` supports an inverted fan for
`nodeCount > 1`; it is simply never triggered for the child connector.

**Fix:**
```dart
// Compute total child count before the connector call.
final totalChildCount = ruleDerivedChildren.length + manualChildren.length;

// Then use it:
_connector(context, nodeCount: totalChildCount, inverted: true),
```

---

### WR-03: Unawaited `Future`s from DAO mutations in `_buildAddParentSection`

**File:** `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart:530-536`

**Issue:** `dao.insertParent(...)` and `dao.deleteParent(...)` both return
`Future<void>` / `Future<int>` but the return values are silently discarded
inside the synchronous `onChanged` callback. If either call throws (e.g. due
to a database constraint violation or a closed connection during navigation),
the error is swallowed with no indication to the user and the UI tree may
diverge from the database state.

```dart
// Current code (unawaited):
for (final id in newIds.difference(manualParentIds)) {
  dao.insertParent(
      childLexemeId: widget.lexeme.id, parentLexemeId: id);
}
for (final id in manualParentIds.difference(newIds)) {
  dao.deleteParent(
      childLexemeId: widget.lexeme.id, parentLexemeId: id);
}
```

**Fix:** Convert `onChanged` to accept an async callback or run the mutations
in a helper method with `unawaited(...)` from `package:async` to make the
intentional discard explicit, and wrap in error handling:

```dart
onChanged: (newIds) async {
  final dao = ref.read(lexemeParentsDaoProvider);
  if (dao == null) return;
  try {
    for (final id in newIds.difference(manualParentIds)) {
      await dao.insertParent(
          childLexemeId: widget.lexeme.id, parentLexemeId: id);
    }
    for (final id in manualParentIds.difference(newIds)) {
      await dao.deleteParent(
          childLexemeId: widget.lexeme.id, parentLexemeId: id);
    }
  } catch (e, st) {
    // Log or surface error. For now at minimum prevent silent failure.
    debugPrint('Etymology parent update failed: $e\n$st');
  }
},
```

Note: `SearchableParentSelector.onChanged` is typed `ValueChanged<Set<int>>`
(synchronous). The quickest minimal fix is to wrap each unawaited call with
`unawaited(dao.insertParent(...))` to make the discard explicit and satisfy
the linter, and add a `.catchError` to surface failures.

---

## Info

### IN-01: Empty-level rows possible from `_flattenAncestry` in sparse DAGs

**File:** `lib/features/lexicon/presentation/dictionary/etymology_chain_section.dart:54`

**Issue:** `_flattenAncestry` populates `byDepth` from actual traversal and
then reconstructs the levels array with `byDepth[d] ?? []` for every depth
from `maxD` down to 1. In a DAG where the `seen` deduplication causes a
certain depth `d` to have no entries (because all nodes at that depth were
already claimed by another branch at an earlier depth), `byDepth[d]` is `null`
and the fallback `[]` is returned. This means `ancestryLevels` may contain
empty sublists, causing `_levelRow` to render an invisible empty `Row` and
`_connector` to receive `nodeCount: 0`. The painter handles `nodeCount <= 1`
as a straight line so there is no crash, but the empty row still consumes
vertical space and there is no test covering this edge case.

**Fix:** Filter out empty levels before rendering:
```dart
// In _flattenAncestry, change the return to:
return [
  for (int d = maxD; d >= 1; d--)
    if (byDepth[d] != null && byDepth[d]!.isNotEmpty) byDepth[d]!,
];
```

---

### IN-02: `_saveEdit` has no in-flight guard — double-tap can submit twice

**File:** `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart:998`

**Issue:** `_WordCreationFormState._save` guards against re-entry with a
`_saving` flag (disables the Save button while async work is in flight).
`_WordDetailPanelState._saveEdit` has no equivalent guard. Rapidly tapping
"Save" twice can trigger two concurrent `dao.updateLexeme` calls and two
`reconcile()` invocations on the same lexeme. On a fast device this is
unlikely to cause data corruption (the second update simply overwrites the
first with identical data), but it is an inconsistency with the creation form's
pattern and can produce unexpected reconciliation runs.

**Fix:** Add a `_saving` state field to `_WordDetailPanelState` mirroring the
pattern in `_WordCreationFormState`:
```dart
bool _saving = false;

// In _saveEdit:
if (_saving) return;
setState(() => _saving = true);
try {
  // ... existing logic ...
} finally {
  if (mounted) setState(() => _saving = false);
}

// In _buildEditMode Save button:
FilledButton(
  onPressed: _saving ? null : () => _saveEdit(lexeme),
  child: _saving
      ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Text('Save'),
),
```

---

_Reviewed: 2026-04-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
