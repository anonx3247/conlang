---
phase: 05-culture-wiki
plan: "02"
subsystem: culture-presentation
tags: [flutter, ui, culture-wiki, tree-sidebar, drag-and-drop, navigation]
dependency_graph:
  requires: ["05-01"]
  provides: ["culture-shell-ui", "page-tree-sidebar", "back-forward-nav", "culture-page-view"]
  affects: ["app-shell", "app-router"]
tech_stack:
  added: ["flutter_fancy_tree_view2 ^1.6.3"]
  patterns:
    - "ConsumerStatefulWidget for shell with PageHistory lifecycle"
    - "ListenableBuilder on PageHistory ChangeNotifier for back/forward bar"
    - "TreeController<CulturePageNode> with expandAll + collapseDeep for 2-level default expansion"
    - "TreeDraggable + TreeDragTarget for reparent-on-drop via cultureDao.reparentPage"
    - "In-memory CulturePageNode tree model built from flat Drift DB rows"
key_files:
  created:
    - lib/features/culture/presentation/culture_shell.dart
    - lib/features/culture/presentation/back_forward_bar.dart
    - lib/features/culture/presentation/culture_page_view.dart
    - lib/features/culture/presentation/page_tree_sidebar.dart
  modified:
    - lib/shared/widgets/app_shell.dart
    - lib/router/app_router.dart
    - pubspec.yaml
decisions:
  - "CultureShell uses plain ConsumerStatefulWidget (not StatefulNavigationShell) — culture sidebar tree IS the navigation, not a fixed sub-route set"
  - "PageHistory owned by CultureShell state, passed down to BackForwardBar as ChangeNotifier — no Riverpod provider needed for ephemeral session state"
  - "CulturePageNode.parent is final, requiring _CulturePageNodeWithParent subclass to wire parent links during tree build from flat list"
  - "_ComingSoonPage removed from app_router.dart — no longer referenced after Culture tab activated"
  - "context async-gap linter warnings resolved by renaming parameter to ctx and using this.context (State's own context) after await"
metrics:
  duration: "~25 min"
  completed: "2026-04-12"
  tasks: 2
  files: 7
---

# Phase 5 Plan 02: Culture Wiki Shell UI Summary

Culture wiki shell UI with tree sidebar, drag-and-drop page organization, CRUD context menu, back/forward navigation, and empty state — built on flutter_fancy_tree_view2 with in-memory CulturePageNode tree model derived from flat Drift rows.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Enable Culture tab, wire router, CultureShell + BackForwardBar + CulturePageView | 378300a | app_shell.dart, app_router.dart, culture_shell.dart, back_forward_bar.dart, culture_page_view.dart, pubspec.yaml |
| 2 | Tree sidebar with expand/collapse, drag-and-drop, context menu CRUD | 66452c1 | page_tree_sidebar.dart |

## What Was Built

### CultureShell (`culture_shell.dart`)
- `ConsumerStatefulWidget` with `PageHistory` lifecycle (initState/dispose)
- Layout: 240px `SizedBox` sidebar + `VerticalDivider` + `Expanded` content area
- Sidebar: `Material(surfaceContainerLow)`, "CULTURE" section header, `PageTreeSidebar`, "New page" TextButton.icon at bottom
- Content area: `BackForwardBar` (top 36px) + `CulturePageView` or `_EmptyState`
- Empty state: `Icons.auto_stories_outlined` (72px alpha 0.15), "No pages yet" heading, descriptive body, "New page" CTA

### BackForwardBar (`back_forward_bar.dart`)
- `ListenableBuilder` wrapping the bar so it rebuilds on `PageHistory` change notifications
- Back/forward `IconButton` widgets with `Opacity(0.3)` for disabled state, `colorScheme.primary` for active
- 36px height, `surfaceContainer` background, bottom `outlineVariant` divider
- Tooltips: "Back" / "Forward"

### CulturePageView (`culture_page_view.dart`)
- `ConsumerStatefulWidget` watching `culturePageProvider(pageId)`
- Page header: optional emoji (18px), title (20px weight 600), timestamps at 12px alpha 0.4
- Inline title rename via pencil `IconButton` toggling a `TextField`
- Content: `SingleChildScrollView` with 24px horizontal / 16px vertical padding, raw Markdown as plain `Text` (Plan 03 will replace with block editor)

### PageTreeSidebar (`page_tree_sidebar.dart`)
- `CulturePageNode` in-memory tree model (page + children + parent links)
- `_buildTree()` builds from flat `List<CulturePage>`, sorts siblings by ordering
- `TreeController<CulturePageNode>` with `expandAll()` + `_collapseDeep()` for first-2-levels default expansion
- `AnimatedTreeView` with `TreeDraggable`/`TreeDragTarget` per node
- Drag-and-drop: `onNodeAccepted` calls `cultureDao.reparentPage(draggedId, targetId, maxOrder+1)`
- Right-click (`GestureDetector.onSecondaryTapDown`) + hover `...` overflow button both invoke `showMenu()` context menu
- Context menu items: Rename (AlertDialog), Set icon (AlertDialog), Add child page, Delete page (AlertDialog with error-color confirm)
- Node tile: 32px height, selected = `primaryContainer` bg + 2px `primary` left border, hover = `surfaceContainer` bg + drag handle visible

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Missing dependency] `intl` package not in pubspec**
- **Found during:** Task 1 (CulturePageView used `DateFormat`)
- **Issue:** `intl` not in pubspec.yaml; adding it would require pub resolution
- **Fix:** Replaced `DateFormat` with a simple inline `_formatDate()` helper (`padLeft` formatting) — no new dependency needed
- **Files modified:** `culture_page_view.dart`
- **Commit:** 378300a

**2. [Rule 2 - Correctness] Unused `_ComingSoonPage` class warning**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `_ComingSoonPage` was left in `app_router.dart` after the Culture branch was replaced; caused `unused_element` warning
- **Fix:** Removed the class entirely (no other routes reference it)
- **Files modified:** `lib/router/app_router.dart`
- **Commit:** 378300a

**3. [Rule 1 - Bug] `BuildContext` across async gap linter violations**
- **Found during:** Task 2 (flutter analyze on page_tree_sidebar.dart)
- **Issue:** `showMenu().then()` pattern passed `context` parameter across async gap, triggering `use_build_context_synchronously` warnings
- **Fix:** Renamed parameter to `ctx`, awaited `showMenu`, checked `mounted`, then used `this.context` (State's own context) for post-await dialog calls — linter-safe pattern
- **Files modified:** `lib/features/culture/presentation/page_tree_sidebar.dart`
- **Commit:** 66452c1

## Known Stubs

- `CulturePageView` renders page content as raw `Text` (plain Markdown string) — Plan 03 will replace with `flutter_markdown_plus` rendered blocks + block editor. This is intentional per plan spec ("For now (Plan 02), render content as plain Text").

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. All data flows are local SQLite reads/writes through existing `CultureDao`.

## Self-Check

Files created:
- lib/features/culture/presentation/culture_shell.dart ✓
- lib/features/culture/presentation/back_forward_bar.dart ✓
- lib/features/culture/presentation/culture_page_view.dart ✓
- lib/features/culture/presentation/page_tree_sidebar.dart ✓

Files modified:
- lib/shared/widgets/app_shell.dart ✓
- lib/router/app_router.dart ✓
- pubspec.yaml ✓

Commits:
- 378300a ✓
- 66452c1 ✓

## Self-Check: PASSED
