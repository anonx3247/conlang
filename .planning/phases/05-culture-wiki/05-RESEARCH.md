# Phase 5: Culture Wiki - Research

**Researched:** 2026-04-12
**Domain:** Flutter Markdown wiki with tree-hierarchy pages, [[wikilink]] inline syntax, block-based editing, drag-and-drop tree reordering
**Confidence:** HIGH (codebase verified), MEDIUM (library versions verified via pub.dev), LOW (drag-and-drop DnD specifics)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Pages organized in a parent-child tree hierarchy (not flat list or tags)
- **D-02:** Sidebar tree expands the first 2 levels of depth by default; deeper nodes start collapsed
- **D-03:** Drag-and-drop for reordering siblings and reparenting pages in the tree
- **D-04:** Page CRUD interaction pattern — Claude's discretion
- **D-05:** Block-based editing: pages render as Markdown by default. Click a heading section to edit its raw Markdown inline (Wikipedia/Jupyter-style section editing)
- **D-06:** Blocks are heading-based sections — each heading (`##`, `###`, etc.) defines an editable block; content between headings is one editable unit
- **D-07:** No formatting toolbar — raw Markdown typing only
- **D-08:** Syntax highlighting in the Markdown editor when a block is in edit mode
- **D-09:** `[[wiki-links]]` with autocomplete popup — typing `[[` opens a dropdown of existing page titles
- **D-10:** Broken links (linking to non-existent pages) display a `?` icon next to the link text
- **D-11:** Clicking a broken link shows a "Create this page?" confirmation prompt, then creates the page if confirmed
- **D-12:** No backlinks section on pages
- **D-13:** Browser-style back/forward navigation arrows at the top of the page for page history traversal
- **D-14:** Auto-tracked created and last-modified timestamps per page
- **D-15:** Optional icon or emoji per page, displayed in the tree and page header
- **D-16:** Hovering over an internal link shows a preview tooltip with the first portion of the linked page's content

### Claude's Discretion
- Page CRUD interaction pattern (D-04)
- Empty state design for a wiki with no pages
- Exact drag-and-drop library/implementation approach
- Markdown rendering library choice (flutter_markdown or alternatives)
- Syntax highlighting library for the editor blocks
- Preview tooltip sizing and content truncation
- How new blocks/sections are added (button placement, interaction)
- Navigation arrow placement and styling

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CULT-01 | User can create and organize wiki-style documentation pages in Markdown format | flutter_markdown_plus rendering, Drift CulturePages table, tree sidebar, block-based editing |
| CULT-02 | User can create internal links between culture pages (wiki-style linking) | Custom `[[link]]` InlineSyntax extension, autocomplete overlay, broken-link detection at render time |
</phase_requirements>

---

## Summary

Phase 5 builds a Markdown wiki feature within the existing Flutter + Drift + Riverpod architecture. The feature is a self-contained `lib/features/culture/` module following the same data/domain/presentation split used by phonology, grammar, and lexicon. The primary new complexity is threefold: (1) a tree-structured page hierarchy in SQLite using a self-referential `parent_id` foreign key, (2) a custom `[[wikilink]]` inline syntax extension for `flutter_markdown_plus`, and (3) a block-based editor where each Markdown heading-section is individually editable in-place.

The `flutter_markdown` package was discontinued by Google in 2025 and replaced by the community-maintained `flutter_markdown_plus` (v1.0.7). This is the correct package to add. The `dart:markdown` package (underlying both) provides an `InlineSyntax` API that is well-suited for implementing `[[...]]` wiki-link parsing. There is no existing Flutter pub.dev package that pre-builds wiki-link syntax — it must be hand-built, but the implementation is ~30 lines following a well-documented pattern.

For the tree sidebar with drag-and-drop, `flutter_fancy_tree_view2` (v1.6.3, November 2025) is the active maintained fork of the discontinued `flutter_fancy_tree_view`. It provides `TreeDraggable` and `TreeDragTarget` wrappers with auto-expand-on-hover and auto-scroll behavior. Alternatively, the tree can be built from scratch with Flutter's `Draggable`/`DragTarget` if the tree depth is constrained — both approaches are viable given the project's existing widget-composition patterns.

**Primary recommendation:** Add `flutter_markdown_plus` for rendering and `flutter_fancy_tree_view2` for the tree sidebar. Implement `[[wikilink]]` as a custom `InlineSyntax` + `MarkdownElementBuilder`. Build the block editor as a `StatefulWidget` that splits page content by heading boundaries, renders each section as `MarkdownBody` in read mode and a plain `TextField` in edit mode.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_markdown_plus | ^1.0.7 | Render Markdown pages with custom syntax | Official successor to flutter_markdown (Google-discontinued 2025); supports custom InlineSyntax and builders |
| flutter_fancy_tree_view2 | ^1.6.3 | Tree sidebar with expand/collapse and DnD | Active fork (Nov 2025) of the discontinued flutter_fancy_tree_view; includes TreeDraggable/TreeDragTarget |
| dart:markdown (transitive) | via flutter_markdown_plus | InlineSyntax API for `[[...]]` custom parsing | Dart's markdown parsing AST layer; no separate install needed |
| flutter_highlight | 0.7.0 | Syntax highlighting in Markdown editor text fields | **Caution: last published March 2021.** Use only if compatible; see Pitfall 2 below |

[VERIFIED: pub.dev — flutter_markdown_plus v1.0.7, flutter_fancy_tree_view2 v1.6.3, flutter_highlight v0.7.0]

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flutter built-in `Autocomplete` | SDK | Autocomplete popup for `[[...]]` input | Sufficient for the wiki-link title dropdown; no extra package needed |
| Flutter built-in `Tooltip` | SDK | Link hover preview (D-16) | Standard Flutter widget; sufficient for the preview tooltip |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| flutter_fancy_tree_view2 | Hand-built ListView + Draggable | Hand-built is simpler for 2-level trees but misses auto-expand and auto-scroll; use fancy_tree_view2 for correctness at any depth |
| flutter_markdown_plus | markdown_widget | markdown_widget is heavier, harder to extend with custom inline syntax; flutter_markdown_plus InlineSyntax API is simpler for wiki-link extension |
| flutter_highlight | Plain TextStyle theming on TextField | flutter_highlight is 5 years stale; a plain TextField with a dark background and monospace font may be sufficient given "no formatting toolbar" requirement (D-07) |

**Installation:**
```bash
flutter pub add flutter_markdown_plus flutter_fancy_tree_view2
# flutter_highlight is optional — evaluate stale status before adding
```

**Version verification:** [VERIFIED: pub.dev — flutter_markdown_plus 1.0.7 (3 months ago), flutter_fancy_tree_view2 1.6.3 (November 2025), flutter_highlight 0.7.0 (March 2021 — stale)]

---

## Architecture Patterns

### Recommended Project Structure
```
lib/features/culture/
├── data/
│   ├── culture_dao.dart          # Drift DAO — CRUD + tree queries
│   ├── culture_dao.g.dart        # generated
│   └── culture_providers.dart    # StreamProvider/Provider for DAO results
├── domain/
│   ├── culture_page.dart         # Domain model: CulturePageData wrapper, link resolution
│   ├── wiki_link_resolver.dart   # Takes page title → resolves to id or null (broken)
│   └── page_history.dart         # Back/forward stack (plain Dart class, no DB)
└── presentation/
    ├── culture_shell.dart        # Left sidebar tree + main content area — mirrors GrammarShell
    ├── culture_page_view.dart    # Full page view: header + block list + nav arrows
    ├── block_editor.dart         # StatefulWidget: read=MarkdownBody, edit=TextField per section
    ├── wiki_link_syntax.dart     # InlineSyntax + MarkdownElementBuilder for [[links]]
    ├── page_tree_sidebar.dart    # flutter_fancy_tree_view2 tree with CRUD context menu
    └── link_autocomplete.dart    # [[...]] autocomplete overlay widget
```

### Pattern 1: Drift Table — Self-Referential Tree (parent_id)
**What:** `CulturePages` table with a nullable `parent_id` FK pointing to itself. Root pages have `parent_id = null`.
**When to use:** All parent-child tree operations — list children, move page (update parent_id), get ancestors.

```dart
// Source: [ASSUMED] — standard Drift self-referential FK pattern
class CulturePages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get parentId => integer().nullable().references(CulturePages, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get icon => text().nullable()(); // emoji or icon codepoint string
  IntColumn get ordering => integer().withDefault(const Constant(0))(); // sibling sort order
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**Key DAO queries needed:**
- `watchRootPages()` — `WHERE parent_id IS NULL ORDER BY ordering`
- `watchChildren(int parentId)` — `WHERE parent_id = ? ORDER BY ordering`
- `reparentPage(int pageId, int? newParentId)` — update parent_id + reorder
- `watchAllPages()` — for wiki-link resolver title lookup

**Schema version:** v12 → v13 migration adds `CREATE TABLE culture_pages`.

### Pattern 2: Block-Based Section Editor
**What:** Split page `content` string by heading markers into blocks. Render each block as `MarkdownBody` (read) or `TextField` (edit). On save, reassemble blocks back into one string.
**When to use:** Every content edit interaction (D-05, D-06).

```dart
// Source: [ASSUMED] — pattern derived from D-05/D-06 requirements

/// Splits raw Markdown into heading-delimited sections.
/// Returns list of [sectionTitle, sectionContent] pairs.
/// First entry is pre-heading content (may be empty).
List<String> splitIntoBlocks(String markdown) {
  // Split on lines that start with one or more `#` characters
  final headingRe = RegExp(r'^#{1,6} ', multiLine: true);
  final matches = headingRe.allMatches(markdown).toList();
  if (matches.isEmpty) return [markdown];
  
  final blocks = <String>[];
  int prev = 0;
  for (final m in matches) {
    if (m.start > prev) blocks.add(markdown.substring(prev, m.start));
    prev = m.start;
  }
  blocks.add(markdown.substring(prev));
  return blocks;
}
```

The `_BlockWidget` is a `StatefulWidget` with a boolean `_editing` flag. `GestureDetector(onTap: () => setState(() => _editing = true))` wraps the `MarkdownBody`. When editing, focus + save on `TextField.onSubmitted` or focus-loss callback.

### Pattern 3: Custom `[[wikilink]]` InlineSyntax
**What:** Extend `md.InlineSyntax` to match `[[page title]]` patterns. Produce a custom AST node. `MarkdownElementBuilder` renders it as a tappable `InkWell` with resolved/broken visual state.
**When to use:** Every Markdown render pass (passed to `MarkdownBody(inlineSyntaxes:..., builders:...)`).

```dart
// Source: [VERIFIED: github.com/flutter/flutter/issues/105571]
import 'package:markdown/markdown.dart' as md;

class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax() : super(r'\[\[([^\]]+)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match.group(1)!.trim();
    final el = md.Element.text('wikilink', title);
    el.attributes['title'] = title;
    parser.addNode(el);
    return true;
  }
}

class WikiLinkBuilder extends MarkdownElementBuilder {
  final Map<String, int> pageTitleToId; // resolved titles
  final void Function(String title, bool exists) onLinkTap;

  WikiLinkBuilder({required this.pageTitleToId, required this.onLinkTap});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final title = element.attributes['title'] ?? element.textContent;
    final exists = pageTitleToId.containsKey(title);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onLinkTap(title, exists),
          child: Text(title, style: TextStyle(
            color: exists ? Colors.blue : Colors.grey,
            decoration: TextDecoration.underline,
          )),
        ),
        if (!exists) const Icon(Icons.help_outline, size: 12), // D-10: ? icon
      ],
    );
  }
}
```

### Pattern 4: `[[...]]` Autocomplete During Editing
**What:** When user types `[[` in a block TextField, open an overlay with matching page titles using Flutter's `Autocomplete` widget or a manual `OverlayEntry`.
**When to use:** Only in edit mode blocks, only after `[[` trigger (D-09).

Use `TextEditingController.addListener` to detect `[[` in the text. When detected, show an `OverlayEntry` positioned below the cursor using `CompositedTransformFollower`. Filter page titles as user continues typing. On selection, replace the open `[[...` fragment with the chosen `[[title]]` and close overlay.

### Pattern 5: Page History (Back/Forward)
**What:** A plain Dart class `PageHistory` holding a `List<int> _stack` and `int _cursor`. Push on navigation, move cursor for back/forward (D-13).
**When to use:** Every page navigation event.

```dart
// Source: [ASSUMED]
class PageHistory extends ChangeNotifier {
  final _stack = <int>[];
  int _cursor = -1;

  bool get canGoBack => _cursor > 0;
  bool get canGoForward => _cursor < _stack.length - 1;

  void push(int pageId) {
    _stack.removeRange(_cursor + 1, _stack.length);
    _stack.add(pageId);
    _cursor = _stack.length - 1;
    notifyListeners();
  }

  int? goBack() { if (canGoBack) { _cursor--; notifyListeners(); return _stack[_cursor]; } return null; }
  int? goForward() { if (canGoForward) { _cursor++; notifyListeners(); return _stack[_cursor]; } return null; }
}
```

Expose via a `Provider<PageHistory>` scoped to the culture feature.

### Pattern 6: CultureShell Layout
**What:** Left sidebar (tree) + right content area — mirrors GrammarShell/LexiconShell patterns exactly.
**When to use:** Top-level culture route.

The sidebar is NOT a `StatefulNavigationShell` sub-tab bar (unlike grammar/lexicon) because culture is a single page+detail view, not multiple sub-sections. The sidebar tree IS the navigation — selecting a tree node pushes to `/culture/page/:id`.

GoRouter: `/culture` → `CultureShell` with child route `/culture/page/:id`. The shell renders the tree sidebar + a content area that shows selected page or empty state.

### Anti-Patterns to Avoid
- **Storing the entire tree in a single JSON column:** The tree must be stored as normalized rows with `parent_id` FK — enables atomic parent changes, stream watching on subtrees, and correct cascade deletes.
- **Re-parsing ALL page titles for link resolution on every render:** Build a `Map<String, int>` title→id provider that is watched via `StreamProvider`, not recomputed inline per render.
- **Putting `PageHistory` in Drift:** History is ephemeral session state (browser-style), not persisted. Plain Dart `ChangeNotifier` + Riverpod `Provider` is correct.
- **Using `flutter_markdown` (original):** It was discontinued in 2025. Use `flutter_markdown_plus` instead. [VERIFIED: pub.dev search]
- **Using `flutter_fancy_tree_view` (original):** Discontinued. Use `flutter_fancy_tree_view2`. [VERIFIED: pub.dev — marked discontinued]
- **Splitting blocks on ALL `#` characters:** Must only split on `#` at the start of a line followed by a space — `r'^#{1,6} '` multiline regex, not a simple `contains('#')` check.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown rendering | Custom text parser | `flutter_markdown_plus` | CommonMark/GFM compliance, handles nested inline, tables, fenced code |
| Tree node expand/collapse animations | Manual AnimatedContainer tricks | `flutter_fancy_tree_view2` `AnimatedTreeView` | Handles sliver-based rendering, lazy loading, depth-first traversal |
| `[[...]]` link parsing | String `.split('[[')` | `md.InlineSyntax` subclass | InlineSyntax correctly interleaves with other markdown inline elements; string splitting breaks on adjacent inline markup |
| Autocomplete overlay positioning | Manual Positioned widget math | `CompositedTransformFollower` + `OverlayEntry` OR Flutter's `Autocomplete` widget | Handles viewport edge cases, keyboard avoidance |

**Key insight:** The inline syntax extension for `[[...]]` looks simple but must be done through the markdown AST API — not string post-processing — because `[[link]]` can appear inside bold text, headings, etc., and string splitting will corrupt surrounding markup.

---

## Common Pitfalls

### Pitfall 1: flutter_markdown_plus InlineSyntax Not Applied to Code Blocks
**What goes wrong:** Custom `WikiLinkSyntax` matches `[[...]]` even inside fenced code blocks (` ``` `) — links become clickable inside code examples.
**Why it happens:** `InlineSyntax` runs on all inline content including code spans by default.
**How to avoid:** Override `allowsIntraWord` / check `parser.enclosingTagName` in `onMatch` to abort inside code elements. Alternatively, accept this edge case since wiki pages are unlikely to have code blocks containing `[[...]]`.
**Warning signs:** Clicking text inside a code block navigates to a page.

### Pitfall 2: flutter_highlight Is 5 Years Stale
**What goes wrong:** `flutter_highlight` (v0.7.0, published March 2021) may have incompatibilities with current Flutter SDK 3.x APIs.
**Why it happens:** Package is unmaintained. [VERIFIED: pub.dev — published March 7, 2021]
**How to avoid:** For the editor block TextField (D-08), a plain `TextField` with a dark monospace `TextStyle` (no color tokens) is likely sufficient since the requirement is "raw Markdown typing" (D-07). If richer syntax colouring is needed, investigate `syntax_highlight` (pub.dev) instead — it uses TextMate rules, VSCode-style, and is more actively maintained. [MEDIUM confidence — not verified for current version]
**Warning signs:** `flutter pub get` errors or deprecated API warnings when adding `flutter_highlight`.

### Pitfall 3: Drift Codegen for Self-Referential FK
**What goes wrong:** Drift code generation for `CulturePages` with `references(CulturePages, #id)` may produce circular import or codegen issues due to self-referencing.
**Why it happens:** Drift's generator resolves FK targets; self-reference is unusual.
**How to avoid:** Use the standard pattern exactly as shown above. Drift does support self-referential FKs — the generated `CulturePages` companion class will have a nullable `parentId` column. Verified by convention with other Drift self-referential patterns; test with `dart run build_runner build` immediately after table definition. [ASSUMED — not verified in this codebase specifically]
**Warning signs:** Build errors like "circular reference" or "unable to resolve table" during `build_runner build`.

### Pitfall 4: Block Splitting Produces Orphaned Pre-Heading Content
**What goes wrong:** Content before the first heading (e.g., an intro paragraph) is in an unnamed block with no heading. Click-to-edit is unclear for this block.
**Why it happens:** Heading-based splitting naturally produces a "block 0" with no header.
**How to avoid:** Treat the pre-heading content as a special "intro block" rendered normally. Display an edit handle (e.g., pencil icon on hover, D-04 discretion area) for it. When empty, show nothing or a "+" placeholder.
**Warning signs:** User cannot edit text placed before the first heading.

### Pitfall 5: Wiki-Link Autocomplete Overlay During [[...]] Input Conflicts with Block Save
**What goes wrong:** The autocomplete overlay captures focus or keypresses. When user presses Enter to accept a suggestion, the block editor interprets it as a save/blur event and collapses the edit mode before the selection completes.
**Why it happens:** Focus management with overlays in Flutter requires careful `FocusNode` coordination — the same problem the IPA keyboard popup hit in Phase 1 (resolved with `TapRegion groupId` + delay pattern in plan 01-08/01-10).
**How to avoid:** Reuse the established pattern from `lib/features/phonology/presentation/` — `TapRegion` with shared `groupId`, `_isInteractingWithOverlay` flag + 100ms delay in focus-loss handler (as documented in STATE.md decisions 01-08, 01-10).
**Warning signs:** Accepting an autocomplete suggestion collapses the editor block immediately.

### Pitfall 6: Tree ordering Column Drift — Concurrent Reorder
**What goes wrong:** When user drags a node to position 3 out of 10 siblings, naive "shift all ordering values" leads to N updates and potential race conditions in reactive streams.
**Why it happens:** Ordering is stored as integer per sibling. Moving a node mid-list requires updating all subsequent rows.
**How to avoid:** Use a `transaction()` to atomically update the moved node's ordering and shift siblings — same pattern as morphological rule reordering in plan 02-07 (STATE.md decision). Alternatively use a floating-point ordering approach (LexoRank-style) to avoid cascaded updates. For simplicity, the transaction approach from 02-07 is preferred since it's already established in this codebase. [ASSUMED for tree-specific application]

---

## Code Examples

Verified patterns from official sources:

### flutter_markdown_plus: Register Custom InlineSyntax
```dart
// Source: [VERIFIED: pub.dev/packages/flutter_markdown_plus + github.com/flutter/flutter/issues/105571]
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as fm;
import 'package:markdown/markdown.dart' as md;

MarkdownBody(
  data: pageContent,
  inlineSyntaxes: [WikiLinkSyntax()],
  builders: {'wikilink': WikiLinkBuilder(pageTitleToId: resolvedTitles, onLinkTap: _onLinkTap)},
  extensionSet: md.ExtensionSet(
    md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    [WikiLinkSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
  ),
)
```

### flutter_fancy_tree_view2: Minimal Tree Setup
```dart
// Source: [VERIFIED: pub.dev/packages/flutter_fancy_tree_view2 documentation]
late final TreeController<CulturePageNode> _treeController;

@override
void initState() {
  super.initState();
  _treeController = TreeController<CulturePageNode>(
    roots: rootPages,
    childrenProvider: (node) => node.children,
    parentProvider: (node) => node.parent,
  );
}

@override
Widget build(BuildContext context) {
  return AnimatedTreeView<CulturePageNode>(
    treeController: _treeController,
    nodeBuilder: (context, entry) => TreeDragTarget<CulturePageNode>(
      node: entry.node,
      onNodeAccepted: (details) => _onNodeDropped(details),
      builder: (context, details) => TreeDraggable<CulturePageNode>(
        node: entry.node,
        feedback: _DragFeedback(node: entry.node),
        child: _TreeNodeTile(entry: entry),
      ),
    ),
  );
}
```

### Drift Schema v13 Migration Block
```dart
// Source: [VERIFIED: lib/db/app_database.dart migration pattern]
if (from < 13) {
  await m.createTable(culturePages);
}
```

### Provider Pattern for Culture Pages (manual, no codegen)
```dart
// Source: [VERIFIED: established pattern in lib/features/*/data/*_providers.dart]
// Use manual Provider/StreamProvider — NOT @riverpod codegen — for Drift-typed results
final culturePageListProvider = StreamProvider.autoDispose<List<CulturePagesData>>((ref) {
  final db = ref.watch(projectDatabaseProvider)!;
  return db.cultureDao.watchAllPages();
});

final pageTitleIndexProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final pages = ref.watch(culturePageListProvider).valueOrNull ?? [];
  return {for (final p in pages) p.title: p.id};
});
```

Note: use `ref.watch(...).valueOrNull` — confirmed pattern from STATE.md decision "asData?.value used for AsyncValue null-safe access (riverpod 3.x has no valueOrNull getter)". Verify actual null-safe accessor used in codebase before writing.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `flutter_markdown` (Google) | `flutter_markdown_plus` (Foresight Mobile) | 2025 | Must use `_plus` variant; same API surface |
| `flutter_fancy_tree_view` | `flutter_fancy_tree_view2` | April 2024 (discontinued) → Nov 2025 (fork) | Must use `_2` fork; maintains same API |

**Deprecated/outdated:**
- `flutter_markdown`: discontinued by Google in 2025 — do not add this package
- `flutter_fancy_tree_view`: marked discontinued on pub.dev — do not add this package
- `flutter_highlight` 0.7.0: last published March 2021 — evaluate carefully, may not be needed

---

## Runtime State Inventory

Phase 5 is a greenfield feature addition. No existing runtime state contains culture-feature strings.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no culture tables exist yet in any project.db | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Dart 3.10.4 constraint in pubspec | ✓ | Project running | — |
| dart pub (network) | `flutter pub add` new packages | ✓ | Standard tooling | — |
| `build_runner` | Drift codegen for CulturePages table | ✓ | ^2.4.15 in pubspec | — |

No missing dependencies that block execution.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — using `flutter test` directly |
| Quick run command | `flutter test test/unit/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CULT-01 | CultureDao CRUD (create, read, update, delete pages) | unit | `flutter test test/unit/culture_dao_test.dart -x` | ❌ Wave 0 |
| CULT-01 | Block splitter splits markdown correctly at headings | unit | `flutter test test/unit/culture_block_splitter_test.dart -x` | ❌ Wave 0 |
| CULT-01 | Block splitter round-trips (split → join = original) | unit | same file | ❌ Wave 0 |
| CULT-02 | WikiLinkSyntax.onMatch parses `[[title]]` correctly | unit | `flutter test test/unit/wiki_link_syntax_test.dart -x` | ❌ Wave 0 |
| CULT-02 | WikiLinkResolver returns id for known title, null for unknown | unit | `flutter test test/unit/wiki_link_resolver_test.dart -x` | ❌ Wave 0 |
| CULT-02 | PageHistory back/forward stack behavior | unit | `flutter test test/unit/page_history_test.dart -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/unit/ --name=culture`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/unit/culture_dao_test.dart` — covers CULT-01 DAO CRUD
- [ ] `test/unit/culture_block_splitter_test.dart` — covers CULT-01 block splitting
- [ ] `test/unit/wiki_link_syntax_test.dart` — covers CULT-02 link parsing
- [ ] `test/unit/wiki_link_resolver_test.dart` — covers CULT-02 link resolution
- [ ] `test/unit/page_history_test.dart` — covers CULT-02 history navigation

---

## Security Domain

No security concerns specific to this phase. The culture wiki operates on local SQLite data only — no network, no user authentication, no file uploads, no external content parsing. Input validation is minimal (page title non-empty). No ASVS categories apply.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Drift supports self-referential FK (`references(CulturePages, #id)`) without codegen errors | Architecture Patterns — Pattern 1 | Build fails; workaround is nullable `IntColumn parentId` without explicit `.references()` call (plain integer, no FK enforcement) |
| A2 | `flutter_highlight` (v0.7.0) is compatible with current Flutter 3.x SDK | Standard Stack | Compilation errors on `flutter pub get`; mitigate by using plain monospace TextField instead |
| A3 | `splitIntoBlocks` regex logic correctly handles edge cases (e.g., `#` inside code fences) | Architecture Patterns — Pattern 2 | Code fences with `#` characters incorrectly treated as section boundaries; mitigate by testing with code-fence content |
| A4 | `pageTitleIndexProvider` null-safe accessor should use `ref.watch(...).valueOrNull` pattern | Code Examples | If riverpod 3.x accessor differs, compilation error; verify against existing providers like `lexemeListProvider` in codebase |

---

## Open Questions

1. **Should `CultureShell` use a `StatefulNavigationShell` sub-route for the sidebar (like Grammar/Lexicon) or a plain `StatefulWidget` with a controller?**
   - What we know: Grammar and Lexicon both use `StatefulNavigationShell` with GoRouter sub-routes per sidebar item, which is appropriate for distinct sub-sections.
   - What's unclear: Culture has one page view + a tree that acts as navigation — the "active page" is dynamic, not a fixed set of routes.
   - Recommendation: Use plain `StatefulWidget` with a `ValueNotifier<int?>` for active page id. Route as `/culture` with a query parameter `/culture?pageId=42` for deep-linking. Avoids a StatefulNavigationShell anti-pattern where sidebar items are page-id-specific.

2. **Is `flutter_fancy_tree_view2` drag-and-drop sufficient for reparenting (not just reordering siblings)?**
   - What we know: `TreeDragTarget.onNodeAccepted` provides `TreeDragAndDropDetails` with both dragged node and target node, enabling reparent logic via `treeController.rebuild()`. [VERIFIED: pub.dev docs]
   - What's unclear: Whether the auto-expand-on-hover works correctly for deep nesting when target node has no children yet.
   - Recommendation: Test reparent DnD in isolation during plan 05-01. If insufficient, fall back to simpler "context menu → Move to…" dialog.

---

## Sources

### Primary (HIGH confidence)
- `lib/db/app_database.dart` — Schema v12 migration pattern, table definition conventions [VERIFIED: codebase read]
- `lib/shared/widgets/app_shell.dart` — Culture tab currently `enabled: false` at index 3 [VERIFIED: codebase read]
- `lib/router/app_router.dart:242-250` — Culture branch with `_ComingSoonPage` placeholder [VERIFIED: codebase read]
- `lib/features/grammar/presentation/grammar_shell.dart` — Shell pattern (200px sidebar + content) [VERIFIED: codebase read]
- `pubspec.yaml` — Current dependency versions, Dart SDK `^3.10.4` [VERIFIED: codebase read]
- `.planning/STATE.md` — Established decisions: manual Provider (not codegen) for Drift types, TapRegion groupId overlay pattern, transaction() for reordering [VERIFIED: codebase read]
- pub.dev: `flutter_markdown_plus` v1.0.7 [VERIFIED: pub.dev fetch]
- pub.dev: `flutter_fancy_tree_view2` v1.6.3, November 2025 [VERIFIED: pub.dev fetch]
- pub.dev: `flutter_highlight` v0.7.0, March 2021 — stale [VERIFIED: pub.dev fetch]
- github.com/flutter/flutter/issues/105571 — `InlineSyntax` + `MarkdownElementBuilder` API pattern [VERIFIED: WebFetch]

### Secondary (MEDIUM confidence)
- WebSearch: flutter_markdown Google discontinuation 2025, flutter_markdown_plus as successor [MEDIUM — multiple sources agree]
- WebSearch: flutter_fancy_tree_view marked discontinued, flutter_fancy_tree_view2 as continuation [MEDIUM — pub.dev confirmation]

### Tertiary (LOW confidence)
- Drift self-referential FK support — [LOW — not tested in this codebase, inferred from Drift docs pattern]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages verified on pub.dev, versions confirmed
- Architecture: HIGH — patterns derived directly from existing codebase conventions
- Pitfalls: MEDIUM — overlay/focus pitfalls based on verified codebase history (STATE.md); library stale-version pitfall verified on pub.dev
- Tree DnD: LOW-MEDIUM — library verified but specific reparenting behavior not tested

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable ecosystem; 30-day window)
