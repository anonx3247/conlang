# Phase 3: Lexicon - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 03-lexicon
**Areas discussed:** Dictionary layout, Search & filtering, Semantic references, Anki export

---

## Dictionary Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Master-detail | Word list left, detail panel right | ✓ |
| Expandable list | Single column with inline expand | |
| Table view | Spreadsheet-style sortable columns | |

**User's choice:** Master-detail, but also wants a table view toggle and POS filters in the master panel.
**Notes:** Both views available — master-detail as default, table view as toggle.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Roots only in list | Derived forms in detail panel | ✓ |
| Flat mixed list | Both roots and derived in same list | |
| Grouped tree | Expandable tree nodes in list | |

**User's choice:** Roots only in list
**Notes:** Keeps the list clean; derivation hierarchy shown in detail panel.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Flat list with arrows | Simple vertical list: root → derived | |
| Visual tree diagram | Branching tree showing derivation chains | ✓ |
| You decide | Claude picks | |

**User's choice:** Visual tree diagram
**Notes:** Shows morphological family at a glance with branching.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Inline form in detail panel | Form replaces detail area | ✓ |
| Dialog popup | Modal dialog for word creation | |
| You decide | Claude picks | |

**User's choice:** Inline form in detail panel
**Notes:** When romanization is enabled, romanized form is the primary input field and IPA is auto-derived. Also wants word generator as an "inspiration panel" next to all word creation forms with clickable/selectable candidates.

---

## Search & Filtering

| Option | Description | Selected |
|--------|-------------|----------|
| Instant filter | Client-side filtering, fast for ~10k words | ✓ |
| FTS5 full-text | SQLite FTS5 index, scales to large lexicons | |
| You decide | Claude picks | |

**User's choice:** Instant filter
**Notes:** FTS5 deferred unless lexicon grows very large.

---

**Searchable fields selected:** Meaning/gloss, IPA/romanization, Part of speech
**Not selected:** Phonetic pattern search (deferred)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Include derived words | Search matches roots and derived forms | ✓ |
| Roots only | Search only matches root words | |

**User's choice:** Include derived words
**Notes:** When a derived word matches, its root appears in list with match highlighted.

---

## Semantic References

| Option | Description | Selected |
|--------|-------------|----------|
| Sidebar checklist | Dedicated sidebar section, coverage indicators | ✓ |
| Inline badges | Badges on dictionary entries | |
| You decide | Claude picks | |

**User's choice:** Sidebar checklist for Swadesh list
**Notes:** Three sidebar items: Dictionary, Swadesh List, Thesaurus.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Browsable category tree | Hierarchical categories with coverage | ✓ |
| Flat searchable list | All concepts in one list | |
| You decide | Claude picks | |

**User's choice:** Browsable category tree for Thesaurus
**Notes:** Wants a search/filter bar to find concepts within the tree.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-filled word form | Opens creation form with meaning filled | ✓ |
| Generate suggestions | Opens word generator with candidates | |
| Both options | Pre-filled + generate button | |

**User's choice:** Pre-filled form, but with word generator as persistent inspiration panel alongside ALL word creation (not just Thesaurus). Generated words must be clickable/selectable to fill the input.

---

## Anki Export

**Card fields selected:** IPA + meaning (front/back), Morphological context, Part of speech tag
**Not selected:** Audio placeholder (TTS is v2)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Selection-based | User selects words then exports | ✓ |
| Full lexicon always | Always exports everything | |
| You decide | Claude picks | |

**User's choice:** Selection-based export

---

## Claude's Discretion

- Table view column configuration and sort behavior
- Word generator panel placement relative to creation form
- Swadesh list data source format
- Thesaurus JSON extraction approach
- Empty state designs
- Selection UI for Anki export

## Deferred Ideas

- Paradigm tables / conjugation charts → Phase 4 (GRAM-03), user wants in morphology tab
- Phonetic pattern search → future filter enhancement
- FTS5 full-text search → if lexicon exceeds ~10k words
- Audio field on Anki cards → v2 (TTS scope)
