---
phase: 05-culture-wiki
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/features/culture/data/culture_dao.dart
  - lib/features/culture/data/culture_providers.dart
  - lib/features/culture/domain/block_splitter.dart
  - lib/features/culture/domain/page_history.dart
  - lib/features/culture/presentation/back_forward_bar.dart
  - lib/features/culture/presentation/block_editor.dart
  - lib/features/culture/presentation/culture_page_view.dart
  - lib/features/culture/presentation/culture_shell.dart
  - lib/features/culture/presentation/link_autocomplete.dart
  - lib/features/culture/presentation/page_tree_sidebar.dart
  - lib/features/culture/presentation/wiki_link_syntax.dart
  - lib/router/app_router.dart
  - lib/shared/widgets/app_shell.dart
  - pubspec.yaml
  - test/unit/culture/block_splitter_test.dart
  - test/unit/culture/culture_dao_test.dart
  - test/unit/culture/page_history_test.dart
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

The Phase 5 culture wiki implementation is solid and well-structured. The block-based editor, wiki-link syntax, autocomplete, page tree sidebar, and navigation history all follow established project patterns. The DAO and domain layer are clean. No critical (security, data-loss, or crash) issues were found.

Five warnings were identified, all relating to logic correctness and missing error handling:

1. The `_HoverPreviewOverlay` receives a `WidgetRef ref` as a constructor parameter — this is an anti-pattern that can cause stale-ref issues.
2. The delete dialog confirms "permanently deletes child pages" but the DAO sets `parentId = null` (orphan, not cascade-delete) — the dialog text is incorrect.
3. Block state in `_BlockEditorState` is not reset when the `BlockEditor` widget is replaced with a completely new `pageId` via `didUpdateWidget`, only when `content` differs.
4. Code-fence toggle tracking in `block_splitter.dart` is naive — nested or mismatched fences can get the toggle state permanently wrong.
5. The `_onTextChanged` autocomplete guard exits early when `filtered.isEmpty && query.isEmpty`, but this means that if a user types `[[` and there are zero pages in the project the overlay is never shown (minor UX gap, but also an inconsistency with the "No matching pages — press Enter to create" empty state that is unreachable).

Four informational items are noted below.

---

## Warnings

### WR-01: `_HoverPreviewOverlay` stores a `WidgetRef` as a constructor field

**File:** `lib/features/culture/presentation/block_editor.dart:470-471`

**Issue:** `_HoverPreviewOverlay` is a `ConsumerWidget` that also accepts a `WidgetRef ref` constructor parameter. This `ref` is captured from the parent `_BlockEditorState` at overlay-creation time, then stored as a field. It is not used in the widget body (the `build` method uses its own `watchRef` parameter correctly). If the parent rebuilds and the overlay is still live, the stored `ref` becomes stale. While the field appears unused in the current `build` body, its presence creates a misleading and fragile contract.

**Fix:** Remove the `ref` constructor parameter and the field from `_HoverPreviewOverlay` entirely; the widget already receives a fresh `WidgetRef` as the second argument to `build`.

```dart
// Before
class _HoverPreviewOverlay extends ConsumerWidget {
  const _HoverPreviewOverlay({
    required this.title,
    required this.pageId,
    required this.position,
    required this.ref,   // <-- remove
  });
  final WidgetRef ref;   // <-- remove

// After
class _HoverPreviewOverlay extends ConsumerWidget {
  const _HoverPreviewOverlay({
    required this.title,
    required this.pageId,
    required this.position,
  });
```

---

### WR-02: Delete dialog claims child pages are deleted, but DAO orphans them instead

**File:** `lib/features/culture/presentation/page_tree_sidebar.dart:279-281`

**Issue:** The confirmation dialog reads: *"This page and all its child pages will be permanently deleted."* However `CultureDao.deletePage` is a simple single-row delete that relies on the database `onDelete: setNull` constraint, which sets `parentId = null` on children rather than cascading the delete. Children survive as orphaned root-level pages. The user is shown a false contract.

**Fix:** Either cascade-delete children in the DAO (fetch all descendants recursively and delete them), or correct the dialog text to reflect the actual behavior:

```dart
// Accurate dialog text if orphaning is intended behavior:
content: const Text(
  'This page will be permanently deleted. '
  'Child pages will be moved to the top level.',
),
```

If true cascade-delete is intended, add a recursive helper to `CultureDao`:

```dart
Future<void> deletePageCascade(int id) {
  return transaction(() async {
    final children = await (select(culturePages)
      ..where((t) => t.parentId.equals(id)))
      .get();
    for (final child in children) {
      await deletePageCascade(child.id);
    }
    await (delete(culturePages)..where((t) => t.id.equals(id))).go();
  });
}
```

---

### WR-03: `_BlockEditorState._blocks` not re-initialised when widget swaps to a different page

**File:** `lib/features/culture/presentation/block_editor.dart:74-79`

**Issue:** `didUpdateWidget` only re-splits blocks when `oldWidget.content != widget.content`. If a `BlockEditor` instance is reused with a new `pageId`'s content that happens to equal the old content (e.g., two pages with identical body), blocks are silently not reset. More importantly, if `_editing` is `true` when the parent changes the page, the stale `_blocks` list and the active `_controller` still hold the previous page's data. The edited text could be flushed to the wrong page when `_saveAndExitEdit` eventually fires.

**Fix:** Also cancel any active edit on content change:

```dart
@override
void didUpdateWidget(BlockEditor oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.content != widget.content) {
    _blocks = splitIntoBlocks(widget.content);
    // Note: child _SectionBlock widgets handle their own edit state;
    // consider adding a resetKey or passing pageId as a key to BlockEditor
    // so Flutter rebuilds the widget tree on page change.
  }
}
```

The most robust fix is to key `BlockEditor` on `pageId` at the call site in `culture_page_view.dart` so Flutter replaces the widget entirely:

```dart
// culture_page_view.dart line ~206
BlockEditor(
  key: ValueKey(widget.pageId),   // <-- add this
  content: page.content,
  ...
)
```

---

### WR-04: Code-fence toggle in `block_splitter.dart` does not handle tildes or indented fences

**File:** `lib/features/culture/domain/block_splitter.dart:23-25`

**Issue:** The fence-detection logic toggles `inCodeFence` on every line that starts with triple-backtick (` ``` `). Markdown also supports `~~~` fences (CommonMark spec). More importantly, an info-string on the opening fence (e.g., ` ```dart `) is handled correctly, but a mismatched or unclosed fence (which is valid raw text) will flip `inCodeFence` permanently for the rest of the document, suppressing all subsequent heading splits. Because `flutter_markdown_plus` is used for rendering, the rendered output does not break — but the editor will offer the wrong split points if a fence is unclosed.

**Fix:** Add `~~~` detection and guard against unbalanced fences by tracking the opening fence marker and only toggling on an exact closing match:

```dart
String? _openFence;

for (var i = 0; i < lines.length; i++) {
  final line = lines[i];
  final trimmed = line.trimLeft();

  if (_openFence == null) {
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      _openFence = trimmed.startsWith('```') ? '```' : '~~~';
    }
  } else if (trimmed.startsWith(_openFence!)) {
    _openFence = null;
  }
  final inCodeFence = _openFence != null;
  // ... rest of heading logic
}
```

---

### WR-05: Autocomplete overlay never shown when no pages exist and `[[` is typed

**File:** `lib/features/culture/presentation/link_autocomplete.dart:109-111`

**Issue:** When `filtered.isEmpty && query.isEmpty`, `_removeOverlay()` is called and the method returns. This means when the project has zero pages (empty `pageTitles` list) and the user types `[[`, the overlay never opens, so the "No matching pages — press Enter to create" empty state in `_buildOverlay` is unreachable. The user gets no feedback that autocomplete is active.

**Fix:** Only suppress the overlay when the query is non-empty and filtering produced zero results but do not suppress when query is empty:

```dart
// Remove this early-exit guard:
// if (filtered.isEmpty && query.isEmpty) {
//   _removeOverlay();
//   return;
// }

// Replace with: always show overlay if [[ is open, even with 0 results
if (filtered.isEmpty && query.isNotEmpty) {
  // keep overlay open to show "No matching pages" hint
}
```

Alternatively, only skip the overlay when `widget.pageTitles.isEmpty && query.isEmpty`:

```dart
if (filtered.isEmpty) {
  // show overlay with "No matching pages" hint regardless
}
```

---

## Info

### IN-01: `pageTitleIndexProvider` silently uses last-write-wins on duplicate page titles

**File:** `lib/features/culture/data/culture_providers.dart:19-22`

**Issue:** The map literal `{for (final p in pages) p.title: p.id}` will silently overwrite earlier entries when two pages share a title. The DAO has no unique constraint on `title`. The wiki-link resolver will non-deterministically resolve links to whichever duplicate appears last in the list (ordered by title — the last alphabetical duplicate wins).

**Suggestion:** Either enforce a unique constraint on `CulturePages.title` in the database schema, or track duplicates explicitly so wiki-links pointing to a duplicate title display a disambiguation indicator.

---

### IN-02: `_buildTree` builds nodes without parent links for root nodes, then silently fixes children by replacing map entries

**File:** `lib/features/culture/presentation/page_tree_sidebar.dart:34-71`

**Issue:** The tree-builder creates all nodes without parents in the first pass, then in the second pass replaces `nodeMap[page.id]` with a new `_CulturePageNodeWithParent` instance. The original parentless node is discarded. This works, but if a page's parent appears after it in the `allPages` list (which is ordered by title, not by parent-child relationship), the first pass is needed anyway — so the logic is correct. However, the comment *"Re-create node with parent set (since parent is final) — We use a workaround"* (lines 53-59) acknowledges the design is fragile. If a deeply nested node has the same id referenced by a sibling, the map replacement means the sibling list of the grandparent still holds the old reference. The code relies on only top-level roots holding the replaced node — children are freshly created with parents, so in practice this is safe, but it is easy to misread.

**Suggestion:** Consider making `_parent` mutable (`CulturePageNode? _parent` without `final`) to avoid the workaround subclass, or document the invariant more explicitly.

---

### IN-03: `KeyboardListener` in `_SectionBlockState` uses an anonymous `FocusNode` that leaks

**File:** `lib/features/culture/presentation/block_editor.dart:310-321`

**Issue:** The `KeyboardListener` widget is constructed with `focusNode: FocusNode()` — a freshly allocated `FocusNode` that is never stored and never disposed. Flutter's `FocusNode` is a `ChangeNotifier` that holds listeners; creating it inline and never disposing it causes a minor resource leak on every edit-mode render cycle.

**Fix:** Promote the `FocusNode` to a field on `_SectionBlockState` and dispose it alongside the existing `_focusNode`:

```dart
late FocusNode _keyListenerFocusNode;

@override
void initState() {
  super.initState();
  _keyListenerFocusNode = FocusNode();
  // ...
}

@override
void dispose() {
  _keyListenerFocusNode.dispose();
  // ...
}

// In build:
KeyboardListener(
  focusNode: _keyListenerFocusNode,
  // ...
)
```

---

### IN-04: `_formatDate` in `culture_page_view.dart` is a module-level private function

**File:** `lib/features/culture/presentation/culture_page_view.dart:9-10`

**Issue:** `_formatDate` is a small utility at module scope. This is fine, but the same formatting pattern is likely to be needed elsewhere (e.g., lexicon entry timestamps). Consider moving it to a shared date utilities file so it does not drift into duplication.

**Suggestion:** Extract to `lib/shared/utils/date_format.dart` or use the `intl` package if it is already a dependency (it is not currently in `pubspec.yaml`).

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
