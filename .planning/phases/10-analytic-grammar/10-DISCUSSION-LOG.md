# Phase 10: Analytic Grammar - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 10-analytic-grammar
**Areas discussed:** Closed-class inventory, Phrase constructions, Word order settings, Grammar tab structure

---

## Closed-Class Inventory

### Location

| Option | Description | Selected |
|--------|-------------|----------|
| Grammar sub-tab (Recommended) | New sidebar item in Grammar shell — keeps closed-class words near inflections and typology | ✓ |
| Lexicon sub-tab | New sidebar item in Lexicon shell alongside Dictionary, Swadesh, Thesaurus | |
| Both views | Primary editor in Grammar, read-only reference view in Lexicon | |

**User's choice:** Grammar sub-tab
**Notes:** None

### Gloss Tags

| Option | Description | Selected |
|--------|-------------|----------|
| Free-form text | User types any gloss tag string | |
| Predefined catalog + custom | Ship catalog of common Leipzig abbreviations as suggestions, allow custom entries | ✓ |
| Strict predefined only | Only allow tags from a fixed Leipzig glossing set | |

**User's choice:** Predefined catalog + custom
**Notes:** None

### Storage

| Option | Description | Selected |
|--------|-------------|----------|
| Same Lexemes table + flag (Recommended) | Add closedClass flag to Lexemes. Unified search, Anki, phonotactics work automatically | ✓ |
| Separate table | New ClosedClassWords table with own schema | |

**User's choice:** Same Lexemes table + flag
**Notes:** None

### Multiple Tags

| Option | Description | Selected |
|--------|-------------|----------|
| One tag per word (Recommended) | Each word has exactly one gloss tag. Multiple functions → separate entries | ✓ |
| Multiple tags per word | Word can carry several gloss tags as a list | |

**User's choice:** One tag per word
**Notes:** None

### POS Assignment

**User's clarification:** Closed-class words should also carry a POS — e.g. auxiliary verbs are still verbs. The closed-class flag is orthogonal to POS.

---

## Phrase Constructions

### Authoring Method

| Option | Description | Selected |
|--------|-------------|----------|
| Visual slot editor (Recommended) | Drag-and-drop or add-button interface with labeled slot boxes | ✓ |
| Text-based DSL | Write rules as text like 'NEG + V' | |
| Hybrid (visual + text) | Visual editor as primary with raw text toggle | |

**User's choice:** Visual slot editor
**Notes:** User selected after seeing preview mockup of slot boxes

### Slot Types

| Option | Description | Selected |
|--------|-------------|----------|
| Gloss tags + POS categories (Recommended) | Slots reference closed-class gloss tags or open-class POS categories | ✓ |
| Gloss tags only | Slots only reference closed-class gloss tags | |
| Gloss tags + POS + specific words | Slots can reference tags, POS, or specific lexeme entries | |

**User's choice:** Gloss tags + POS categories
**Notes:** None

### Rule Grouping

| Option | Description | Selected |
|--------|-------------|----------|
| Flat list with names (Recommended) | Each rule has a descriptive name, simple flat list | ✓ |
| Grouped by category | Rules organized under categories (Tense/Aspect, Polarity, etc.) | |

**User's choice:** Flat list with names
**Notes:** None

### Live Preview

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, live preview (Recommended) | Show preview with actual words from lexicon | ✓ |
| No preview needed | Visual editor is self-explanatory | |

**User's choice:** Yes, live preview
**Notes:** None

---

## Word Order Settings

### Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Extend Typology page (Recommended) | Add new sections below existing dropdowns | ✓ |
| New 'Word Order' sub-tab | Split into own sidebar item | |

**User's choice:** Extend Typology page
**Notes:** None

### Detail Level

| Option | Description | Selected |
|--------|-------------|----------|
| Core settings only (Recommended) | Head-directionality, adposition type, adjective/genitive placement | ✓ |
| Full phrase structure | Detailed slot ordering for NP, VP, PP, clause-level | |
| Minimal | Only head-directionality and adposition type | |

**User's choice:** Core settings only
**Notes:** None

### Role of Settings

| Option | Description | Selected |
|--------|-------------|----------|
| Descriptive now, parseable later (Recommended) | Structured data so Phase 12 can use them | ✓ |
| Purely descriptive | Free text notes | |

**User's choice:** Descriptive now, parseable later
**Notes:** None

---

## Grammar Tab Structure

### Sidebar Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Add 2 items: Particles + Constructions (Recommended) | Grammar shell grows to 5 sidebar items | ✓ |
| Add 1 combined item | Single 'Analytic Grammar' item | |
| Reorganize into sections | Group into Morphology / Syntax sections | |

**User's choice:** Add 2 items: Particles + Constructions
**Notes:** User selected after seeing sidebar preview mockup

### Particles Page Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Grouped by POS (Recommended) | Sections like Auxiliaries, Determiners, Conjunctions | ✓ |
| Flat list with filters | Single alphabetical list with filter chips | |
| Grouped by gloss tag | Organized by grammatical function | |

**User's choice:** Grouped by POS
**Notes:** None

---

## Claude's Discretion

- Icon choices for new sidebar items
- Leipzig glossing catalog contents
- Particles page layout details
- Construction slot editor widget design

## Deferred Ideas

None — discussion stayed within phase scope
