# Phase 5: Culture Wiki - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 05-culture-wiki
**Areas discussed:** Page organization, Editor experience, Internal linking, Page metadata

---

## Page Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Tree hierarchy | Pages nested in parent-child tree, like folder structure | ✓ |
| Flat + tags | All pages at one level, organized by user-defined tags | |
| Hybrid (tree + tags) | Tree hierarchy for structure, optional tags for cross-cutting themes | |

**User's choice:** Tree hierarchy
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed by default | Only top-level sections visible initially | |
| Expanded by default | Full tree visible at a glance | |
| Custom | User-defined behavior | ✓ |

**User's choice:** Expanded for first 2 levels of depth, deeper nodes collapsed
**Notes:** User specified custom depth threshold

| Option | Description | Selected |
|--------|-------------|----------|
| Context menu on tree | Right-click to add child, rename, delete, move | |
| Toolbar buttons | Dedicated buttons above the tree | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide (Claude's discretion)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Drag-and-drop | Drag pages to reorder siblings or reparent | ✓ |
| Move via dialog | Right-click > Move to... parent picker | |
| You decide | Claude picks | |

**User's choice:** Drag-and-drop
**Notes:** None

---

## Editor Experience

**User's choice:** Block-based editing (custom — user described before options were presented)
**Notes:** User referenced Wikipedia and Jupyter notebook UI. Pages render as Markdown by default. Click a heading section to edit its raw Markdown inline. Can add new blocks anywhere.

| Option | Description | Selected |
|--------|-------------|----------|
| Heading-based sections | Each heading creates a block, content between headings is one editable unit | ✓ |
| Freeform cells | User adds/removes blocks freely like Jupyter cells | |
| You decide | Claude picks | |

**User's choice:** Heading-based sections
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal toolbar | Small floating toolbar with common formatting buttons | |
| No toolbar | Raw Markdown typing only | ✓ |
| You decide | Claude picks | |

**User's choice:** No toolbar
**Notes:** User also requested syntax highlighting in the Markdown editor blocks

---

## Internal Linking

| Option | Description | Selected |
|--------|-------------|----------|
| Autocomplete popup | Typing [[ opens dropdown of existing page titles | ✓ |
| Plain text only | User types [[Page Name]] manually | |
| You decide | Claude picks | |

**User's choice:** Autocomplete popup
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Create page on click | Clicking broken link immediately creates new page | |
| Show error tooltip | Broken links visually distinct, tooltip says page doesn't exist | |
| Prompt to create | Clicking broken link asks "Create this page?" | ✓ |

**User's choice:** Prompt to create + question mark icon indicator
**Notes:** User wants a `?` icon next to broken links (like Wikipedia's missing citation UI), plus a confirmation prompt when clicking

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, backlinks at bottom | Auto-generated "Pages that link here" section | |
| No backlinks | Forward links only | ✓ |

**User's choice:** No backlinks, but back/forward navigation arrows
**Notes:** User wants browser-style back/forward arrows at the top for page history traversal instead of backlinks

---

## Page Metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Created/modified timestamps | Auto-tracked dates | ✓ |
| Icon or emoji | Optional per-page icon in tree and header | ✓ |
| Summary/excerpt | Short description for hover/search | |
| None — just title + body | Minimal pages | |

**User's choice:** Timestamps + Icon/emoji (multi-select)
**Notes:** No summary field, but user wants link hover to show a preview of the first portion of the linked page's content

---

## Claude's Discretion

- Page CRUD interaction pattern (context menu, toolbar, or hybrid)
- Empty state design
- Drag-and-drop implementation approach
- Markdown rendering and syntax highlighting libraries
- Preview tooltip sizing and truncation
- New section/block creation UX
- Navigation arrow placement

## Deferred Ideas

None — discussion stayed within phase scope
