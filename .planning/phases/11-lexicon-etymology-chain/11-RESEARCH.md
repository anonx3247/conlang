# Phase 11: Lexicon Etymology Chain - Research

**Researched:** 2026-04-14
**Domain:** Flutter widget tree rendering, Riverpod provider composition, DAG ancestry traversal
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Render ancestry as an indented tree with connector lines (like a file explorer / tree view)
- Each node shows: word form (romanization or IPA) on one line, meaning below it — same layout as the dictionary list, not inline parentheses
- Multi-parent nodes (compounds) show each parent as its own branch with its own sub-tree above it — full DAG expansion
- Current word appears as the highlighted leaf at the bottom so ancestry direction is clear
- Immediate children (direct derived words and manual-parent children) shown one level below the current word — no recursive descent downward
- Replace the existing `WordDetailParentsSection` ("Parents" section) with a new "Etymology Chain" section
- Expanded by default for words that have parents or children
- Section hidden entirely for root words with no parents and no children
- Max 10 levels of upward traversal; if exceeded, show "↑ N more ancestors" truncation link
- Replace parent selection UI with a searchable dropdown: user types to filter, selects words, each selected word appears as a removable pill with × button
- Traverse both `Lexeme.derivedFromLexemeId` AND `LexemeParents` junction table
- Ancestry chain only — recursive upward traversal
- Children: immediate next generation only (both rule-derived children and manual-parent children of current word)
- Edge labels: "via [rule name]" for rule-derived, custom label or "parent" for manual
- Cycle detection: track visited IDs, show "⚠ cycle" marker if word appears in its own ancestor chain

### Claude's Discretion
- Exact visual styling (connector line colors, indentation amounts, node chip dimensions) — follow existing app theme
- Whether to use a custom painter or nested Column/Row widgets for the tree structure
- Provider architecture for the ancestry chain computation

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LEX-09 | User can view the full etymology chain (root → derived → compound) as a visual lineage display in the lexicon | EtymologyChainSection widget with upward DAG traversal; node tap calls `onNavigateToWord`; UI-SPEC fully defines the visual contract |
</phase_requirements>

---

## Summary

Phase 11 is a contained Flutter UI phase within an existing, mature codebase. All data infrastructure is already in place: `LexemeParentsDao` (manual links), `childrenForLexemeProvider` (children stream), `parentsForLexemeProvider` (manual parents stream), and `allLexemeListProvider` (O(1) in-memory lookup). The phase has three distinct work streams: (1) the new `EtymologyChainSection` widget with upward DAG traversal, (2) the `SearchableParentSelector` replacing the filter-chip wall, and (3) a bug fix to `promotedDerivedFormProvider` for multi-level sequential derivation.

The tree widget layout is settled as nested `Column`/`Row` with manual connector-line containers — identical to the existing `_TreeNode`/`_DerivedRow` pattern in `derivation_tree_widget.dart`. No custom `CustomPainter` is needed. The DAG traversal runs entirely in-memory against `allLexemeListProvider` data already loaded by the lexicon tab.

**Primary recommendation:** Build a single `ancestryChainProvider(lexemeId)` that returns a pre-computed `AncestryNode` tree model (immutable data class), then render it with a pure-widget `EtymologyChainSection`. Fix the sequential derivation bug in `promotedDerivedFormProvider` first — it affects correct display of promoted-derivation nodes in the tree.

---

## Standard Stack

### Core (already in pubspec.yaml — no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.0.3 | Reactive state, provider composition | [VERIFIED: pubspec.yaml] — established project convention |
| drift | ^2.30.0 | SQLite DAO layer | [VERIFIED: pubspec.yaml] — existing DAOs used directly |
| Flutter Material 3 | 3.38.5 | `ActionChip`, `Autocomplete`, `Column`/`Row` | [VERIFIED: flutter --version] |

**No new packages required.** The UI-SPEC explicitly states this: "No new packages required for this phase. Implementation uses existing Flutter Material 3 primitives." [VERIFIED: 11-UI-SPEC.md]

### Supporting Providers (already exist)

| Provider | File | Purpose |
|----------|------|---------|
| `allLexemeListProvider` | `lexeme_providers.dart` | Full in-memory lexeme list for O(1) lookup |
| `parentsForLexemeProvider(id)` | `grammar_providers.dart:127` | Reactive stream of `LexemeParentRow` for manual parents |
| `childrenForLexemeProvider(id)` | `grammar_providers.dart:136` | Reactive stream of children (manual links direction) |
| `promotedDerivedFormProvider(id)` | `lexeme_providers.dart:387` | Computes derived IPA/rom for a promoted lexeme row |
| `morphologicalRuleListProvider` | `morphology_providers.dart` | Rule lookup for edge labels |
| `romanizeProvider` | `romanization_providers.dart` | Display form conversion |
| `lexemeByIdProvider(id)` | `lexeme_providers.dart:233` | Single lexeme watch by id |

---

## Architecture Patterns

### Recommended Project Structure

```
lib/features/lexicon/presentation/dictionary/
├── word_detail_panel.dart         # existing — replace WordDetailParentsSection call at line 675
├── derivation_tree_widget.dart    # existing — unchanged
├── etymology_chain_section.dart   # NEW: EtymologyChainSection + NodeChip
├── searchable_parent_selector.dart # NEW: SearchableParentSelector + pill management
└── word_creation_form.dart        # existing — replace FilterChip wall with SearchableParentSelector
```

No new directories needed. Both new files belong alongside existing dictionary widgets.

### Pattern 1: In-Memory DAG Traversal Model

**What:** A pure-Dart data class `AncestryNode` representing a tree node, built by a `Provider.family` that traverses `allLexemeListProvider` data in-memory.

**When to use:** When the source data (all lexemes) is already loaded and reactive, and the traversal cost is O(N) per rebuild where N is lexeme count — acceptable for <10k words.

**AncestryNode data model:**
```dart
// Source: design derived from CONTEXT.md + codebase analysis [ASSUMED pattern]
class AncestryNode {
  const AncestryNode({
    required this.lexeme,
    required this.edgeLabel,   // "via Rule Name" or "parent" or custom label
    required this.isRuleDerived,
    required this.parents,     // List<AncestryNode> — empty for root
    this.isCycle = false,
  });

  final Lexeme lexeme;
  final String edgeLabel;
  final bool isRuleDerived;
  final List<AncestryNode> parents;  // each parent has its own sub-tree
  final bool isCycle;
}
```

**Provider pattern:**
```dart
// Source: follows established pattern from lexeme_providers.dart computedDerivedFormsProvider
final ancestryChainProvider = Provider.family<AncestryNode?, int>((ref, lexemeId) {
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value;
  if (allLexemes == null) return null;
  final lexemeById = {for (final lx in allLexemes) lx.id: lx};

  final manualParentRows = ref.watch(parentsForLexemeProvider(lexemeId)).asData?.value ?? const [];
  final rules = ref.watch(morphologicalRuleListProvider).asData?.value ?? const [];

  return _buildAncestryNode(
    lexemeId: lexemeId,
    lexemeById: lexemeById,
    manualParentRowsByChild: _indexManualParents(allManualRows),  // see pitfall note
    rules: rules,
    visited: {},
    depth: 0,
  );
});
```

**IMPORTANT — reactive dependency on ALL manual parent links:** The provider above only watches `parentsForLexemeProvider(lexemeId)` for the root node. But ancestor nodes also have parents. The traversal needs to look up manual parents for each ancestor lexeme too. Two approaches:

- **Option A (recommended):** Watch `allLexemeListProvider` and the Drift query for *all* `LexemeParentRow`s across all lexemes — add a `watchAllParentLinks()` method to `LexemeParentsDao`, backed by `select(lexemeParents).watch()`. This emits whenever any link changes. Provider depends on this single stream, then indexes by `childLexemeId` for O(1) lookup during traversal.

- **Option B:** Watch `parentsForLexemeProvider(id)` for only the current word's direct parents, and lazily fetch deeper levels. Simpler but won't react to ancestor link changes in real time.

**Recommendation:** Option A is cleaner and the stream is small (lexicon parents table is sparse). Requires adding one method to `LexemeParentsDao`.

### Pattern 2: Nested Column/Row Tree Rendering

**What:** Render the `AncestryNode` tree as nested `Column` + `Padding` with horizontal container "branch lines" — identical to the existing `_DerivedRow` connector-line pattern.

**When to use:** Always preferred for Flutter desktop tree views with ≤50 nodes. Custom painter adds no benefit and is harder to maintain.

```dart
// Source: mirrors _DerivedRow connector in derivation_tree_widget.dart:424-430
Widget _buildAncestryRow(AncestryNode node, int level) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Render this node's parents recursively first (ancestry = upward)
      for (final parent in node.parents)
        _buildAncestryRow(parent, level + 1),

      // Then render this node
      Padding(
        padding: EdgeInsets.only(left: level * 20.0),  // 20px per UI-SPEC
        child: Row(
          children: [
            if (level > 0)
              Container(
                width: 12, height: 1,
                color: cs.outlineVariant,
                margin: const EdgeInsets.only(right: 4),
              ),
            NodeChip(node: node, onNavigateToWord: onNavigateToWord),
          ],
        ),
      ),
    ],
  );
}
```

### Pattern 3: Cycle Detection via Visited Set

**What:** Pass a `Set<int>` of visited lexeme IDs through the recursive traversal. If the next parent's ID is already in the set, return a cycle node instead of recursing.

```dart
// Source: CONTEXT.md decision; standard DAG cycle detection algorithm [ASSUMED]
AncestryNode? _buildAncestryNode({
  required int lexemeId,
  required Map<int, Lexeme> lexemeById,
  required Map<int, List<LexemeParentRow>> manualParentsByChild,
  required List<MorphologicalRuleData> rules,
  required Set<int> visited,
  required int depth,
}) {
  if (!lexemeById.containsKey(lexemeId)) return null;
  if (depth >= 10) return AncestryNode(/* truncation sentinel */);
  if (visited.contains(lexemeId)) {
    return AncestryNode(lexeme: lexemeById[lexemeId]!, isCycle: true, ...);
  }

  final newVisited = {...visited, lexemeId};  // immutable copy per branch for DAG
  // ... collect parents from both derivedFromLexemeId and manualParentsByChild
}
```

**CRITICAL NOTE on visited set for DAG (not just tree):** For a DAG (word has multiple parents), pass a *copy* of the visited set per branch, not the same set. If a word appears as a parent via two different paths, it should only show "⚠ cycle" when it appears in its *own* direct ancestry chain, not simply because it appeared in a sibling branch.

### Anti-Patterns to Avoid

- **Using StreamProvider for ancestry chain:** The ancestry chain provider depends on `allLexemeListProvider` (already a StreamProvider). Wrapping the chain computation itself in a StreamProvider would force double-stream nesting and rebuild complexity. Use `Provider.family` that watches the upstream `StreamProvider` via `.asData?.value` — same pattern as `computedDerivedFormsProvider`.
- **Fetching parent rows per-node inside the recursive function:** Calling `ref.watch(parentsForLexemeProvider(id))` inside a loop creates O(depth * parents) provider instances per render. Instead, pre-fetch all parent links once in the top-level provider.
- **Using `allLexemes.where(...).toList()` per traversal step:** Pre-index lexemes into `Map<int, Lexeme>` before recursion — already the established pattern in `WordDetailParentsSection` (line 1233).
- **Sharing the visited Set across DAG branches:** Must use per-branch copies (`{...visited, id}`) to avoid marking a word as a cycle just because it was visited via a different parent branch. A diamond-shaped DAG (A → B, A → C, B → D, C → D) would incorrectly mark D as a cycle if the set is shared.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Searchable autocomplete | Custom dropdown + filter logic | Flutter `Autocomplete<Lexeme>` | Already used in `slot_editor.dart:291` and `particle_dialog.dart:148`; handles keyboard nav, focus, overlay positioning for desktop |
| Reactive lexeme lookup | Manual DB queries | `allLexemeListProvider` already loaded | Full list is already in memory for the lexicon tab; no additional DB work |
| Rule name lookup | Re-reading DB in traversal | Pass `morphologicalRuleListProvider` list once, index by id | Same pattern as `computedDerivedFormsProvider` |
| Child lexemes query | Custom SQL join | `childrenForLexemeProvider(id)` (manual) + filter `allLexemeListProvider` for `derivedFromLexemeId == id` (rule-derived) | Both already exist |

**Key insight:** Every data access pattern this phase needs already has a working implementation in the codebase. The phase is 100% widget + provider composition work.

---

## Bug Fix Analysis

### Bug 1: Multi-Level Sequential Derivation (CRITICAL to fix first)

**Location:** `lib/features/lexicon/data/lexeme_providers.dart` — `promotedDerivedFormProvider`, line 419.

**Current code:**
```dart
// lexeme_providers.dart:419 [VERIFIED: Read tool]
final result = engine.applyRule(parsed.rule!, parent.ipa, inventory);
```

**Root cause:** When word C (promoted derivation) derives from word B (promoted derivation) via rule R2, and B derives from A via R1:
- B is stored with `ipa = A.ipa` (placeholder per `promoteDerivation` at `lexeme_dao.dart:151`: `ipa: parent.ipa`)
- The comment at line 114 says: "ipa = parent.ipa — placeholder only; it is ignored by the promoted-form provider"
- But `promotedDerivedFormProvider` for C reads `parent.ipa` (= `B.ipa` = `A.ipa`) and applies R2 to it
- This applies R2 to A's IPA instead of B's computed form

**Fix:** Before applying the rule, check if the parent is itself a promoted derivation. If so, use `promotedDerivedFormProvider(parent.id)` to get the parent's correctly computed IPA as input.

```dart
// Fixed promotedDerivedFormProvider (conceptual — plan will detail exact code)
// [ASSUMED: exact Dart pattern, logic verified from codebase analysis]
final promotedDerivedFormProvider =
    Provider.family<PromotedDerivedForm?, int>((ref, lexemeId) {
  // ... (existing setup code unchanged)

  // Get parent's IPA — but if parent is also a promoted derivation,
  // use its computed form rather than its stored placeholder IPA.
  final String parentIpa;
  if (parent.derivedFromLexemeId != null && parent.derivedViaRuleId != null) {
    // Parent is itself a promoted derivation — get its computed form
    final parentComputed = ref.watch(promotedDerivedFormProvider(parent.id));
    if (parentComputed == null) return null; // parent's chain is broken
    parentIpa = parentComputed.ipa;
  } else {
    parentIpa = parent.ipa;  // parent is a root or detached — ipa is authoritative
  }

  final result = engine.applyRule(parsed.rule!, parentIpa, inventory);
  // ... rest unchanged
});
```

**Important:** `promotedDerivedFormProvider` is already a `Provider.family` — watching itself recursively via `ref.watch(promotedDerivedFormProvider(parent.id))` is valid in Riverpod (providers can watch other family instances). Riverpod handles the dependency graph correctly. No circular dependency risk as long as there are no cycles in the derivation chain (which would be a DB integrity issue, not a provider issue).

### Bug 2: Parent Display Shows Wrong Form

**Cause:** Directly related to Bug 1. `WordDetailParentsSection._buildRuleDerivedParentRow` (line 1281-1284) reads `parent.romanization` / `parent.ipa` directly from the stored `Lexeme` row — and for a promoted derivation, those stored values are the grandparent's IPA, not B's computed form.

**Fix:** In `EtymologyChainSection` (which replaces `WordDetailParentsSection`), use `resolveDisplayForms(parent, ref.watch(promotedDerivedFormProvider(parent.id)))` to get the correctly computed display forms. The helper `resolveDisplayForms` already exists at `lexeme_providers.dart:362`.

---

## Component Implementation Guide

### EtymologyChainSection

**Replaces:** `WordDetailParentsSection` at `word_detail_panel.dart:675`

**Key implementation details:**

1. **Section visibility:** Identical to current `WordDetailParentsSection` — hidden when no parents AND no children. Check: `parents.isEmpty && !hasRuleDerivedParent && manualChildren.isEmpty && ruleDerivedChildren.isEmpty`.

2. **Children: two sources to combine:**
   - Manual children: `ref.watch(childrenForLexemeProvider(lexemeId))` — returns `List<LexemeParentRow>`
   - Rule-derived children: filter `allLexemeListProvider` for `lx.derivedFromLexemeId == lexemeId` — note these are *promoted* derived lexemes (stored rows), not computed-only derivations. Computed-only derivations are shown in `DerivationTreeWidget`, not here.

3. **Section header:** "Etymology Chain" (not "Parents") — 13px, w600, per UI-SPEC.

4. **Expansion state:** Expanded by default. If wrapping in `ExpansionTile`, set `initiallyExpanded: true`.

5. **Current word node styling:** `surfaceContainerHigh` background, 2px left border in `colorScheme.primary`, no tap target.

6. **Edge labels on children:**
   - Rule-derived children: look up rule name from `morphologicalRuleListProvider` using `child.derivedViaRuleId`
   - Manual children: use `row.relationship ?? 'parent'`

### SearchableParentSelector

**Replaces:** The `FilterChip` wall in `word_creation_form.dart:530-548`.

**Also needed in:** `EtymologyChainSection` for the "Add parent" affordance (currently absent from view mode — parents can only be added at word creation time).

**Key implementation details:**

1. **Widget contract:**
```dart
class SearchableParentSelector extends ConsumerStatefulWidget {
  const SearchableParentSelector({
    super.key,
    required this.selectedIds,        // Set<int> — current selection
    required this.onChanged,          // void Function(Set<int>) — new set
    required this.excludeId,          // int — don't show the current word as selectable parent
    this.enabled = true,
  });
}
```

2. **Autocomplete pattern:** Use `Autocomplete<Lexeme>` — same API as `slot_editor.dart:291`. The `optionsBuilder` filters `allLexemeListProvider` client-side by romanization + IPA + meaning (case-insensitive substring). Empty query returns empty iterable (no "show all" behavior — prevents the pill-wall problem).

3. **Selected pill rendering:** `Wrap` of `ActionChip` with `onDeleted` callback. Each chip calls `onChanged(selectedIds..remove(id))`.

4. **Deduplication:** `Autocomplete` should not show already-selected words in the options overlay (filter by `!selectedIds.contains(lx.id)`).

5. **Integration in `word_creation_form.dart`:** Replace the `Consumer` block at lines 514-550 with `SearchableParentSelector(selectedIds: _selectedParents, onChanged: (ids) => setState(() => _selectedParents = ids), excludeId: -1)`.

6. **Integration in `EtymologyChainSection`:** Add a "Add parent" section at the bottom of the Etymology Chain section when viewing. This requires a stateful sub-widget that holds a local `bool _addingParent` toggle + calls `LexemeParentsDao.insertParent` on selection. Deleting a manual parent chip calls `LexemeParentsDao.deleteParent`.

---

## Common Pitfalls

### Pitfall 1: DAG vs. Tree — Visited Set Must Be Per-Branch

**What goes wrong:** Pass a single mutable `Set<int>` through the recursion. Word D appears as a parent of both B and C (diamond DAG). When traversing B's branch first, D is added to visited. Then when traversing C's branch, D is already visited, so it gets marked as a cycle even though it isn't one.

**Why it happens:** Standard tree DFS reuses the visited set. DAG traversal requires per-branch copies.

**How to avoid:** Use `Set<int> newVisited = {...visited, currentId}` (immutable spread copy) before recursing into each parent branch.

**Warning signs:** "⚠ cycle" appearing on words that are clearly not in a cycle, just shared ancestors.

### Pitfall 2: Promoted Row's Stored IPA Is a Placeholder

**What goes wrong:** Reading `parent.ipa` or `parent.romanization` directly from a promoted derivation row to display it, or to use as input for another rule. The stored values equal the grandparent's IPA (by design, per `promoteDerivation`).

**Why it happens:** `promoteDerivation` stores `ipa: parent.ipa` as a non-nullable placeholder. The comment in `lexeme_providers.dart:114` says "ignored by the promoted-form provider" — but other code (e.g., `WordDetailParentsSection._buildRuleDerivedParentRow`) reads the raw field.

**How to avoid:** Always display promoted derivations through `resolveDisplayForms(lexeme, ref.watch(promotedDerivedFormProvider(lexeme.id)))`. This helper exists at `lexeme_providers.dart:362` and handles both cases.

**Warning signs:** Ancestor nodes in the etymology tree showing the wrong (root) word's phonemes.

### Pitfall 3: Rule-Derived Children vs. Computed-Only Derivations

**What goes wrong:** The `EtymologyChainSection`'s children section shows all computed derivations (from `computedDerivedFormsProvider`) in addition to promoted rows, creating overlap with the `DerivationTreeWidget` already shown below.

**Why it happens:** There are two kinds of "children" — *promoted* stored rows (`derivedFromLexemeId == current`) and *computed-only* on-the-fly derivations (shown in `DerivationTreeWidget`). Only promoted rows should appear in the etymology chain children section.

**How to avoid:** Filter `allLexemeListProvider` for `lx.derivedFromLexemeId == lexemeId` to get only stored promoted children. Do not use `computedDerivedFormsProvider` in the etymology chain section.

### Pitfall 4: `Autocomplete` Display String vs. Object

**What goes wrong:** `Autocomplete<Lexeme>` requires `displayStringForOption` callback. If not set, Flutter calls `option.toString()` which renders the Drift row's default `toString()` — unreadable.

**Why it happens:** Generic Autocomplete widget uses display string for both the options list and the input field value when selected.

**How to avoid:** 
```dart
// Source: slot_editor.dart:291 pattern [VERIFIED: codebase]
Autocomplete<Lexeme>(
  displayStringForOption: (lx) =>
    (lx.romanization?.isNotEmpty == true ? lx.romanization! : lx.ipa) +
    (lx.meaning != null ? ' — ${lx.meaning}' : ''),
  optionsBuilder: (textValue) { /* filter allLexemes */ },
  onSelected: (lx) { /* add to selection */ },
)
```

### Pitfall 5: riverpod_lint Warning on `ref.watch` Inside Conditional

**What goes wrong:** `promotedDerivedFormProvider` fix introduces a conditional `ref.watch` inside an `if` block. `riverpod_lint` may flag this as a lint violation (providers should be watched unconditionally).

**Why it happens:** Riverpod lint expects all `ref.watch` calls to appear at the top of `build`/`Provider` body unconditionally to ensure stable dependency tracking.

**How to avoid:** Always call `ref.watch(promotedDerivedFormProvider(parent.id))` unconditionally (move it before the `if` check), then use the result conditionally. The watcher result will simply be `null` for non-promoted parents.

---

## Code Examples

### Existing Autocomplete Pattern (reuse directly)

```dart
// Source: slot_editor.dart:291 [VERIFIED: codebase Read]
Autocomplete<String>(
  optionsBuilder: (textEditingValue) {
    if (textEditingValue.text.isEmpty) {
      return const Iterable<String>.empty();
    }
    return options.where(
      (item) => item.toLowerCase().contains(textEditingValue.text.toLowerCase()),
    );
  },
  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(labelText: 'Search...'),
    );
  },
  onSelected: (value) { /* handle selection */ },
)
```

### Existing resolveDisplayForms Helper

```dart
// Source: lexeme_providers.dart:362 [VERIFIED: codebase Read]
({String rom, String ipa}) resolveDisplayForms(
  Lexeme lexeme,
  PromotedDerivedForm? promoted,
) {
  if (promoted != null) {
    return (rom: promoted.romanization, ipa: promoted.ipa);
  }
  return (
    rom: (lexeme.romanization != null && lexeme.romanization!.isNotEmpty)
        ? lexeme.romanization!
        : lexeme.ipa,
    ipa: lexeme.ipa,
  );
}
```

### Existing ActionChip Parent Row Pattern (foundation for NodeChip)

```dart
// Source: word_detail_panel.dart:1290-1304 [VERIFIED: codebase Read]
ActionChip(
  avatar: const Icon(Icons.arrow_upward, size: 14),
  label: Text(
    chipLabel,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 2),
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  onPressed: () => onNavigateToWord!(parent.id),
)
```

### Existing Section Header Pattern

```dart
// Source: word_detail_panel.dart:1256-1263 [VERIFIED: codebase Read]
Text(
  'Etymology Chain',  // formerly 'Parents'
  style: theme.textTheme.bodyMedium?.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  ),
),
const SizedBox(height: 6),
```

### Existing Connector Line Pattern (reuse in ancestry nodes)

```dart
// Source: derivation_tree_widget.dart:427-432 [VERIFIED: codebase Read]
Container(
  width: 12,
  height: 1,
  color: cs.outlineVariant,
  margin: const EdgeInsets.only(right: 4),
),
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All words as FilterChip pills for parent selection | Searchable Autocomplete + removable chips | Phase 11 | Scales to large lexicons |
| Flat "Parents" list (one level up) | Full DAG ancestry tree (N levels up + 1 level down) | Phase 11 | Full etymology visibility |
| `promotedDerivedFormProvider` applies rule to raw `parent.ipa` | Provider checks if parent is also promoted, uses computed form | Phase 11 (bug fix) | Multi-level derivation chains correct |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `promotedDerivedFormProvider` watching itself recursively via `ref.watch(promotedDerivedFormProvider(parent.id))` is valid in Riverpod 3.0.x and won't create circular dependency errors | Bug Fix Analysis | Medium — if Riverpod forbids self-family-watch in `Provider.family`, alternative is to inline the parent IPA resolution without using the provider recursively |
| A2 | `riverpod_lint` may warn about conditional `ref.watch` in the bug fix | Common Pitfalls | Low — lint warning, not compile error; can silence or restructure |
| A3 | A `watchAllParentLinks()` method (returning all rows from `lexemeParents` table) is needed to make the ancestry chain provider react to ancestor link changes | Architecture Patterns — Option A | Low — Option B (watch only direct parents) would work but miss reactivity for deep changes |

---

## Open Questions

1. **Where does `SearchableParentSelector` live in edit flow?**
   - What we know: Manual parents currently can only be added at word creation time (in `word_creation_form.dart`). The detail panel view mode has no "Add parent" affordance.
   - What's unclear: Should `EtymologyChainSection` include an inline "Add parent" button in view mode (non-editing state)? Or should adding parents require entering edit mode?
   - Recommendation: Based on CONTEXT.md intent ("Clicking a pill removes the parent link"), parent management belongs inline in the etymology section itself (not behind an edit-mode gate). Add a small "Add parent" `TextButton.icon` at the bottom of the Etymology Chain section that toggles the `SearchableParentSelector` into view. This is consistent with how exceptions are managed (via `TextButton.icon` "Add exception" in view mode at line 719).

2. **`word_creation_form.dart` parent selector scope**
   - What we know: The FilterChip wall is in `word_creation_form.dart` lines 530-548 and uses a `Set<int> _selectedParents` already.
   - What's unclear: Whether the phase is expected to update `word_creation_form.dart` or only add the searchable selector to the existing etymology section.
   - Recommendation: Update both: replace the FilterChip wall in creation form AND add inline parent management to EtymologyChainSection. Both are needed for LEX-09 to feel complete.

---

## Environment Availability

Step 2.6: SKIPPED — phase is purely code/widget changes with no external dependencies beyond the existing Flutter toolchain.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.38.5) |
| Config file | none — standard `flutter test` discovery |
| Quick run command | `flutter test test/lexicon/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LEX-09 | Ancestry traversal returns correct chain (single parent) | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 |
| LEX-09 | Cycle detection stops traversal and marks node | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 |
| LEX-09 | Multi-parent (compound) node expands both branches | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 |
| LEX-09 | 10-level truncation shows correct count | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 |
| Bug 1 | `promotedDerivedFormProvider` computes C correctly when B is also promoted | unit | `flutter test test/lexicon/lexeme_providers_test.dart` | ❌ Wave 0 |
| Bug 2 | NodeChip displays B's computed form, not A's raw IPA | unit | `flutter test test/lexicon/etymology_chain_test.dart` | ❌ Wave 0 |

Note: Existing `test/lexicon/lexeme_dao_test.dart` provides the in-memory DB setup pattern (`AppDatabase(NativeDatabase.memory())`) which all new tests should follow.

### Sampling Rate

- **Per task commit:** `flutter test test/lexicon/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lexicon/etymology_chain_test.dart` — covers LEX-09 traversal logic (unit tests against pure Dart traversal function, no Flutter widget pump needed)
- [ ] `test/lexicon/lexeme_providers_test.dart` — covers Bug 1 fix (in-memory DB + provider container test)

---

## Security Domain

`security_enforcement` is not explicitly set to `false` in `.planning/config.json`. However, this phase involves no authentication, sessions, access control, cryptography, or sensitive data. The only data operations are reads from `allLexemeListProvider` and write operations (`insertParent`, `deleteParent`) on the `lexeme_parents` junction table.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — local desktop app, no auth |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a — single-user SQLite |
| V5 Input Validation | yes (minimal) | Relationship label text field — length constraint (existing TextField pattern, no injection risk in SQLite via Drift parameterized queries) |
| V6 Cryptography | no | n/a |

**No security concerns.** All DB writes go through Drift's parameterized query layer (existing pattern). No user-supplied content is rendered as HTML/code. No network calls.

---

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/features/lexicon/data/lexeme_providers.dart` — promotedDerivedFormProvider, allLexemeListProvider, resolveDisplayForms
- Codebase: `lib/features/lexicon/data/lexeme_dao.dart` — promoteDerivation stores `ipa: parent.ipa` placeholder
- Codebase: `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — WordDetailParentsSection (to be replaced), edit mode structure, onNavigateToWord wiring
- Codebase: `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` — existing connector line pattern, _TreeNode/_DerivedRow
- Codebase: `lib/features/grammar/data/lexeme_parents_dao.dart` — existing DAO API
- Codebase: `lib/features/grammar/data/grammar_providers.dart` — parentsForLexemeProvider, childrenForLexemeProvider
- Codebase: `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` — FilterChip wall (to be replaced)
- Codebase: `lib/features/grammar/presentation/constructions/slot_editor.dart` — Autocomplete<String> pattern
- Codebase: `lib/db/app_database.dart` — LexemeParents schema, Lexemes schema
- `.planning/phases/11-lexicon-etymology-chain/11-CONTEXT.md` — locked decisions
- `.planning/phases/11-lexicon-etymology-chain/11-UI-SPEC.md` — visual/interaction contract
- `pubspec.yaml` — confirmed no new packages needed
- `flutter --version` output — Flutter 3.38.5, Dart 3.10.4

### Secondary (MEDIUM confidence)
- None needed — all findings verified directly from codebase.

### Tertiary (LOW confidence)
- A1 (Riverpod self-family-watch): based on Riverpod 3.x training knowledge — not empirically tested in this session.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from pubspec.yaml and codebase
- Architecture: HIGH — derived from verified existing patterns in codebase
- Bug analysis: HIGH — root cause traced to specific lines of verified source code
- Pitfalls: HIGH — derived from direct code analysis
- A1 (Riverpod recursive watch): LOW — unverified assumption

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (stable domain — Flutter/Riverpod patterns don't change frequently)
