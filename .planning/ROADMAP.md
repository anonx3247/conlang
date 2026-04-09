# Roadmap: Conlang Workbench

## Overview

Conlang Workbench is built from the inside out: the morphology engine — the architectural centrepiece — is established before any feature that depends on it. Foundation work (project shell, phonology tools, database schema) comes first because every subsequent phase writes data into it. Lexicon and grammar follow once the engine is proven, and the culture wiki rounds out the tool as a self-contained offline conlanging environment.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Flutter app shell, project management, phonology tools, and derivation-aware database schema
- [ ] **Phase 2: Morphology Engine** - Pattern mini-language, plugin architecture, and rule editor — the centrepiece differentiator
- [ ] **Phase 3: Lexicon** - Root and derived-word dictionary, search, semantic references, Anki export, phonotactic highlighting
- [ ] **Phase 4: Grammar** - Parts of speech, declension/conjugation rules, paradigm chart generation, typology settings
- [ ] **Phase 5: Culture Wiki** - Markdown wiki with internal linking for world-building documentation
- [ ] **Phase 6: Reference & Polish** - Built-in linguistic glossary and cross-cutting quality pass

## Phase Details

### Phase 1: Foundation
**Goal**: Users can create and manage conlang projects with a working phonology toolset and a correct database schema that supports non-concatenative morphology from the start
**Depends on**: Nothing (first phase)
**Requirements**: PROJ-01, PROJ-02, PROJ-03, PHON-01, PHON-02, PHON-03, PHON-04, PHON-06, PHON-07, PHON-08
**Success Criteria** (what must be TRUE):
  1. User can create a new conlang project, open it, switch to another project, and delete one — each project's data is isolated in its own SQLite database folder
  2. User can define a phoneme inventory with IPA symbols and articulation properties, and hear real audio recordings for any phoneme by clicking the IPA reference chart
  3. User can enter IPA text using the on-screen IPA keyboard without switching input methods
  4. User can define phonotactic syllable structure rules and phonological rules (e.g. vowel assimilation), then use the word generator to produce random words that conform to those rules
  5. User can define a romanization mapping so any IPA transcription can be displayed in the project's chosen Latin script
**Plans:** 7 plans in 4 waves

Plans:
- [x] 01-01-PLAN.md — App shell: Flutter project init, dependencies, window setup, go_router tabs+sidebar navigation
- [x] 01-02-PLAN.md — Project management: create/open/delete/switch projects, ProjectRegistry, per-project Drift database with derivation-aware schema
- [x] 01-03-PLAN.md — IPA reference chart: bundled OGG audio assets, persistent side panel with clickable playback
- [x] 01-04-PLAN.md — IPA keyboard: OverlayPortal popup widget for IPA text input throughout the app
- [x] 01-05-PLAN.md — Phoneme inventory editor: CRUD for consonants/vowels, articulation properties, natural class management
- [x] 01-06-PLAN.md — Romanization mappings: IPA-to-Latin mapping editor with live preview and conversion function
- [x] 01-07-PLAN.md — Phonotactic rules + word generator: petitparser DSL for syllable templates, live word generation preview

### Phase 2: Morphology Engine
**Goal**: Users can express any word transformation rule — concatenative, templatic, ablaut, or suppletive — in a readable pattern mini-language, and the engine applies those rules consistently
**Depends on**: Phase 1
**Requirements**: MORPH-01, MORPH-02, MORPH-03, MORPH-04
**Success Criteria** (what must be TRUE):
  1. User can write a morphological rule in the pattern mini-language (e.g. a suffix, an infix, a triconsonantal CaCCaaC template) and have it applied to a root word to produce the correct derived form
  2. The engine produces correct outputs for at least four typological strategies: concatenative (affix), Semitic root-and-pattern (template), vowel ablaut, and analytic (particle/aux verb, defined as a no-transform passthrough)
  3. User can define word derivation rules (e.g. denominalizer, agentive) that chain with root definitions to produce derived words
  4. User can mark any individual word as an exception to any morphological rule and supply the irregular form directly
**Plans**: TBD

Plans:
- [ ] 02-01: Pattern mini-language design spike — one-page spec, PEG grammar (petitparser), AST node types for AFFIX / TEMPLATE / ABLAUT / LOOKUP
- [ ] 02-02: Morphology engine core — lexer, parser, AST-to-bytecode compiler, runtime evaluator with plugin dispatch
- [ ] 02-03: Plugin implementations — concatenative, Semitic template, ablaut/vowel-change, reduplication, suppletive lookup
- [ ] 02-04: MorphologyRepository and rule editor UI — CRUD for rules, per-word exception overrides, live preview of rule output

### Phase 3: Lexicon
**Goal**: Users can build and navigate a root-and-derived-word dictionary with full search, semantic coverage guidance, flashcard export, and inline phonotactic validation throughout the interface
**Depends on**: Phase 2
**Requirements**: LEX-01, LEX-02, LEX-03, LEX-04, LEX-05, LEX-06, LEX-07, PHON-05
**Success Criteria** (what must be TRUE):
  1. User can add, edit, and delete root words with meaning, part of speech, and IPA transcription; derived words generated by morphology rules appear automatically with their etymology chain visible
  2. User can search and filter the lexicon by meaning, root, part of speech, or phonetic pattern and get results instantly even in a large dictionary
  3. User can open the Swadesh list view and the Conlanger's Thesaurus reference to identify semantic gaps and guide vocabulary creation
  4. User can export selected lexicon entries as Anki .apkg flashcards with morphological context in the card fields
  5. Words that violate phonotactic rules are highlighted in red throughout the entire tool (lexicon, grammar tables, and any text field), with an option to mark individual words as exceptions
**Plans**: TBD

Plans:
- [ ] 03-01: LexiconRepository — root words table, derived forms cache (root_id, rule_ids, computed_form), FTS5 full-text search, etymology chain
- [ ] 03-02: Lexicon UI — root dictionary view, word detail panel, derivation tree display, search and filter bar
- [ ] 03-03: Semantic references — bundled Swadesh list view with coverage indicators, Conlanger's Thesaurus integration (pre-extracted JSON from PDF)
- [ ] 03-04: Anki export — .apkg builder with morphological context fields, export flow
- [ ] 03-05: Phonotactic violation highlighting — PhonologyEngine compiled DFA, red highlight widget, per-word exception toggle

### Phase 4: Grammar
**Goal**: Users can define the grammatical structure of their language — parts of speech, inflection rules, and typological choices — and generate complete paradigm charts for any word
**Depends on**: Phase 3
**Requirements**: GRAM-01, GRAM-02, GRAM-03, GRAM-04
**Success Criteria** (what must be TRUE):
  1. User can define custom parts of speech categories with their grammatical feature dimensions (e.g. case, number, tense) as user-defined data, not a fixed list
  2. User can write declension and conjugation rules using the pattern mini-language and attach them to a part of speech
  3. User can select any word from the lexicon and view a fully generated paradigm chart (all inflected forms in a table) with per-cell exception support
  4. User can record language-level typology choices — alignment (ergative/accusative), word order, and modality expression strategy (morphological vs analytic) — and these choices are documented and accessible throughout the tool
**Plans**: TBD

Plans:
- [ ] 04-01: GrammarRepository — user-defined POS categories, feature dimension definitions, typology settings storage
- [ ] 04-02: GrammarService — paradigm generation (feature matrix × morphology engine), per-cell exception handling
- [ ] 04-03: Grammar UI — POS editor, feature dimension editor, typology settings panel, paradigm chart view

### Phase 5: Culture Wiki
**Goal**: Users can document the world and culture behind their conlang in a structured wiki with Markdown formatting and navigable internal links between pages
**Depends on**: Phase 1
**Requirements**: CULT-01, CULT-02
**Success Criteria** (what must be TRUE):
  1. User can create, edit, and organize Markdown-formatted documentation pages within their project, with rendered preview
  2. User can create [[wiki-style]] internal links between culture pages and navigate the link graph — broken links are visually distinct from resolved ones
**Plans**: TBD

Plans:
- [ ] 05-01: CultureRepository and CultureService — page CRUD, internal link resolution, document graph
- [ ] 05-02: Culture UI — Markdown editor with flutter_markdown, [[link]] inline syntax extension, page list and navigation

### Phase 6: Reference Glossary
**Goal**: Users can look up unfamiliar linguistic terminology without leaving the application
**Depends on**: Phase 1
**Requirements**: REF-01
**Success Criteria** (what must be TRUE):
  1. User can open the built-in glossary, search for a linguistic term (e.g. "ergative", "allophone", "paradigm"), and read a clear definition without leaving the app
  2. Glossary entries for terms relevant to current context (morphology, phonology, grammar) are accessible from those tabs
**Plans**: TBD

Plans:
- [ ] 06-01: Linguistic glossary — bundled terminology dataset, searchable glossary UI, contextual access from relevant tabs

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4. Phases 5 and 6 depend only on Phase 1 and can be done at any point after Phase 1 completes.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 7/7 | ✓ Complete | 2026-04-08 |
| 2. Morphology Engine | 0/4 | Not started | - |
| 3. Lexicon | 0/5 | Not started | - |
| 4. Grammar | 0/3 | Not started | - |
| 5. Culture Wiki | 0/2 | Not started | - |
| 6. Reference Glossary | 0/1 | Not started | - |
