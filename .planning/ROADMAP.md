# Roadmap: Conlang Workbench

## Milestones

- ✅ **v1.0 Core Workbench** — Phases 1-9 (shipped 2026-04-13)
- 🚧 **v2.0 Analytic Grammar, Scratchpad & AI** — Phases 10-16 (in progress)

## Phases

<details>
<summary>✅ v1.0 Core Workbench (Phases 1-9) — SHIPPED 2026-04-13</summary>

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
**Plans:** 13 plans

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
  1. User can write a morphological rule in the pattern mini-language and have it applied to a root word to produce the correct derived form
  2. The engine produces correct outputs for at least four typological strategies: concatenative, Semitic root-and-pattern, vowel ablaut, and analytic
  3. User can define word derivation rules that chain with root definitions to produce derived words
  4. Infrastructure complete for per-word exceptions (schema + DAO); UI available in Phase 3
**Plans:** 10 plans

Plans:
- [x] 02-01-PLAN.md — TDD: Morphology DSL data model, petitparser grammar, serializer, and evaluation engine
- [x] 02-02-PLAN.md — Drift schema extension (MorphologicalRules + Exceptions tables, v4 migration), MorphologyDao, providers
- [x] 02-03-PLAN.md — Morphology tab + router, rule editor UI with hybrid authoring
- [x] 02-04-PLAN.md — Checkpoint: end-to-end verification of all typological strategies + UI fixes
- [x] 02-05-PLAN.md — Gap closure: InfixOp DSL parser fix (TDD) + exception UI deferral
- [x] 02-06-PLAN.md — Gap closure: Jargon clarity, IPA keyboards in morphology, preview polish
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
  5. Words that violate phonotactic rules are highlighted in red throughout the entire tool, with an option to mark individual words as exceptions
**Plans:** 6 plans

Plans:
- [x] 03-01-PLAN.md — Data layer: LexemeDao, schema v7 migration, providers, client-side filter, bundled Swadesh + Thesaurus JSON assets
- [x] 03-02-PLAN.md — Dictionary UI: master-detail layout, word list panel, word detail panel, creation form, derivation tree
- [x] 03-03-PLAN.md — Semantic references: Swadesh list checklist with coverage progress, Thesaurus hierarchical tree browser
- [x] 03-04-PLAN.md — Anki export: .apkg builder with sqlite3 + archive, selection checkboxes, export flow
- [x] 03-05-PLAN.md — Phonotactic highlighting infrastructure: shared ViolationText widget extraction, validation provider
- [x] 03-06-PLAN.md — Phonotactic highlighting wiring: ViolationText into lexicon detail/list, per-word exception toggle

### Phase 3.1: Display & UX Fixes INSERTED
**Goal**: Fix visual and UX issues from phases 1–3: IPA chart shapes, word display format, Anki export UX, and romanization visibility toggle
**Depends on**: Phase 3
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05
**Success Criteria** (what must be TRUE):
  1. IPA vowel chart and phoneme inventory charts render with correct trapezoid/triangular shapes matching standard IPA layout
  2. Word generator shows words as romanization first (IPA in brackets)
  3. Anki cards show romanization on one line then IPA below
  4. Anki export UI shows an "Export to Anki" button with confirm/cancel flow
  5. Phoneme inventory shows romanized form by default
**Plans:** 4 plans

Plans:
- [x] 03.1-01-PLAN.md — IPA trapezoid vowel chart: CustomPaint trapezoid for reference panel and inventory vowel grid
- [x] 03.1-02-PLAN.md — Word display format fixes: romanization-first in word generator and Anki card front field
- [x] 03.1-03-PLAN.md — Anki export selection mode: toolbar button, conditional checkboxes, bottom bar confirm/cancel
- [x] 03.1-04-PLAN.md — Phoneme inventory romanization toggle: Alt-key listener, romanization default display

### Phase 3.2: Phonology Enhancements INSERTED
**Goal**: Predefined natural classes with sensible IPA defaults and a contextual allophone viewer that surfaces phoneme realizations from existing rewrite rules
**Depends on**: Phase 3.1
**Requirements**: PHON-09, PHON-11
**Success Criteria** (what must be TRUE):
  1. Predefined natural classes (Stop/S, Liquid/L, Rhotic/R, Nasal/N, Fricative/F, Obstruent/Sonorant/Approximant/Affricate) ship as hardcoded defaults with IPA members and resolve in the existing DSL
  2. User can click a phoneme in the inventory and see its contextual allophones listed in the phoneme dialog
**Plans:** 4 plans

Plans:
- [x] 03.2-01-PLAN.md — Default natural classes catalog + `_buildInventory` merge with user precedence
- [x] 03.2-02-PLAN.md — Alias-first resolver in word_generator + morphology_engine + validator extension
- [x] 03.2-03-PLAN.md — Allophone computation module (pure function + data class) + derived Riverpod provider
- [x] 03.2-04-PLAN.md — Phoneme dialog Allophones section + Alt-held inline chip suffix + human verification

### Phase 4: Grammar & Morphology
**Goal**: Users can define grammatical structure through N-dimensional feature systems per part of speech, with inflectional morphology rules organized by those dimensions and paradigm generation
**Depends on**: Phase 3.2
**Requirements**: GRAM-01, GRAM-02, GRAM-03, GRAM-04, GRAM-05, GRAM-06, GRAM-07
**Success Criteria** (what must be TRUE):
  1. User can define custom parts of speech with N grammatical dimensions, each with K levels
  2. User can attach inflectional morphology rules to dimension levels that stack hierarchically
  3. User can override any cell in the paradigm table with a manual exception form
  4. User can select any word from the lexicon and view a fully generated paradigm chart
  5. User can record language-level typology choices (alignment, word order, modality expression strategy)
  6. The standalone Morphology tab is removed; its rule editor UI is reused within Grammar and Lexicon
  7. Existing morphology rules are migrated to lexicon derivational rules
**Plans:** 25 plans

### Phase 5: Culture Wiki
**Goal**: Users can document the world and culture behind their conlang in a structured wiki with Markdown formatting and navigable internal links between pages
**Depends on**: Phase 1
**Requirements**: CULT-01, CULT-02
**Success Criteria** (what must be TRUE):
  1. User can create, edit, and organize Markdown-formatted documentation pages within their project, with rendered preview
  2. User can create internal links between culture pages and navigate the link graph — broken links are visually distinct from resolved ones
**Plans:** 4 plans

### Phase 6: Reference Glossary
**Goal**: Users can look up unfamiliar linguistic terminology without leaving the application
**Depends on**: Phase 1
**Requirements**: REF-01
**Success Criteria** (what must be TRUE):
  1. User can open the built-in glossary, search for a linguistic term, and read a clear definition without leaving the app
  2. Glossary entries for terms relevant to current context are accessible from those tabs
**Plans:** 2 plans

### Phase 7: Polish & Refactor
**Goal**: Fix all outstanding UI nits, clean up dead code from culture wiki removal, and refactor oversized files
**Depends on**: Phase 6
**Requirements**: NIT-01, NIT-02, NIT-03, NIT-04, NIT-05, REFAC-01
**Success Criteria** (what must be TRUE):
  1. Natural classes moved to their own Phonology sub-tab
  2. Phoneme inventory charts show /phoneme/ next to romanization (only when they differ)
  3. Romanization section appears below phoneme inventory (not separate sub-tab)
  4. Abbreviations are case-insensitive and display with trailing period
  5. Dead code from culture wiki removal is cleaned up
  6. rule_editor_dialog.dart split into smaller focused files
**Plans:** 6 plans

### Phase 8: Gemination Restrictions
**Goal**: Users can define gemination restrictions as phonotactic constraints — prevent geminate consonants globally, positionally, or selectively
**Depends on**: Phase 7
**Requirements**: GEM-01
**Success Criteria** (what must be TRUE):
  1. User can add a "no gemination" constraint with position options
  2. Word generator respects gemination constraints
  3. Phonotactic violation highlighting flags geminate violations
**Plans:** TBD

### Phase 9: Platform Polish
**Goal**: Move File menu to macOS native menu bar, add project management features, fix app name, and create app logo
**Depends on**: Phase 8
**Requirements**: PLAT-01, PLAT-02, PLAT-03
**Success Criteria** (what must be TRUE):
  1. File/Edit/View menus appear in macOS global menu bar
  2. User can rename a project
  3. User can "Save as" to duplicate a project
  4. Projects stored as .conlang files in user-chosen locations
  5. App name shows "Conlang Workbench" everywhere
  6. App has a custom logo/icon
**Plans:** 3 plans

Plans:
- [ ] 09-01-PLAN.md — App identity: macOS PRODUCT_NAME fix, SVG-to-PNG icon generation, .conlang file type registration
- [x] 09-02-PLAN.md — Project data layer overhaul: Project model filePath field, registry .conlang support, providers refactor, recent projects service
- [x] 09-03-PLAN.md — PlatformMenuBar in app.dart, welcome screen with logo + recent projects, remove in-app File button

</details>

---

## v2.0 Analytic Grammar, Scratchpad & AI (In Progress)

**Milestone Goal:** Extend the workbench beyond morphological tools into phrase-level grammar, text composition with live analysis, AI-assisted conlanging, custom script support, and language evolution modeling.

### Phase 10: Analytic Grammar
**Goal**: Users can define the closed-class word inventory and phrase-level construction rules that govern how particles, auxiliaries, and determiners combine with content words
**Depends on**: Phase 9
**Requirements**: AGRAM-01, AGRAM-02, AGRAM-03
**Success Criteria** (what must be TRUE):
  1. User can define closed-class words (particles, auxiliaries, prepositions, determiners, conjunctions) with grammatical gloss tags (DEF, NEG, PROG, FUT, etc.) in a dedicated sub-tab, separate from content words in the main lexicon
  2. User can define named phrase construction rules with ordered slots (e.g. "negation = NEG + V", "future = AUX:FUT + V") that encode how analytic forms express grammatical meaning
  3. User can specify structured word order patterns (basic order SVO/SOV/etc., head-directionality, adposition placement) as project-level typology settings
  4. Analytic particles appear in unified lexicon search and Anki export — they are not siloed from the main word list
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [ ] 10-01-PLAN.md — Schema v15 migration (isClosedClass + glossTag + PhraseConstructions + ConstructionSlots), Grammar sidebar 5 items, GoRouter branches, placeholder pages
- [ ] 10-02-PLAN.md — Particles page: POS-grouped closed-class word list, add/edit/delete dialogs, Leipzig gloss tag autocomplete
- [ ] 10-03-PLAN.md — Constructions page: master-detail layout, visual slot editor with drag-and-drop, live preview with real words
- [ ] 10-04-PLAN.md — Typology page extension: Word Order section with head-directionality, adposition type, adjective/genitive placement dropdowns

### Phase 11: Lexicon Etymology Chain
**Goal**: Users can see the full derivational history of any word as a visual lineage display tracing root through derived forms to compounds
**Depends on**: Phase 10
**Requirements**: LEX-09
**Success Criteria** (what must be TRUE):
  1. User can open any word in the lexicon and view its complete etymology chain (root → derived → compound) as a visual lineage tree, not just a text field
  2. The lineage display is navigable — clicking any node in the chain opens that word's detail panel
**Plans**: TBD
**UI hint**: yes

### Phase 12: Writing Scratchpad
**Goal**: Users can compose phrases in their conlang and receive automatic interlinear glossing, IPA transcription, and error highlighting without leaving the app
**Depends on**: Phase 10
**Requirements**: WRIT-01, WRIT-02, WRIT-03, WRIT-04
**Success Criteria** (what must be TRUE):
  1. User can type a phrase in their conlang and see it automatically tokenized into morphemes with Leipzig-format interlinear gloss (original line / morpheme gloss line / free translation line)
  2. Unknown tokens display as "?" in the gloss line; words violating phonotactics or grammar rules are highlighted as errors — the scratchpad shows honest parsing gaps, not silent failures
  3. User can generate an IPA transcription line for any written phrase by applying the project's phonology rules
  4. User can enter a free translation beneath each glossed phrase and save it as part of the phrase record
**Plans**: TBD
**UI hint**: yes

### Phase 13: Writing System
**Goal**: Users can define their conlang's orthography or custom script with grapheme-to-phoneme mapping, custom font rendering, and script preview in the scratchpad
**Depends on**: Phase 12
**Requirements**: WSYS-01, WSYS-02, WSYS-03
**Success Criteria** (what must be TRUE):
  1. User can define orthography rules mapping graphemes to phoneme sequences, with priority ordering and context-sensitive rules, covering diverse script types (alphabet, abjad, syllabary, abugida)
  2. User can load a custom .ttf or .otf font file and preview text rendered in that font within the app — no external tool required for basic script display
  3. Scratchpad phrases render a third interlinear tier showing the text in the custom script alongside the romanization and IPA lines
**Plans**: TBD
**UI hint**: yes

### Phase 14: AI / MCP Integration
**Goal**: An MCP server auto-starts with the app, exposing all project data as structured tools so external AI clients and in-app workflows can query and interact with the language
**Depends on**: Phase 13
**Requirements**: AI-01, AI-02
**Success Criteria** (what must be TRUE):
  1. When the app launches, an MCP server starts automatically and exposes phoneme inventory, lexicon, grammar rules, morphology patterns, and culture wiki as named read-only MCP tools
  2. An external MCP client (Claude Desktop, claude CLI) can connect to the running server, call tools like `search_lexicon` or `get_paradigm_table`, and receive accurate structured data from the current project
**Plans**: TBD

### Phase 15: Language Evolution — Sound Changes
**Goal**: Users can define ordered sound change rules and apply them to the full lexicon with a before/after diff preview, and can promote allophones to full phonemes with guided inventory updates
**Depends on**: Phase 14
**Requirements**: EVOL-01, EVOL-02
**Success Criteria** (what must be TRUE):
  1. User can define a named set of ordered, context-sensitive sound change rules and apply them to the entire lexicon — a diff view shows every affected word with its original and evolved IPA form before any change is committed
  2. Sound changes are non-destructive: original lexeme IPA is never overwritten; evolved forms are computed from a stored rule stack and can be rolled back by removing rules
  3. User can select an allophone from the phonological rules and promote it to a full phoneme, with the app guiding updates to the inventory, affected rewrite rules, and lexicon entries where the phoneme now contrasts
**Plans**: TBD

### Phase 16: Language Evolution — Diachronic Modeling
**Goal**: Users can model the broader historical arc of their language — phoneme mergers, grammatical drift, and family tree relationships between parent and daughter languages
**Depends on**: Phase 15
**Requirements**: EVOL-03
**Success Criteria** (what must be TRUE):
  1. User can define phoneme merger events (two phonemes collapse into one) and see lexicon-wide impact — which words change pronunciation, which minimal pairs are lost
  2. User can record grammatical evolution events (e.g. analytic → agglutinative shift, loss of a case) as timestamped notes with links to affected grammar rules and lexicon changes
  3. User can create a language family tree showing how daughter languages descend from a parent language, with branching points annotated with the sound changes or innovations that define each split
**Plans**: TBD

---

## Progress

**Execution Order:**
v1.0 phases complete. v2.0 executes: 10 → 11 → 12 → 13 → 14 → 15 → 16

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 13/13 | Complete | 2026-04-09 |
| 2. Morphology Engine | v1.0 | 10/10 | Complete | 2026-04-09 |
| 3. Lexicon | v1.0 | 6/6 | Complete | 2026-04-09 |
| 3.1 Display & UX Fixes | v1.0 | 4/4 | Complete | 2026-04-10 |
| 3.2 Phonology Enhancements | v1.0 | 4/4 | Complete | 2026-04-10 |
| 4. Grammar & Morphology | v1.0 | 25/25 | Complete | 2026-04-12 |
| 5. Culture Wiki | v1.0 | 4/4 | Complete | 2026-04-13 |
| 6. Reference Glossary | v1.0 | 2/2 | Complete | 2026-04-12 |
| 7. Polish & Refactor | v1.0 | 6/6 | Complete | 2026-04-13 |
| 8. Gemination Restrictions | v1.0 | TBD | Complete | 2026-04-13 |
| 9. Platform Polish | v1.0 | 3/3 | Complete | 2026-04-13 |
| 10. Analytic Grammar | v2.0 | 0/4 | Planned | - |
| 11. Lexicon Etymology Chain | v2.0 | 0/? | Not started | - |
| 12. Writing Scratchpad | v2.0 | 0/? | Not started | - |
| 13. Writing System | v2.0 | 0/? | Not started | - |
| 14. AI / MCP Integration | v2.0 | 0/? | Not started | - |
| 15. Language Evolution — Sound Changes | v2.0 | 0/? | Not started | - |
| 16. Language Evolution — Diachronic Modeling | v2.0 | 0/? | Not started | - |
