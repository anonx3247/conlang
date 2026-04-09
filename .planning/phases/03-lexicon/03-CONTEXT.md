# Phase 3: Lexicon - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can build and navigate a root-and-derived-word dictionary with search, semantic coverage guidance (Swadesh list + Conlanger's Thesaurus), Anki flashcard export, and phonotactic violation highlighting across the tool. Exception UI (deferred from Phase 2) is delivered here on the word detail page. Paradigm chart generation belongs in Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Dictionary layout
- **D-01:** Master-detail layout — scrollable word list on the left, detail panel on the right showing full entry (IPA, meaning, derivation tree, exceptions)
- **D-02:** Word list also supports a table view toggle (spreadsheet-style with sortable columns: word, IPA, POS, meaning)
- **D-03:** POS filter chips/dropdown in the master panel to filter the word list
- **D-04:** Word list shows only root entries; derived forms appear in the detail panel when a root is selected
- **D-05:** Derivation chain displayed as a visual tree diagram in the detail panel (root → level 1 → level 2, with branching for multiple derivations). Irregular/exception forms shown in amber/orange (carried from Phase 2)
- **D-06:** New root words added via inline form in the detail panel area ("+ New root" button). Fields: IPA (with keyboard popup), romanization, meaning, POS dropdown
- **D-07:** When romanization is enabled, the romanized form is the primary input field and IPA is auto-derived from romanization mappings (reverse direction). IPA field still editable for manual override.
- **D-08:** Word generator panel shown alongside the word creation form as an "inspiration panel" — generates phonotactically valid candidates that the user can click/select to fill the IPA/romanization field. Available for all word creation, not just Thesaurus gaps.

### Search & filtering
- **D-09:** Instant client-side filter (no FTS5 for now). Typing in the search bar instantly filters the visible word list
- **D-10:** Searchable fields: meaning/gloss, IPA/romanization, and part of speech
- **D-11:** Search matches both roots and derived words. When a derived word matches, its root appears in the list with the matched derived form highlighted in the detail panel

### Semantic references
- **D-12:** Lexicon sidebar has three sub-navigation items: **Dictionary**, **Swadesh List**, **Thesaurus**
- **D-13:** Swadesh list presented as a checklist of ~207 concepts. Concepts with matching lexicon entries are checked/green with linked word. Unchecked concepts have a "Create" action. Coverage progress shown (e.g. "45/207 — 22%")
- **D-14:** Conlanger's Thesaurus presented as a browsable hierarchical category tree (e.g. Nature > Weather > Rain types). Each leaf concept shows whether a word exists. Pre-extracted from PDF into bundled JSON
- **D-15:** Thesaurus tree has a search/filter bar to quickly find concepts within the hierarchy
- **D-16:** Clicking "Create" from a Swadesh/Thesaurus gap opens the inline word creation form with the meaning pre-filled from the concept

### Anki export
- **D-17:** Card fields: front = IPA form (+ romanization if enabled), back = meaning/gloss. Additional fields: POS tag, morphological context for derived words (root + rule name that produced it)
- **D-18:** Export scope is selection-based — user selects specific words (or "select all") from the lexicon list, then exports those as a .apkg deck
- **D-19:** No audio field for now (TTS is v2 scope)

### Exception UI (carried from Phase 2)
- **D-20:** Per-word exception management lives on the word detail page (Phase 2 decision: "exceptions entered from the word")
- **D-21:** Schema and DAO already complete from Phase 2 (MorphologicalRuleExceptions table) — this phase adds the UI

### Claude's Discretion
- Table view column configuration and sort behavior
- Exact word generator panel placement relative to the creation form
- Swadesh list data source and format (standard 207-item list)
- Thesaurus JSON extraction approach from fiatlingua.org PDF
- Empty state designs for new/empty lexicons
- How "select for export" works in the UI (checkboxes, multi-select, etc.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Database schema
- `lib/db/app_database.dart` — Lexemes table definition (lines 153-162), MorphologicalRuleExceptions table (lines 133-139), PartsOfSpeech table (line 102)

### Existing morphology integration
- `lib/features/morphology/data/morphology_dao.dart` — MorphologyDao with rule CRUD and engine methods
- `lib/features/morphology/domain/morphology_engine.dart` — Engine that applies rules to roots (needed for derived word computation)

### Reusable UI components
- `lib/features/phonology/presentation/sound_rules/word_generator_panel.dart` — Word generator panel (reuse for inspiration panel)
- `lib/features/phonology/domain/word_generator.dart` — Word generation logic from phonotactic rules
- `lib/shared/widgets/app_shell.dart` — App shell with tab navigation

### Prior phase context
- `.planning/phases/01-foundation/01-CONTEXT.md` — Navigation patterns, IPA keyboard popup, violation display decisions
- `.planning/phases/02-morphology-engine/02-CONTEXT.md` — Exception handling decisions, hybrid authoring pattern, preview behavior

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Lexemes table**: Already defined in schema with all needed columns (ipa, rootId, ruleIds, computedForm, romanization, meaning, partOfSpeech)
- **MorphologicalRuleExceptions table**: Schema + DAO ready from Phase 2; needs UI only
- **PartsOfSpeech table**: Exists from Phase 2 gap closure (02-08) — reuse for POS filter dropdown
- **IpaTextField**: Widget with IPA keyboard popup — reuse for IPA input in word creation form
- **WordGeneratorPanel**: Generates sample words from phonotactics — adapt into "inspiration panel"
- **Morphology engine**: Can apply rules to roots to compute derived forms
- **romanizationEnabledProvider**: Already watches project settings for romanization toggle

### Established Patterns
- Drift DAO pattern: DatabaseAccessor<AppDatabase> with @DriftAccessor annotation
- Riverpod StreamProvider for reactive data (manual providers, not codegen, for Drift types)
- Debounced live preview (300ms timer) for instant feedback
- Tab + sidebar navigation in AppShell

### Integration Points
- AppShell: Add Lexicon tab (currently only Phonology and Morphology active)
- GoRouter: Add lexicon routes (dictionary, swadesh, thesaurus sub-routes)
- Morphology engine: Call to compute derived forms when displaying a root's derivation tree
- Romanization mappings: Reverse lookup for romanization→IPA auto-derivation in word creation

</code_context>

<specifics>
## Specific Ideas

- Word generator as persistent "inspiration panel" next to all word creation forms — not a separate page, but an always-available suggestion source with clickable/selectable candidates
- Romanized form as primary input when romanization is enabled — matches the user's mental model (they think in their romanization, not raw IPA)
- Visual derivation tree in detail panel — shows the morphological family at a glance, with amber/orange for irregular forms
- Thesaurus as a browsable tree with search — not just a flat list, preserving the semantic hierarchy for exploration

</specifics>

<deferred>
## Deferred Ideas

- **Paradigm tables / conjugation charts in morphology tab** — user wants a "tables" view to show all forms of a word's conjugation/declension. This maps to Phase 4 (GRAM-03: paradigm chart generation). Consider adding it as a morphology tab sub-section or as part of the word detail panel in Phase 4.
- **Phonetic pattern search** (e.g. "words ending in nasal", CVC structure) — not selected for Phase 3 search. Could be added later as an advanced filter.
- **FTS5 full-text search** — deferred in favor of instant client-side filter. Add if lexicon size exceeds ~10k words.
- **Audio field on Anki cards** — TTS is v2 scope; card template can be extended later.

</deferred>

---

*Phase: 03-lexicon*
*Context gathered: 2026-04-09*
