# Phase 11: Lexicon Etymology Chain - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a visual multi-level etymology chain for any word in the lexicon. When a user opens a word's detail panel, they see a navigable ancestry tree tracing the full derivational history upward (root → derived → current word), plus the word's immediate children one level down. Replaces the existing flat "Parents" section with a full lineage tree component.

Also includes two related bug fixes and one UX improvement to the parent management UI.

</domain>

<decisions>
## Implementation Decisions

### Visual Tree Layout
- Render ancestry as an indented tree with connector lines (like a file explorer / tree view)
- Each node shows: word form (romanization or IPA) on one line, meaning below it — same layout as the dictionary list, not inline parentheses
- Multi-parent nodes (compounds) show each parent as its own branch with its own sub-tree above it — full DAG expansion
- Current word appears as the highlighted leaf at the bottom so ancestry direction is clear
- Immediate children (direct derived words and manual-parent children) shown one level below the current word — no recursive descent downward

### UI Placement
- Replace the existing `WordDetailParentsSection` ("Parents" section) with a new "Etymology Chain" section
- Expanded by default for words that have parents or children
- Section hidden entirely for root words with no parents and no children (consistent with current behavior)
- Max 10 levels of upward traversal; if exceeded, show "↑ N more ancestors" truncation link

### Parent Selection UI (Bug/UX Fix)
- Currently all existing words are shown as pills for parent selection — this doesn't scale
- Replace with a searchable dropdown: user types to filter, selects words, each selected word appears as a removable pill with a × button
- Clicking a pill removes the parent link

### Data Scope
- Traverse both `Lexeme.derivedFromLexemeId` (rule-derived) AND `LexemeParents` junction table (manual/compound links)
- Ancestry chain only — recursive upward traversal
- Children: immediate next generation only (both rule-derived children and manual-parent children of current word), shown as expandable list below the current word node
- Edge labels: show "via [rule name]" for rule-derived links, custom relationship label or "parent" for manual links
- Cycle detection: track visited IDs during traversal, show "⚠ cycle" marker if a word appears in its own ancestor chain

### Claude's Discretion
- Exact visual styling (connector line colors, indentation amounts, node chip dimensions) — follow existing app theme
- Whether to use a custom painter or nested Column/Row widgets for the tree structure
- Provider architecture for the ancestry chain computation

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WordDetailParentsSection` (word_detail_panel.dart:1203) — existing parents display, to be replaced by etymology chain
- `LexemeParentsDao.watchParentsForChild(id)` and `watchChildrenForParent(id)` — reactive streams for manual parent links
- `allLexemeListProvider` — full lexeme list already loaded in memory, use for O(1) lookup during tree traversal
- `parentsForLexemeProvider(id)` — existing provider for manual parents
- `onNavigateToWord` callback already wired in `WordDetailPanel` — reuse for node tap navigation
- `romanizeProvider` — for displaying romanized forms

### Established Patterns
- Detail panel sections use `Column` + `Padding` with `Text` headers (`bodyMedium`, fontWeight w600, fontSize 13)
- `ActionChip` used for parent pills — reuse chip visual for tree nodes or adapt
- `StreamProvider` / `ref.watch` for reactive data — follow Riverpod patterns throughout
- `ConsumerWidget` for all display widgets that read providers

### Integration Points
- `WordDetailPanel._WordDetailPanelState` (word_detail_panel.dart) — replace `WordDetailParentsSection` call at line 675 with new `EtymologyChainSection`
- `LexemeParentsDao` in `lib/features/grammar/data/lexeme_parents_dao.dart` — no changes needed, use existing queries
- `LexemeDao` in `lib/features/lexicon/data/lexeme_dao.dart` — no changes needed

</code_context>

<specifics>
## Specific Ideas

- Node layout: word form (romanization or IPA) in bold on first line, meaning in a smaller/muted font on second line — mirrors the dictionary list row layout (not parentheses)
- Immediate children shown below current word with a downward arrow/branch, but NOT recursively — only generation N+1
- "↑ N more ancestors" truncation at 10 levels — clicking could scroll to a "Show full chain" view

### Bug Fixes Required (part of this phase)

**Bug 1 — Multi-level derivation chain applies wrong base:**
When word C derives from B (via rule R2), and B derives from root A (via rule R1), the system is currently applying rule R2 directly onto A's IPA instead of computing A→B first and then B→C. Fix: derivation must be sequential — apply R1(A) = B, then R2(B) = C. The computed form for B must be used as the input to R2, not A's raw IPA.

**Bug 2 — Parent display shows root word instead of derived word:**
When displaying parent words and their meanings in the detail panel, it sometimes shows the root word (A) instead of the actual derived parent (B). Likely related to Bug 1 — the lookup resolves `derivedFromLexemeId` but then computes/displays the wrong form.

**UX Fix — Parent selection UI:**
The current "add parent" UI shows all existing words as pills at once, which will not scale. Replace with a searchable dropdown: user types to filter lexemes, selects one, it appears as a removable pill. Clicking a pill removes the parent link.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
