---
phase: 05-culture-wiki
plan: "03"
subsystem: culture-presentation
tags: [flutter, ui, culture-wiki, block-editor, wiki-links, markdown, autocomplete]
dependency_graph:
  requires: ["05-02"]
  provides: ["block-editor", "wiki-link-syntax", "link-autocomplete", "hover-preview"]
  affects: ["culture-page-view"]
tech_stack:
  added: ["flutter_markdown_plus ^1.0.7", "markdown ^7.0.0"]
  patterns:
    - "ConsumerStatefulWidget BlockEditor splitting content via splitIntoBlocks()"
    - "MarkdownBody with custom WikiLinkSyntax InlineSyntax + WikiLinkBuilder MarkdownElementBuilder"
    - "TapRegion groupId + 100ms delay for overlay focus management (IPA keyboard pattern)"
    - "CompositedTransformTarget/Follower + OverlayEntry for autocomplete positioning"
    - "Timer-based 400ms hover delay for preview tooltip"
    - "visitElementAfterWithContext() for wiki-link rendering (visitElementAfter deprecated)"
key_files:
  created:
    - lib/features/culture/presentation/block_editor.dart
    - lib/features/culture/presentation/wiki_link_syntax.dart
    - lib/features/culture/presentation/link_autocomplete.dart
  modified:
    - lib/features/culture/presentation/culture_page_view.dart
    - pubspec.yaml
decisions:
  - "WikiLinkBuilder uses visitElementAfterWithContext() not visitElementAfter() — the latter is @Deprecated in flutter_markdown_plus 1.0.7"
  - "LinkAutocompleteState is public (not private) so block_editor.dart can hold GlobalKey<LinkAutocompleteState> for key event forwarding"
  - "markdown package added explicitly as direct dependency alongside flutter_markdown_plus (depend_on_referenced_packages lint)"
  - "Hover preview Timer moved inside WikiLinkBuilder (400ms delay per D-16) with cancel on onExit"
metrics:
  duration: "~20 min"
  completed: "2026-04-12"
  tasks: 2
  files: 5
status: checkpoint-reached
checkpoint_task: 3
---

# Phase 5 Plan 03: Block Editor and Wiki-Link Syntax Summary

Block-based Markdown editor with rendered preview, [[wiki-link]] inline syntax with autocomplete, broken link handling, and hover preview tooltips — implementing the core wiki editing experience for the Culture feature.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Block editor with Markdown rendering and inline section editing | cd98f05 | block_editor.dart, culture_page_view.dart, pubspec.yaml |
| 2 | Wiki-link syntax, broken-link handling, autocomplete, hover preview | cd98f05 | wiki_link_syntax.dart, link_autocomplete.dart, block_editor.dart |

## Checkpoint Reached

**Task 3:** Human verification of complete Culture Wiki feature  
**Status:** Awaiting human verification

## What Was Built

**BlockEditor** (`block_editor.dart`):
- Splits page content into heading-delimited blocks via `splitIntoBlocks()`
- Read mode: `MarkdownBody` with `WikiLinkSyntax` + `WikiLinkBuilder` passed to `inlineSyntaxes`/`builders`
- Edit mode: `TextField` (monospace 13px, multiline) with primary-color focus border
- Escape key or focus-loss saves block and exits edit mode
- TapRegion groupId + 100ms delay prevents autocomplete interaction from triggering premature save
- 3-second fade-out hint "Click any section to edit"
- Pencil icon on hover for intro block (block 0)
- Hover preview overlay via `_HoverPreviewOverlay` ConsumerWidget watching `culturePageProvider`

**WikiLinkSyntax + WikiLinkBuilder** (`wiki_link_syntax.dart`):
- `WikiLinkSyntax` extends `md.InlineSyntax` with regex `\[\[([^\]]+)\]\]`
- `WikiLinkBuilder` renders resolved links in `colorScheme.primary` with underline
- Broken links show 16px circular `colorScheme.error` badge with "?" text (D-10)
- Hover fires `onHoverStart` after 400ms Timer (D-16), clears on exit

**LinkAutocomplete** (`link_autocomplete.dart`):
- Monitors `TextEditingController` for `[[` trigger before cursor
- Filters page titles case-insensitively, shows up to 10 matches
- `CompositedTransformFollower` + `OverlayEntry` popup below TextField
- Arrow key navigation, Enter/Tab selects, Escape closes without selecting
- `TapRegion` with shared `groupId` prevents block editor focus-loss on overlay interaction
- Public `LinkAutocompleteState` class exposes `handleKeyEvent()` for block editor key forwarding
- On selection: replaces `[[partial` with `[[title]]` at cursor position

**CulturePageView** (`culture_page_view.dart`):
- Replaces `Text(page.content)` with `BlockEditor` wired to `pageTitleIndexProvider`
- `onContentChanged` saves via `db.cultureDao.updatePage()`
- `_handleLinkTap`: navigates to existing page or shows "Page not found / Create?" dialog (D-11)
- Creates page via `db.cultureDao.createPage()` and navigates on confirm

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] visitElementAfter deprecated in flutter_markdown_plus 1.0.7**
- **Found during:** Task 2
- **Issue:** Plan specified overriding `visitElementAfter()` but this method is `@Deprecated` — the active API is `visitElementAfterWithContext(BuildContext, md.Element, TextStyle?, TextStyle?)`
- **Fix:** Implemented `visitElementAfterWithContext()` instead, giving direct `BuildContext` access (eliminates need for `Builder` wrapper widgets for `Theme.of(context)`)
- **Files modified:** `wiki_link_syntax.dart`
- **Commit:** cd98f05

**2. [Rule 2 - Missing dep] markdown added as explicit direct dependency**
- **Found during:** Task 1 flutter analyze
- **Issue:** `depend_on_referenced_packages` lint: importing `package:markdown/markdown.dart` without declaring it directly in pubspec.yaml
- **Fix:** Added `markdown: ^7.0.0` to pubspec.yaml dependencies
- **Files modified:** `pubspec.yaml`
- **Commit:** cd98f05

**3. [Rule 3 - Blocking] Private _LinkAutompleteState unusable as GlobalKey type argument**
- **Found during:** Task 2 flutter analyze
- **Issue:** `block_editor.dart` needs `GlobalKey<_LinkAutompleteState>` to forward key events, but private state class can't be used as type argument across files
- **Fix:** Renamed `_LinkAutompleteState` to public `LinkAutocompleteState` and added doc comment
- **Files modified:** `link_autocomplete.dart`, `block_editor.dart`
- **Commit:** cd98f05

## Self-Check

### Created files exist:
- `lib/features/culture/presentation/block_editor.dart` — FOUND
- `lib/features/culture/presentation/wiki_link_syntax.dart` — FOUND
- `lib/features/culture/presentation/link_autocomplete.dart` — FOUND

### Modified files exist:
- `lib/features/culture/presentation/culture_page_view.dart` — FOUND
- `pubspec.yaml` — FOUND

### Commits exist:
- `cd98f05` feat(05-03): block editor — FOUND

## Self-Check: PASSED
