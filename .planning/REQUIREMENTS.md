# Requirements: Conlang Workbench

**Defined:** 2026-04-08
**Core Value:** A powerful, flexible morphology engine that handles the full spectrum of language types through a readable pattern mini-language

## v1.0 Requirements (Shipped)

### Project Management

- [x] **PROJ-01**: User can create, open, and delete conlang projects — Validated Phase 1
- [x] **PROJ-02**: Each project stores all data in its own SQLite database in a dedicated folder — Validated Phase 1
- [x] **PROJ-03**: User can switch between projects from a project selector — Validated Phase 1

### Phonology

- [x] **PHON-01**: User can define a phoneme inventory (consonants and vowels) with IPA symbols, manner/place of articulation — Validated Phase 1
- [x] **PHON-02**: User can view and interact with a full IPA chart with clickable audio playback (real recordings) — Validated Phase 1
- [x] **PHON-03**: User can input IPA text via an on-screen IPA keyboard — Validated Phase 1
- [x] **PHON-04**: User can define phonotactic rules (syllable structure constraints) — Validated Phase 1
- [x] **PHON-05**: Words that violate phonotactics appear highlighted in red throughout the tool (with exception override for loanwords) — Validated Phase 3
- [x] **PHON-06**: User can define phonological rules (e.g. a + nasal -> ã, allophonic variation) — Validated Phase 1
- [x] **PHON-07**: User can define Latin transcription mappings (IPA to romanization) — Validated Phase 1
- [x] **PHON-08**: User can generate random words that conform to phonotactic rules — Validated Phase 1
- [x] **PHON-09**: Predefined natural classes (Stop, Liquid, Rhotic, Nasal, Fricative, etc.) with sensible IPA defaults, including sounds outside the project inventory — Validated Phase 3.2
- [x] **PHON-11**: User can click a phoneme to view all contextual allophones based on phonological rules — Validated Phase 3.2

### Lexicon

- [x] **LEX-01**: User can add, edit, and delete root words with meaning, part of speech, and IPA transcription — Validated Phase 3
- [x] **LEX-02**: User can view derived words generated from roots via morphological rules, with etymology tracing — Validated Phase 3
- [x] **LEX-03**: User can search and filter the lexicon by meaning, root, part of speech, or phonetic pattern — Validated Phase 3
- [x] **LEX-04**: User can reference the built-in Swadesh list to guide core vocabulary creation — Validated Phase 3
- [x] **LEX-05**: User can reference the integrated Conlanger's Thesaurus for semantic coverage guidance — Validated Phase 3
- [x] **LEX-06**: User can export vocabulary as Anki .apkg flashcards — Validated Phase 3
- [x] **LEX-07**: User can generate new words that follow phonotactic constraints — Validated Phase 1

### Morphology

- [x] **MORPH-01**: User can define morphological rules using a readable pattern mini-language (suffixes, prefixes, infixes, vowel replacements, root templates) — Validated Phase 2
- [x] **MORPH-02**: The morphology engine handles agglutinative, Semitic triconsonantal, fusional, and analytic language types in one unified system — Validated Phase 2
- [x] **MORPH-03**: User can define word derivation rules (e.g. -tion, -er, CaCCaaC templates from triconsonantal roots) — Validated Phase 2
- [x] **MORPH-04**: User can define per-word exceptions to override any morphological rule for irregular forms — Validated Phase 2/3

### Display & UX

- [x] **FIX-01**: IPA vowel chart and phoneme inventory charts render with correct standard IPA shapes — Validated Phase 3.1
- [x] **FIX-02**: Word generator displays words as romanization first — Validated Phase 3.1
- [x] **FIX-03**: Anki cards show romanization on first line, IPA on second line — Validated Phase 3.1
- [x] **FIX-04**: Anki export UI uses an "Export to Anki" button with confirm/cancel — Validated Phase 3.1
- [x] **FIX-05**: Phoneme inventory shows romanized form alongside IPA — Validated Phase 3.1

### Grammar

- [x] **GRAM-01**: User can define parts of speech categories with N user-defined grammatical dimensions — Validated Phase 4
- [x] **GRAM-02**: User can attach inflectional morphology rules to dimension levels that stack hierarchically — Validated Phase 4
- [x] **GRAM-03**: User can generate full paradigm charts for any word based on its POS dimensions — Validated Phase 4
- [x] **GRAM-04**: User can specify language typology choices — Validated Phase 4
- [x] **GRAM-05**: User can override any individual cell in a paradigm table with a manual exception form — Validated Phase 4
- [x] **GRAM-06**: The standalone Morphology tab is removed; rule editor UI reused in Grammar and Lexicon — Validated Phase 4
- [x] **GRAM-07**: Existing morphology rules migrate to lexicon derivational rules — Validated Phase 4

### Culture

- [x] **CULT-01**: User can create and organize wiki-style documentation pages in Markdown format — Validated Phase 5
- [x] **CULT-02**: User can create internal links between culture pages (wiki-style linking) — Validated Phase 5

### Reference

- [x] **REF-01**: User can search a built-in glossary of linguistic terminology with definitions — Validated Phase 6

### Polish & Platform

- [x] **NIT-01** through **NIT-05**: UI polish items — Validated Phase 7
- [x] **REFAC-01**: Dead code cleanup + rule_editor_dialog refactor — Validated Phase 7
- [x] **GEM-01**: Gemination restrictions as phonotactic constraints — Validated Phase 8
- [x] **PLAT-01**: macOS native menu bar — Validated Phase 9
- [x] **PLAT-02**: Project management (.conlang file format, rename, save-as) — Validated Phase 9
- [x] **PLAT-03**: App name + custom logo — Validated Phase 9

## v2.0 Requirements

Requirements for v2.0 milestone. Each maps to roadmap phases.

### Analytic Grammar

- [ ] **AGRAM-01**: User can define closed-class words (particles, aux verbs, prepositions, determiners, conjunctions) with grammatical gloss tags (DEF, NEG, PROG, etc.) in a dedicated inventory separate from content words
- [ ] **AGRAM-02**: User can define named phrase construction rules with ordered slots (e.g. "negation = NEG + V", "future = AUX:FUT + V", "genitive = N + PREP:GEN + N")
- [ ] **AGRAM-03**: User can define structured word order patterns (basic order SVO/SOV/etc., head-directionality, adposition placement, NP/VP/PP ordering rules)

### Writing Scratchpad

- [ ] **WRIT-01**: User can write phrases and have them tokenized into morphemes with automatic interlinear glossing in Leipzig format (original / morpheme gloss / free translation)
- [ ] **WRIT-02**: Unknown tokens display as "?" in the gloss, and words violating phonotactics or grammar rules are highlighted as errors
- [ ] **WRIT-03**: User can generate IPA transcription of written phrases from phonology rules
- [ ] **WRIT-04**: User can enter a free translation line beneath each glossed phrase

### AI Integration

- [ ] **AI-01**: MCP server auto-starts with the app and exposes phoneme inventory, lexicon, grammar rules, morphology patterns, and culture wiki as MCP tools
- [ ] **AI-02**: External MCP clients (Claude Desktop, etc.) can connect to the running server and query/interact with all project data

### Writing System

- [ ] **WSYS-01**: User can define orthography rules mapping graphemes to phoneme sequences, supporting diverse script types (alphabet, abjad, syllabary, abugida) with priority ordering and context-sensitive rules
- [ ] **WSYS-02**: User can load custom .ttf/.otf font files for their writing system and preview text rendered in the custom script
- [ ] **WSYS-03**: Scratchpad text can be rendered in the custom script alongside romanization

### Lexicon Extras

- [ ] **LEX-09**: User can view the full etymology chain (root → derived → compound) as a visual lineage display in the lexicon

### Language Evolution

- [ ] **EVOL-01**: User can define ordered, context-sensitive sound change rules and apply them to the full lexicon with preview diff before committing
- [ ] **EVOL-02**: User can promote an allophone to a full phoneme (split), with guided updates to inventory, rules, and affected lexicon entries
- [ ] **EVOL-03**: User can model broader diachronic changes: phoneme mergers/fusions, grammatical evolution (e.g. analytic → agglutinative), and track language family lineage trees showing how daughter languages descend from parent languages

## Future Requirements

Deferred beyond v2.0. Tracked but not in current roadmap.

### Input & Diacritics

- **DIAC-01**: App-wide compose-key system for common romanization diacritics (e.g. a+macron → ā)

### Word Preview

- **WPREV-01**: Example paragraph preview in word generator showing generated words in running text

### Audio

- **TTS-01**: User can hear conlang text read aloud via TTS synthesis with phoneme mapping

### AI Enhancements

- **AI-03**: In-app AI chat panel as linguistics tutor + co-creator with full project context

### Scratchpad Enhancements

- **WRIT-05**: Export interlinear glosses as LaTeX (gb4e/expex) or HTML (Leipzig.js format)

### Lexicon Enhancements

- **LEX-10**: Automatic etymology suggestions — detect compound words by matching known root concatenations

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile app | Desktop-first; Flutter allows future expansion but not in scope |
| Collaborative/multi-user editing | Single-user tool — conlanging is a solo creative activity |
| Cloud sync | All data stays local; user preference for offline-first |
| Machine translation | Full natlang-to-conlang translation is AI-complete; out of scope |
| Social/sharing features | ConWorkShop already fills this niche |
| Full NLP pipeline | Dependency/constituency parsing is a different product; interlinear gloss covers 90% of needs |
| Font/glyph editor | FontForge/Glyphr Studio are mature dedicated tools; load custom fonts instead |
| PHON-10 | Natural class sharing across projects — descoped v1, remains out of scope |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AGRAM-01 | Phase 10 | Pending |
| AGRAM-02 | Phase 10 | Pending |
| AGRAM-03 | Phase 10 | Pending |
| LEX-09 | Phase 11 | Pending |
| WRIT-01 | Phase 12 | Pending |
| WRIT-02 | Phase 12 | Pending |
| WRIT-03 | Phase 12 | Pending |
| WRIT-04 | Phase 12 | Pending |
| WSYS-01 | Phase 13 | Pending |
| WSYS-02 | Phase 13 | Pending |
| WSYS-03 | Phase 13 | Pending |
| AI-01 | Phase 14 | Pending |
| AI-02 | Phase 14 | Pending |
| EVOL-01 | Phase 15 | Pending |
| EVOL-02 | Phase 15 | Pending |
| EVOL-03 | Phase 16 | Pending |

**Coverage:**
- v2.0 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-13 after v2.0 roadmap creation*
