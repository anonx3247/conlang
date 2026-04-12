# Phase 5: Culture Wiki - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Markdown wiki for world-building documentation within a conlang project. Users can create, edit, and organize pages in a tree hierarchy with rendered Markdown preview, block-based inline editing, [[wiki-style]] internal linking with navigation, and per-page metadata (timestamps, icon/emoji). All data stored in the project's existing SQLite database.

</domain>

<decisions>
## Implementation Decisions

### Page organization
- **D-01:** Pages organized in a parent-child tree hierarchy (not flat list or tags)
- **D-02:** Sidebar tree expands the first 2 levels of depth by default; deeper nodes start collapsed
- **D-03:** Drag-and-drop for reordering siblings and reparenting pages in the tree
- **D-04:** Page CRUD interaction pattern — Claude's discretion (context menu, toolbar buttons, or hybrid)

### Editor experience
- **D-05:** Block-based editing: pages render as Markdown by default. Click a heading section to edit its raw Markdown inline (Wikipedia/Jupyter-style section editing)
- **D-06:** Blocks are heading-based sections — each heading (`##`, `###`, etc.) defines an editable block; content between headings is one editable unit
- **D-07:** No formatting toolbar — raw Markdown typing only
- **D-08:** Syntax highlighting in the Markdown editor when a block is in edit mode

### Internal linking
- **D-09:** `[[wiki-links]]` with autocomplete popup — typing `[[` opens a dropdown of existing page titles
- **D-10:** Broken links (linking to non-existent pages) display a `?` icon next to the link text (Wikipedia missing-citation style)
- **D-11:** Clicking a broken link shows a "Create this page?" confirmation prompt, then creates the page if confirmed
- **D-12:** No backlinks section on pages
- **D-13:** Browser-style back/forward navigation arrows at the top of the page for page history traversal

### Page metadata
- **D-14:** Auto-tracked created and last-modified timestamps per page
- **D-15:** Optional icon or emoji per page, displayed in the tree and page header
- **D-16:** Hovering over an internal link shows a preview tooltip with the first portion of the linked page's content (below the title)

### Claude's Discretion
- Page CRUD interaction pattern (D-04)
- Empty state design for a wiki with no pages
- Exact drag-and-drop library/implementation approach
- Markdown rendering library choice (flutter_markdown or alternatives)
- Syntax highlighting library for the editor blocks
- Preview tooltip sizing and content truncation
- How new blocks/sections are added (button placement, interaction)
- Navigation arrow placement and styling

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above.

### Requirements
- `.planning/REQUIREMENTS.md` — CULT-01 (wiki-style Markdown pages), CULT-02 (internal links)

### Existing integration points
- `lib/router/app_router.dart:242-250` — Culture branch placeholder (replace `_ComingSoonPage`)
- `lib/shared/widgets/app_shell.dart:30` — Culture tab definition (enable it, currently `enabled: false`)
- `lib/db/app_database.dart` — Schema v12, new culture tables needed (v13 migration)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AppShell tab bar** (`lib/shared/widgets/app_shell.dart`): Culture tab already defined at index 3, just needs `enabled: true`
- **GoRouter branch** (`lib/router/app_router.dart`): Culture branch exists as placeholder, needs real routes
- **Drift database** (`lib/db/app_database.dart`): Schema v12, well-established migration pattern for adding tables
- **Riverpod providers**: All features use StreamProvider/Provider patterns for data layer

### Established Patterns
- Feature modules live in `lib/features/{name}/` with `data/`, `domain/`, `presentation/` subdirectories
- DAOs extend `DatabaseAccessor<AppDatabase>` with Drift code generation
- Providers use manual `Provider`/`StreamProvider` (not `@riverpod` codegen) for Drift types
- Dark theme with `colorScheme.surface`/`surfaceContainer` palette

### Integration Points
- New `lib/features/culture/` feature module following existing conventions
- New Drift tables (CulturePages) with v12→v13 schema migration
- Router: replace `_ComingSoonPage` with real culture page routes + sidebar sub-navigation
- AppShell: flip `enabled: false` → `true` on Culture tab

</code_context>

<specifics>
## Specific Ideas

- **Wikipedia-style section editing**: The user specifically referenced Wikipedia and Jupyter notebook UI. The key UX is that content is rendered/readable by default, and you click into a section to edit — not a permanent split pane or separate edit mode
- **Missing-link indicator**: User referenced Wikipedia's missing-citation UI style — a small `?` icon next to broken links, visually distinct but not aggressive (not red, just an indicator)
- **Link hover preview**: When hovering over an internal link, show a tooltip/popup with the first portion of the target page's content — gives context without navigating away
- **Navigation history**: Back/forward arrows like a web browser — maintain a page visit stack for the wiki, not just relying on the sidebar tree

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-culture-wiki*
*Context gathered: 2026-04-12*
