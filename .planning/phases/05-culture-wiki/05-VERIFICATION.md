---
phase: 05-culture-wiki
verified: 2026-04-12T00:00:00Z
status: gaps_found
score: 11/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Providers expose culture page data as streams for reactive UI consumption"
    status: failed
    reason: "selectedCulturePageIdProvider uses StateProvider which is not exported by flutter_riverpod 3.0.3 main import — flutter analyze reports 'The function StateProvider isn't defined' at culture_providers.dart:40"
    artifacts:
      - path: "lib/features/culture/data/culture_providers.dart"
        issue: "Line 40: `StateProvider<int?>` — StateProvider was removed from flutter_riverpod 3.x main export; must use NotifierProvider or import from flutter_riverpod/legacy.dart"
    missing:
      - "Replace `final selectedCulturePageIdProvider = StateProvider<int?>((ref) => null)` with a NotifierProvider equivalent (see lexeme_providers.dart pattern) or add `import 'package:flutter_riverpod/legacy.dart'` if legacy compatibility is acceptable"
  - truth: "[[wiki-links]] render as clickable inline links with primary color"
    status: partial
    reason: "WikiLinkBuilder and WikiLinkSyntax are implemented and wired correctly; however, the compilation error in culture_providers.dart (StateProvider undefined) means selectedCulturePageIdProvider cannot be resolved at runtime, which breaks the _handleLinkTap navigation path in culture_page_view.dart"
    artifacts:
      - path: "lib/features/culture/data/culture_providers.dart"
        issue: "StateProvider compile error cascades to break link-tap navigation"
    missing:
      - "Fix StateProvider issue (see gap 1) to restore navigation from wiki-link taps"
human_verification:
  - test: "Visual rendering of Culture Wiki end-to-end"
    expected: "Culture tab opens wiki view; pages display rendered Markdown with formatted headings, bold, lists; clicking a section enters edit mode; Escape/click-outside saves"
    why_human: "UI rendering, edit mode focus behavior, and visual appearance cannot be verified programmatically"
  - test: "[[wiki-link]] rendering and navigation"
    expected: "Resolved links render in primary color with underline; broken links show circular red ? badge; clicking a resolved link navigates to that page; back arrow becomes active"
    why_human: "Visual inline rendering in MarkdownBody requires running app"
  - test: "Link autocomplete popup"
    expected: "Typing [[ in edit mode shows dropdown of matching page titles; selecting inserts [[title]]"
    why_human: "Overlay positioning and keyboard interaction require manual testing"
  - test: "Hover preview tooltip"
    expected: "Hovering over a resolved [[wiki-link]] shows a tooltip after ~400ms with first ~200 chars of target page content"
    why_human: "Timer-based overlay behavior requires running app"
  - test: "Tree drag-and-drop reparenting"
    expected: "Dragging a page node onto another page reparents it; dragging within same parent reorders"
    why_human: "Drag-and-drop interaction requires manual testing"
---

# Phase 5: Culture Wiki Verification Report

**Phase Goal:** Users can document the world and culture behind their conlang in a structured wiki with Markdown formatting and navigable internal links between pages
**Verified:** 2026-04-12
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CulturePages table exists in schema v13 with parent_id, title, content, icon, ordering, createdAt, updatedAt columns | VERIFIED | `class CulturePages extends Table` at app_database.dart:405; `schemaVersion => 13` at line 466; `if (from < 13)` migration at line 674 |
| 2 | CultureDao provides CRUD operations and tree queries | VERIFIED | culture_dao.dart: watchRootPages, watchChildren, watchAllPages, createPage, updatePage, deletePage, reparentPage, swapOrdering, maxSiblingOrdering all present |
| 3 | Providers expose culture page data as streams for reactive UI consumption | FAILED | `StateProvider<int?>` at culture_providers.dart:40 is undefined in flutter_riverpod 3.0.3 — `flutter analyze` reports compile error; selectedCulturePageIdProvider cannot be resolved |
| 4 | PageHistory class maintains a back/forward navigation stack | VERIFIED | page_history.dart: `class PageHistory extends ChangeNotifier` with push/goBack/goForward/canGoBack/canGoForward |
| 5 | Block splitter correctly splits Markdown content at heading boundaries and round-trips without data loss | VERIFIED | block_splitter.dart: splitIntoBlocks/joinBlocks with inCodeFence logic; 10 unit tests all pass |
| 6 | Culture tab in AppShell is enabled and navigates to the culture wiki | VERIFIED | app_shell.dart:30: `enabled: true, phase: null`; app_router.dart:211: `builder: (_, _) => const CultureShell()` |
| 7 | Culture shell displays a 240px tree sidebar on the left and content area on the right | VERIFIED | culture_shell.dart: `SizedBox(width: 240,)` at line 60, VerticalDivider + Expanded content area |
| 8 | Sidebar shows pages in a tree hierarchy with expand/collapse, first 2 levels expanded by default | VERIFIED | page_tree_sidebar.dart: TreeController with expandAll() + _collapseDeep() at lines 136-150; CulturePageNode tree model present |
| 9 | User can create, rename, set icon, and delete pages via context menu on tree nodes | VERIFIED | page_tree_sidebar.dart: showMenu at line 160 with Rename, Set icon, Add child page, Delete page items; respective dialog methods present |
| 10 | User can drag-and-drop tree nodes to reorder siblings and reparent pages | VERIFIED | page_tree_sidebar.dart: TreeDragTarget at line 387 with reparentPage call at line 394 |
| 11 | Back/forward navigation arrows work at the top of the content area | VERIFIED | back_forward_bar.dart: ListenableBuilder on PageHistory, Icons.arrow_back and Icons.arrow_forward with Opacity(0.3) for disabled state |
| 12 | Page content renders as formatted Markdown by default, not raw text | VERIFIED | block_editor.dart: MarkdownBody at line 393 with WikiLinkSyntax + WikiLinkBuilder; culture_page_view.dart:206 wires BlockEditor |
| 13 | [[wiki-links]] render as clickable inline links with primary color | PARTIAL | WikiLinkSyntax (\[\[([^\]]+)\]\] regex) and WikiLinkBuilder (primary color, ? badge) are implemented and wired; however, the StateProvider compile error in culture_providers.dart breaks selectedCulturePageIdProvider, cascading to link navigation in _handleLinkTap |

**Score:** 11/13 truths verified (1 failed, 1 partial)

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/db/app_database.dart` | VERIFIED | CulturePages table, schemaVersion 13, migration block |
| `lib/features/culture/data/culture_dao.dart` | VERIFIED | Full CRUD + tree queries, extends DatabaseAccessor<AppDatabase> |
| `lib/features/culture/data/culture_providers.dart` | STUB | StateProvider undefined — compile error at line 40 |
| `lib/features/culture/domain/page_history.dart` | VERIFIED | PageHistory extends ChangeNotifier with full back/forward stack |
| `lib/features/culture/domain/block_splitter.dart` | VERIFIED | splitIntoBlocks/joinBlocks with code fence handling |
| `lib/shared/widgets/app_shell.dart` | VERIFIED | Culture tab `enabled: true, phase: null` |
| `lib/features/culture/presentation/culture_shell.dart` | VERIFIED | CultureShell with 240px sidebar + PageHistory lifecycle |
| `lib/features/culture/presentation/page_tree_sidebar.dart` | VERIFIED | PageTreeSidebar with CulturePageNode, TreeController, DnD, context menu |
| `lib/features/culture/presentation/culture_page_view.dart` | VERIFIED | CulturePageView using BlockEditor + pageTitleIndexProvider |
| `lib/features/culture/presentation/back_forward_bar.dart` | VERIFIED | BackForwardBar with ListenableBuilder, back/forward icons |
| `lib/features/culture/presentation/block_editor.dart` | VERIFIED | BlockEditor with splitIntoBlocks, MarkdownBody, TextField, _editing, WikiLinkSyntax wiring |
| `lib/features/culture/presentation/wiki_link_syntax.dart` | VERIFIED | WikiLinkSyntax (InlineSyntax), WikiLinkBuilder (MarkdownElementBuilder) with ? badge |
| `lib/features/culture/presentation/link_autocomplete.dart` | VERIFIED | LinkAutocomplete with [[ detection, OverlayEntry, TapRegion groupId |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| culture_dao.dart | app_database.dart | DatabaseAccessor<AppDatabase> | WIRED | `extends DatabaseAccessor<AppDatabase>` confirmed |
| culture_providers.dart | culture_dao.dart | currentDatabaseProvider watch | WIRED | `ref.watch(currentDatabaseProvider)` + `db.cultureDao.*` confirmed |
| app_router.dart | culture_shell.dart | GoRoute builder | WIRED | import + `builder: (_, _) => const CultureShell()` confirmed |
| page_tree_sidebar.dart | culture_providers.dart | culturePageListProvider | WIRED | `ref.watch(culturePageListProvider)` at line 309 confirmed |
| culture_shell.dart | page_history.dart | PageHistory instance | WIRED | `late PageHistory _pageHistory` with initState/dispose lifecycle confirmed |
| wiki_link_syntax.dart | culture_providers.dart | pageTitleIndexProvider | WIRED (via caller) | pageTitleIndex passed as constructor param from culture_page_view which watches pageTitleIndexProvider |
| block_editor.dart | block_splitter.dart | splitIntoBlocks/joinBlocks | WIRED | `_blocks = splitIntoBlocks(widget.content)` at line 63; `joinBlocks(_blocks)` at line 92 |
| culture_page_view.dart | block_editor.dart | BlockEditor widget | WIRED | `child: BlockEditor(` at line 206 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| culture_page_view.dart | page (CulturePage) | culturePageProvider(pageId) -> currentDatabaseProvider -> cultureDao.watchPageById | Yes — Drift DB stream | FLOWING |
| block_editor.dart | _blocks (List<String>) | splitIntoBlocks(widget.content) — content from parent page | Yes — real page content from DB | FLOWING |
| page_tree_sidebar.dart | pages (List<CulturePage>) | culturePageListProvider -> currentDatabaseProvider -> cultureDao.watchAllPages | Yes — Drift DB stream | FLOWING |
| wiki_link_syntax.dart | pageTitleToId (Map<String,int>) | pageTitleIndexProvider -> culturePageListProvider -> DB | Yes — derived from real DB rows | FLOWING |
| culture_providers.dart | selectedCulturePageIdProvider | StateProvider — UNDEFINED | No — compile error | DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Unit tests (24 tests) | `flutter test test/unit/culture/` | 24/24 passed | PASS |
| flutter analyze culture data layer | `flutter analyze lib/features/culture/data/` | 1 error: StateProvider undefined | FAIL |
| flutter analyze culture presentation layer | `flutter analyze lib/features/culture/presentation/` | No issues | PASS |
| flutter analyze culture domain layer | `flutter analyze lib/features/culture/domain/` | No issues | PASS |
| flutter analyze routing + app shell | `flutter analyze lib/router/app_router.dart lib/shared/widgets/app_shell.dart` | Info only (style), no errors | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CULT-01 | 05-01, 05-02, 05-03 | User can create and organize wiki-style documentation pages in Markdown format | PARTIAL | Pages, tree sidebar, block editor, and Markdown rendering are implemented. StateProvider compile error in selectedCulturePageIdProvider means the ephemeral page selection state is broken at compile time. |
| CULT-02 | 05-01, 05-03 | User can create internal links between culture pages (wiki-style linking) | PARTIAL | WikiLinkSyntax, WikiLinkBuilder, broken-link badge, autocomplete overlay all implemented. Navigation through link taps depends on selectedCulturePageIdProvider which has the StateProvider compile error. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| lib/features/culture/data/culture_providers.dart | 40 | `StateProvider<int?>` — removed from flutter_riverpod 3.x main export | Blocker | selectedCulturePageIdProvider is used in 5 call sites across culture_shell.dart, culture_page_view.dart, page_tree_sidebar.dart; entire page selection flow is broken at compile time |

### Human Verification Required

#### 1. Culture Wiki End-to-End Rendering

**Test:** Open a project, click Culture tab, create pages with Markdown content (headings, bold, lists), click a section to enter edit mode, press Escape to save
**Expected:** Content renders as formatted HTML-like Markdown; clicking sections shows a raw TextField; Escape saves and returns to rendered view; timestamps show in page header
**Why human:** Visual rendering and focus behavior require a running app

#### 2. [[wiki-link]] Visual States

**Test:** Create two pages, add `[[OtherPage]]` in content, also add `[[NonExistent]]`
**Expected:** OtherPage renders as a primary-color underlined link; NonExistent renders with a red circular ? badge; clicking OtherPage navigates to that page
**Why human:** Inline MarkdownBody widget rendering requires a running app

#### 3. [[ Autocomplete Popup

**Test:** In edit mode, type `[[` and begin typing a partial page title
**Expected:** A dropdown appears below the cursor with matching page titles; arrow keys navigate; Enter inserts `[[title]]`
**Why human:** Overlay positioning and keyboard interaction require manual testing

#### 4. Hover Preview Tooltip

**Test:** Hover the mouse over a resolved [[wiki-link]] for ~500ms
**Expected:** A tooltip panel appears showing the first ~200 chars of the target page content
**Why human:** Timer-based overlay behavior requires a running app

#### 5. Drag-and-Drop Page Reordering

**Test:** With multiple pages in the sidebar, drag one page and drop it onto another to reparent it; drag within same parent to reorder
**Expected:** Tree reflects new parent/child structure; sibling ordering updates
**Why human:** Drag gesture interaction requires manual testing

### Gaps Summary

One blocker gap prevents CULT-01 and CULT-02 from being fully satisfied:

**StateProvider compile error** (`lib/features/culture/data/culture_providers.dart:40`): `flutter_riverpod 3.0.3` removed `StateProvider` from its main export. The `selectedCulturePageIdProvider` — which tracks which page is currently selected in the wiki — uses `StateProvider<int?>` but this symbol is undefined. This is a compile error confirmed by both `flutter analyze` and `dart analyze`.

The symbol is used at 5 call sites:
- `culture_shell.dart:40` — set selected page on sidebar item tap
- `culture_shell.dart:54` — read selected page to show content or empty state
- `culture_shell.dart:127` — set selected page on "New page" creation
- `culture_page_view.dart:61` — set selected page on link navigation
- `culture_page_view.dart:88` — set selected page on broken-link page creation
- `page_tree_sidebar.dart:382` — read selected page to show selected state in tree

**Fix:** Replace `StateProvider<int?>` with a `NotifierProvider` following the pattern already used in `lexeme_providers.dart`:

```dart
class _SelectedCulturePageId extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final selectedCulturePageIdProvider = NotifierProvider<_SelectedCulturePageId, int?>(
  _SelectedCulturePageId.new,
);
```

Call sites using `ref.read(selectedCulturePageIdProvider.notifier).state = pageId` will need updating to `ref.read(selectedCulturePageIdProvider.notifier).set(pageId)`.

All other implementation is substantive and correctly wired. 24 unit tests pass. The data layer, tree sidebar, block editor, wiki-link syntax, autocomplete, and hover preview are all implemented with real data flows. The gap is a single provider definition that prevents the feature from compiling cleanly.

---

_Verified: 2026-04-12_
_Verifier: Claude (gsd-verifier)_
