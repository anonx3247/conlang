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

### Grammar

- [ ] **GRAM-01**: User can define parts of speech categories and their grammatical properties
- [ ] **GRAM-02**: User can define declension and conjugation rules per part of speech using the pattern mini-language
- [ ] **GRAM-03**: User can generate full paradigm charts (declension/conjugation tables) for any word
- [ ] **GRAM-04**: User can specify language typology choices (ergative/accusative alignment, word order, modality expression as morphological vs analytic)

### Culture

- [ ] **CULT-01**: User can create and organize wiki-style documentation pages in Markdown format
- [ ] **CULT-02**: User can create internal links between culture pages (wiki-style linking)

### Reference

- [ ] **REF-01**: User can search a built-in glossary of linguistic terminology with definitions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

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
| PROJ-01 | — | Pending |
| PROJ-02 | — | Pending |
| PROJ-03 | — | Pending |
| PHON-01 | — | Pending |
| PHON-02 | — | Pending |
| PHON-03 | — | Pending |
| PHON-04 | — | Pending |
| PHON-05 | — | Pending |
| PHON-06 | — | Pending |
| PHON-07 | — | Pending |
| PHON-08 | — | Pending |
| LEX-01 | — | Pending |
| LEX-02 | — | Pending |
| LEX-03 | — | Pending |
| LEX-04 | — | Pending |
| LEX-05 | — | Pending |
| LEX-06 | — | Pending |
| LEX-07 | — | Pending |
| MORPH-01 | — | Pending |
| MORPH-02 | — | Pending |
| MORPH-03 | — | Pending |
| MORPH-04 | — | Pending |
| GRAM-01 | — | Pending |
| GRAM-02 | — | Pending |
| GRAM-03 | — | Pending |
| GRAM-04 | — | Pending |
| CULT-01 | — | Pending |
| CULT-02 | — | Pending |
| REF-01 | — | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 0
- Unmapped: 29 ⚠️

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-08 after initial definition*
