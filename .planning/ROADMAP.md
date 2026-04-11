# Roadmap: Conlang Workbench

## Overview

Conlang Workbench is built from the inside out: the morphology engine — the architectural centrepiece — is established before any feature that depends on it. Foundation work (project shell, phonology tools, database schema) comes first because every subsequent phase writes data into it. Lexicon and grammar follow once the engine is proven, and the culture wiki rounds out the tool as a self-contained offline conlanging environment.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Flutter app shell, project management, phonology tools, and derivation-aware database schema
- [x] **Phase 2: Morphology Engine** - Pattern mini-language, plugin architecture, and rule editor — the centrepiece differentiator
- [x] **Phase 3: Lexicon** - Root and derived-word dictionary, search, semantic references, Anki export, phonotactic highlighting
- [x] **Phase 3.1: Display & UX Fixes** - IPA chart shapes, word display format, Anki export UX, romanization toggle (INSERTED)
- [x] **Phase 3.2: Phonology Enhancements** - Predefined natural classes with IPA defaults, contextual allophone viewer (INSERTED)
- [ ] **Phase 4: Grammar & Morphology** - Dimensional POS features, inflectional rules, paradigm generation, morphology tab merge (revised)
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
**Plans:** 13 plans in 6 waves

Plans:
- [x] 01-01-PLAN.md — App shell: Flutter project init, dependencies, window setup, go_router tabs+sidebar navigation
- [x] 01-02-PLAN.md — Project management: create/open/delete/switch projects, ProjectRegistry, per-project Drift database with derivation-aware schema
- [x] 01-03-PLAN.md — IPA reference chart: bundled OGG audio assets, persistent side panel with clickable playback
- [x] 01-04-PLAN.md — IPA keyboard: OverlayPortal popup widget for IPA text input throughout the app
- [x] 01-05-PLAN.md — Phoneme inventory editor: CRUD for consonants/vowels, articulation properties, natural class management
- [x] 01-06-PLAN.md — Romanization mappings: IPA-to-Latin mapping editor with live preview and conversion function
- [x] 01-07-PLAN.md — Phonotactic rules + word generator: petitparser DSL for syllable templates, live word generation preview
- [x] 01-08-PLAN.md — Gap closure: IPA keyboard popup fix, template editor fix, IPA chart overflow, constraint docs
- [x] 01-09-PLAN.md — Gap closure: Phoneme dialog redesign (feature-driven IPA, delete button), romanization Latin-first flip
- [x] 01-10-PLAN.md — Gap closure: IPA keyboard popup re-fix (blocker) and audio preview on symbol tap
- [x] 01-11-PLAN.md — Gap closure: Single Add Phoneme button, reverse IPA symbol derivation
- [x] 01-12-PLAN.md — Gap closure: Bidirectional phoneme-romanization sync, project-level toggle
- [x] 01-13-PLAN.md — Gap closure: Phonological rewrite rules (A -> B / C_D) DSL and editor

### Phase 2: Morphology Engine
**Goal**: Users can express any word transformation rule — concatenative, templatic, ablaut, or suppletive — in a readable pattern mini-language, and the engine applies those rules consistently
**Depends on**: Phase 1
**Requirements**: MORPH-01, MORPH-02, MORPH-03, MORPH-04
**Success Criteria** (what must be TRUE):
  1. User can write a morphological rule in the pattern mini-language (e.g. a suffix, an infix, a triconsonantal CaCCaaC template) and have it applied to a root word to produce the correct derived form
  2. The engine produces correct outputs for at least four typological strategies: concatenative (affix), Semitic root-and-pattern (template), vowel ablaut, and analytic (particle/aux verb, defined as a no-transform passthrough)
  3. User can define word derivation rules (e.g. denominalizer, agentive) that chain with root definitions to produce derived words
  4. ~~User can mark any individual word as an exception to any morphological rule and supply the irregular form directly~~ — **Infrastructure complete (schema + DAO); UI deferred to Phase 3** where word detail pages provide the natural entry point for per-word exception management (per CONTEXT.md: "Exceptions entered from the word")
**Plans:** 10 plans in 5 waves (4 core + 6 gap closure)

Plans:
- [x] 02-01-PLAN.md — TDD: Morphology DSL data model, petitparser grammar, serializer, and evaluation engine (all 7 operation types + branching conditions)
- [x] 02-02-PLAN.md — Drift schema extension (MorphologicalRules + Exceptions tables, v4 migration), MorphologyDao, Riverpod providers
- [x] 02-03-PLAN.md — Morphology tab + router, rule editor UI with hybrid authoring (structured form + live DSL + preview panel)
- [x] 02-04-PLAN.md — Checkpoint: end-to-end verification of all typological strategies + UI fixes
- [x] 02-05-PLAN.md — Gap closure: InfixOp DSL parser fix (TDD) + exception UI deferral to Phase 3
- [x] 02-06-PLAN.md — Gap closure: Jargon clarity, IPA keyboards in morphology, preview polish (font + regen)
- [x] 02-07-PLAN.md — Gap closure: Rule reordering with up/down buttons and DAO swap
- [x] 02-08-PLAN.md — Gap closure: Parts of Speech definitions + POS-based rule filtering
- [x] 02-09-PLAN.md — Gap closure: Condition pattern redesign (position dropdown + phonological notation)
- [x] 02-10-PLAN.md — Gap closure: Preview enhancements (phonotactic violation highlighting + multi-rule stacking)

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
**Plans:** 6 plans in 3 waves

Plans:
- [x] 03-01-PLAN.md — Data layer: LexemeDao, schema v7 migration, providers, client-side filter, bundled Swadesh + Thesaurus JSON assets
- [x] 03-02-PLAN.md — Dictionary UI: master-detail layout, word list panel, word detail panel, creation form, derivation tree (on-the-fly engine), inspiration panel, exception UI, query param handling for D-16
- [x] 03-03-PLAN.md — Semantic references: Swadesh list checklist with coverage progress, Thesaurus hierarchical tree browser with search
- [x] 03-04-PLAN.md — Anki export: .apkg builder with sqlite3 + archive, selection checkboxes, export flow with snackbar confirmation
- [x] 03-05-PLAN.md — Phonotactic highlighting infrastructure: shared ViolationText widget extraction, validation provider
- [x] 03-06-PLAN.md — Phonotactic highlighting wiring: ViolationText into lexicon detail/list, per-word exception toggle, batch validation provider

### Phase 3.1: Display & UX Fixes INSERTED
**Goal**: Fix visual and UX issues from phases 1–3: IPA chart shapes, word display format, Anki export UX, and romanization visibility toggle
**Depends on**: Phase 3
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05
**Success Criteria** (what must be TRUE):
  1. IPA vowel chart and phoneme inventory charts render with correct trapezoid/triangular shapes matching standard IPA layout
  2. Word generator shows words as `romanization [IPA]` (romanization first, IPA in brackets)
  3. Anki cards show `romanization` on one line then `[IPA]` below — not `[IPA] romanization`
  4. Anki export UI shows an "Export to Anki" button; selection checkboxes only appear after pressing it, with a confirm/cancel flow
  5. Phoneme inventory shows romanized form (e.g. th, sh) by default, IPA in /slashes/ only when holding Alt/Option
**Plans:** 4 plans in 2 waves

Plans:
- [x] 03.1-01-PLAN.md — IPA trapezoid vowel chart: CustomPaint trapezoid for reference panel and inventory vowel grid
- [x] 03.1-02-PLAN.md — Word display format fixes: romanization-first in word generator and Anki card front field
- [x] 03.1-03-PLAN.md — Anki export selection mode: toolbar button, conditional checkboxes, bottom bar confirm/cancel
- [x] 03.1-04-PLAN.md — Phoneme inventory romanization toggle: Alt-key listener, romanization default display

### Phase 3.2: Phonology Enhancements INSERTED
**Goal**: Predefined natural classes with sensible IPA defaults (including sounds outside a project's inventory), and a contextual allophone viewer that surfaces phoneme realizations from existing rewrite rules
**Depends on**: Phase 3.1
**Requirements**: PHON-09, PHON-11 (PHON-10 descoped from v1 per user decision 2026-04-10)
**Success Criteria** (what must be TRUE):
  1. Predefined natural classes (Stop/S, Liquid/L, Rhotic/R, Nasal/N, Fricative/F, plus Obstruent/Sonorant/Approximant/Affricate) ship as hardcoded defaults with IPA members and can include sounds not in the project's phoneme inventory. Defaults resolve in the existing DSL wherever a `[class]` reference is allowed.
  2. User can click a phoneme in the inventory and see its contextual allophones listed in the phoneme dialog. When holding Alt (which already toggles IPA display), each phoneme chip in the consonant/vowel grids shows its allophones inline next to the IPA form.
**Plans:** 4 plans in 4 waves

Plans:
- [x] 03.2-01-PLAN.md — Default natural classes catalog + `_buildInventory` merge with user precedence (PHON-09 foundation)
- [x] 03.2-02-PLAN.md — Alias-first resolver in word_generator + morphology_engine + validator extension + end-to-end DSL test (PHON-09 completion)
- [x] 03.2-03-PLAN.md — Allophone computation module (pure function + data class) + derived Riverpod provider (PHON-11 engine)
- [x] 03.2-04-PLAN.md — Phoneme dialog Allophones section + Alt-held inline chip suffix + human verification (PHON-11 UI)

### Phase 4: Grammar & Morphology (revised)
**Goal**: Users can define grammatical structure through N-dimensional feature systems per part of speech, with inflectional morphology rules organized by those dimensions and paradigm generation — the current Morphology tab merges into Grammar, and derivational morphology moves to Lexicon
**Depends on**: Phase 3.2
**Requirements**: GRAM-01, GRAM-02, GRAM-03, GRAM-04, GRAM-05, GRAM-06, GRAM-07
**Success Criteria** (what must be TRUE):
  1. User can define custom parts of speech with N grammatical dimensions, each with K levels (e.g. noun: gender[M/F] × number[SG/PL] × case[NOM/ACC/...])
  2. User can attach inflectional morphology rules to dimension levels that stack hierarchically (e.g. gender suffix + number suffix), with the combined output auto-generated
  3. User can override any cell in the paradigm table with a manual exception form
  4. User can select any word from the lexicon and view a fully generated paradigm chart (all inflected forms in a dimension-based table)
  5. User can record language-level typology choices (alignment, word order, modality expression strategy)
  6. The standalone Morphology tab is removed; its rule editor UI is reused within Grammar (inflectional) and Lexicon (derivational)
  7. Existing morphology rules are migrated to lexicon derivational rules; derivational rules appear in a "Derivations" tab within Lexicon with romanization for all derived forms
**Plans:** 7 plans in 7 waves (split during plan-check revision — the original monolithic 04-04 Grammar UI plan was subdivided into 04-04/04-05/04-06 for scope; original 04-05 Lexicon Derivations renumbered to 04-07)

Plans:
- [ ] 04-01-PLAN.md — Schema v8 migration: Dimensions + ParadigmCellOverrides tables, kind/featureBindings/input/outputPosId columns, file-level v7 backup, FeatureBindings TypeConverter
- [ ] 04-02-PLAN.md — Grammar data layer: dimension template catalog (20+), GrammarDao for Dimensions CRUD, kind-aware MorphologyDao extensions, posForLexeme resolver
- [ ] 04-03-PLAN.md — Paradigm engine: feature-consumption algorithm (D-10/D-11), tiebreak detector, typology + paradigm-axes providers, computedInflectedParadigmProvider
- [ ] 04-04-PLAN.md — Grammar shell + POS page + Typology: router surgery (delete Morphology tab), Grammar shell with 4 sub-tabs, POS+Dimensions master-detail page with template picker, migration banner, Typology form
- [ ] 04-05-PLAN.md — Inflectional rule editor: kind-aware RuleEditorDialog with FilterChip dimension picker, mandatory live tiebreak banner integration test, InflectionalRulesPage filter
- [ ] 04-06-PLAN.md — Paradigm Viewer: ParadigmTableWidget with D-25 tabs/dropdown affordance for 3+ dimension POS, per-cell ViolationText wiring, amber override rendering, CellOverrideDialog, CoverageMatrixPanel, ParadigmCellOverrideDao, AxisConfigBar
- [ ] 04-07-PLAN.md — Lexicon Derivations: 4th sidebar tab, DerivationsPage reusing RulesPage(kind=derivational), computedDerivedFormsProvider kind filter (pitfall #9), word detail paradigm embed

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
Phases execute in numeric order: 1 -> 2 -> 3 -> 4. Phases 5 and 6 depend only on Phase 1 and can be done at any point after Phase 1 completes.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 13/13 | Complete | 2026-04-09 |
| 2. Morphology Engine | 10/10 | Complete | 2026-04-09 |
| 3. Lexicon | 6/6 | Complete | 2026-04-09 |
| 3.1 Display & UX Fixes | 0/4 | Not started | - |
| 3.2 Phonology Enhancements | 0/4 | Not started | - |
| 4. Grammar & Morphology | 0/5 | Planned | - |
| 5. Culture Wiki | 0/2 | Not started | - |
| 6. Reference Glossary | 0/1 | Not started | - |
