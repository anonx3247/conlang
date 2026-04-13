# Requirements: Conlang Workbench

**Defined:** 2026-04-08
**Core Value:** A powerful, flexible morphology engine that handles the full spectrum of language types through a readable pattern mini-language

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Project Management

- [ ] **PROJ-01**: User can create, open, and delete conlang projects
- [ ] **PROJ-02**: Each project stores all data in its own SQLite database in a dedicated folder
- [ ] **PROJ-03**: User can switch between projects from a project selector

### Phonology

- [ ] **PHON-01**: User can define a phoneme inventory (consonants and vowels) with IPA symbols, manner/place of articulation
- [ ] **PHON-02**: User can view and interact with a full IPA chart with clickable audio playback (real recordings)
- [ ] **PHON-03**: User can input IPA text via an on-screen IPA keyboard
- [ ] **PHON-04**: User can define phonotactic rules (syllable structure constraints)
- [ ] **PHON-05**: Words that violate phonotactics appear highlighted in red throughout the tool (with exception override for loanwords)
- [ ] **PHON-06**: User can define phonological rules (e.g. a + nasal -> ã, allophonic variation)
- [ ] **PHON-07**: User can define Latin transcription mappings (IPA to romanization)
- [ ] **PHON-08**: User can generate random words that conform to phonotactic rules

### Lexicon

- [ ] **LEX-01**: User can add, edit, and delete root words with meaning, part of speech, and IPA transcription
- [ ] **LEX-02**: User can view derived words generated from roots via morphological rules, with etymology tracing
- [ ] **LEX-03**: User can search and filter the lexicon by meaning, root, part of speech, or phonetic pattern
- [ ] **LEX-04**: User can reference the built-in Swadesh list to guide core vocabulary creation
- [ ] **LEX-05**: User can reference the integrated Conlanger's Thesaurus for semantic coverage guidance
- [ ] **LEX-06**: User can export vocabulary as Anki .apkg flashcards
- [ ] **LEX-07**: User can generate new words that follow phonotactic constraints

### Morphology

- [ ] **MORPH-01**: User can define morphological rules using a readable pattern mini-language (suffixes, prefixes, infixes, vowel replacements, root templates)
- [ ] **MORPH-02**: The morphology engine handles agglutinative, Semitic triconsonantal, fusional, and analytic language types in one unified system
- [ ] **MORPH-03**: User can define word derivation rules (e.g. -tion, -er, CaCCaaC templates from triconsonantal roots)
- [ ] **MORPH-04**: User can define per-word exceptions to override any morphological rule for irregular forms

### Display & UX Fixes

- [ ] **FIX-01**: IPA vowel chart and phoneme inventory charts render with correct standard IPA shapes (trapezoid vowel chart)
- [ ] **FIX-02**: Word generator displays words as `/romanization/ [phonetics]` (romanization first)
- [ ] **FIX-03**: Anki cards show `/romanization/` on first line, `[IPA]` on second line
- [ ] **FIX-04**: Anki export UI uses an "Export to Anki" button that reveals selection checkboxes on demand, with confirm/cancel
- [ ] **FIX-05**: Phoneme inventory shows romanized form alongside IPA only when holding alt/ctrl modifier key

### Phonology (additional)

- [ ] **PHON-09**: Predefined natural classes (Stop, Liquid, Rhotic, Nasal, Fricative, etc.) with sensible IPA defaults, including sounds outside the project inventory
- [ ] ~~**PHON-10**: Natural classes are shareable across languages (global definitions reusable per project)~~ — **Out of scope (v1)**, user decision 2026-04-10 during Phase 3.2 discussion. Natural classes remain project-local.
- [ ] **PHON-11**: User can click a phoneme to view all contextual allophones based on phonological rules

### Grammar

- [ ] **GRAM-01**: User can define parts of speech categories with N user-defined grammatical dimensions, each with K levels (e.g. gender[M/F] × number[SG/PL] × case[NOM/ACC])
- [ ] **GRAM-02**: User can attach inflectional morphology rules to dimension levels that stack hierarchically with auto-generated combined forms
- [ ] **GRAM-03**: User can generate full paradigm charts (declension/conjugation tables) for any word based on its POS dimensions
- [ ] **GRAM-04**: User can specify language typology choices (ergative/accusative alignment, word order, modality expression as morphological vs analytic)
- [ ] **GRAM-05**: User can override any individual cell in a paradigm table with a manual exception form
- [ ] **GRAM-06**: The standalone Morphology tab is removed; rule editor UI is reused within Grammar (inflectional) and Lexicon (derivational)
- [ ] **GRAM-07**: Existing morphology rules migrate to lexicon derivational rules; derivational rules have a dedicated tab in Lexicon with romanization for all derived forms

### Culture

- [ ] **CULT-01**: User can create and organize wiki-style documentation pages in Markdown format
- [ ] **CULT-02**: User can create internal links between culture pages (wiki-style linking)

### Reference

- [ ] **REF-01**: User can search a built-in glossary of linguistic terminology with definitions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Input & Diacritics

- **DIAC-01**: App-wide compose-key system for common romanization diacritics (e.g. a+macron → ā, h+dot → ḣ)

### Writing System

- **WSYS-01**: Writing system tab for defining and previewing custom scripts/orthographies

### Language Evolution

- **EVOL-01**: Language evolution tools for modeling sound changes and phoneme splits over time
- **EVOL-02**: Allophone-to-phoneme promotion workflow (allophones becoming separate phonemes through evolution)

### Word Preview

- **WPREV-01**: Example paragraph preview in word generator showing generated words in running text

### Writing Scratchpad

- **WRIT-01**: User can write phrases and have them tokenized into morphemes
- **WRIT-02**: User can view auto-generated interlinear glosses for written phrases
- **WRIT-03**: User can see error highlighting for unknown words and rule violations in text
- **WRIT-04**: User can generate IPA transcription of written phrases from phonology rules

### AI Integration

- **AI-01**: AI agent (MCP-powered) acts as linguistics tutor — explains terms, answers questions
- **AI-02**: AI agent acts as co-creator — suggests words, proposes patterns, helps fill paradigms
- **AI-03**: All project data exposed as MCP tools for AI agent access

### Audio

- **TTS-01**: User can hear conlang text read aloud via TTS synthesis with phoneme mapping

### Lexicon Extras

- **LEX-08**: Automatic etymology suggestions (detect compound words, suggest parent roots)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile app | Desktop-first; Flutter allows future expansion but not in scope |
| Collaborative/multi-user editing | Single-user tool — conlanging is a solo creative activity |
| Cloud sync | All data stays local; user preference for offline-first |
| Machine translation | Full natlang-to-conlang translation is AI-complete; out of scope |
| Social/sharing features | ConWorkShop already fills this niche |
| Real-time chat/community | Out of scope — this is a creation tool, not a platform |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROJ-01 | Phase 1 | Pending |
| PROJ-02 | Phase 1 | Pending |
| PROJ-03 | Phase 1 | Pending |
| PHON-01 | Phase 1 | Pending |
| PHON-02 | Phase 1 | Pending |
| PHON-03 | Phase 1 | Pending |
| PHON-04 | Phase 1 | Pending |
| PHON-05 | Phase 3 | Pending |
| PHON-06 | Phase 1 | Pending |
| PHON-07 | Phase 1 | Pending |
| PHON-08 | Phase 1 | Pending |
| LEX-01 | Phase 3 | Pending |
| LEX-02 | Phase 3 | Pending |
| LEX-03 | Phase 3 | Pending |
| LEX-04 | Phase 3 | Pending |
| LEX-05 | Phase 3 | Pending |
| LEX-06 | Phase 3 | Pending |
| LEX-07 | Phase 3 | Pending |
| MORPH-01 | Phase 2 | Pending |
| MORPH-02 | Phase 2 | Pending |
| MORPH-03 | Phase 2 | Pending |
| MORPH-04 | Phase 2 | Pending |
| FIX-01 | Phase 3.1 | Pending |
| FIX-02 | Phase 3.1 | Pending |
| FIX-03 | Phase 3.1 | Pending |
| FIX-04 | Phase 3.1 | Pending |
| FIX-05 | Phase 3.1 | Pending |
| PHON-09 | Phase 3.2 | Pending |
| PHON-10 | — | Out of scope (v1) |
| PHON-11 | Phase 3.2 | Pending |
| GRAM-01 | Phase 4 | Pending |
| GRAM-02 | Phase 4 | Pending |
| GRAM-03 | Phase 4 | Pending |
| GRAM-04 | Phase 4 | Pending |
| GRAM-05 | Phase 4 | Pending |
| GRAM-06 | Phase 4 | Pending |
| GRAM-07 | Phase 4 | Pending |
| CULT-01 | Phase 5 | Pending |
| CULT-02 | Phase 5 | Pending |
| REF-01 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-08 after roadmap creation*
