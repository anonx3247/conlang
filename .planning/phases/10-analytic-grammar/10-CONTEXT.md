# Phase 10: Analytic Grammar - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the closed-class word inventory, phrase-level construction rules, and expanded word order settings. It gives users the tools to define how particles, auxiliaries, determiners, and other function words combine with content words to express grammatical meaning analytically (rather than through morphology).

</domain>

<decisions>
## Implementation Decisions

### Closed-Class Inventory
- **D-01:** Closed-class words are edited in a new **"Particles"** sub-tab in the Grammar sidebar, separate from the main Lexicon dictionary
- **D-02:** Closed-class words are stored in the **same Lexemes table** with a boolean/category flag distinguishing them from content words — unified search, Anki export, and phonotactic validation work automatically
- **D-03:** Each closed-class word carries **one gloss tag** (e.g. DEF, NEG, PROG, FUT). If a particle serves multiple functions, create separate entries
- **D-04:** Gloss tags use a **predefined catalog of common Leipzig glossing abbreviations** (DEF, PROG, PST, NEG, etc.) as suggestions, but the user can also enter custom tags
- **D-05:** Closed-class words **still carry a POS** (e.g. auxiliary verbs are POS=Verb, determiners have their own POS). The closed-class flag is orthogonal to POS assignment

### Phrase Constructions
- **D-06:** Phrase construction rules are authored via a **visual slot editor** — each slot is a labeled box, slots are added/ordered in sequence
- **D-07:** A slot can reference either a **closed-class gloss tag** (NEG, DEF, FUT) or an **open-class POS category** (V, N, ADJ)
- **D-08:** Rules are organized as a **flat list with user-chosen names** (e.g. "Negation", "Future tense", "Genitive") — no category grouping layer
- **D-09:** Rules show a **live preview** using actual closed-class words and sample lexicon entries to demonstrate the pattern with real words

### Word Order Settings
- **D-10:** New word order settings **extend the existing Typology page** with additional sections below the current Alignment / Word Order / Modality dropdowns — same auto-save pattern via project_settings
- **D-11:** **Core settings only**: head-directionality (head-initial / head-final / mixed), adposition type (preposition / postposition / circumposition), and adjective/genitive placement relative to noun
- **D-12:** Settings are stored as **structured data** (not free text) so Phase 12's scratchpad can use them as parsing hints — descriptive now, parseable later

### Grammar Tab Structure
- **D-13:** Grammar sidebar grows from 3 to 5 items: POS & Dimensions, Inflections, **Particles** (new), **Constructions** (new), Typology
- **D-14:** Particles page shows closed-class words **grouped by POS** (e.g. Auxiliaries section, Determiners section, Conjunctions section)

### Claude's Discretion
- Icon choices for new sidebar items (Particles, Constructions)
- Exact Leipzig glossing catalog contents (standard abbreviations)
- Particles page layout details (list vs cards, detail panel style)
- Construction slot editor widget design details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Grammar Architecture
- `lib/features/grammar/presentation/grammar_shell.dart` — Current sidebar structure (3 items) that needs 2 new items added
- `lib/features/grammar/presentation/typology/typology_page.dart` — Existing typology page to extend with new word order settings
- `lib/features/grammar/data/typology_providers.dart` — TypologySettings model and project_settings read/write pattern to follow

### Data Layer
- `lib/db/app_database.dart` — Drift database schema; Lexemes table needs closedClass flag + glossTag column
- `lib/features/lexicon/data/lexeme_dao.dart` — LexemeDao CRUD patterns for unified word storage
- `lib/features/lexicon/data/lexeme_providers.dart` — Existing providers that should expose closed-class words to unified search

### Morphology DSL (Pattern Reference)
- `lib/features/morphology/presentation/rules/rules_page.dart` — Reusable rule editor UI (potential pattern for construction rule editor)
- `lib/features/morphology/domain/morphology_engine.dart` — DSL processor pattern (reference for construction rule engine if needed)

### Navigation
- `lib/router/app_router.dart` — GoRouter config; needs new routes for Particles and Constructions pages

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **TypologyPage pattern**: Auto-save dropdowns via `writeTypologyKey` — reuse for new word order settings
- **project_settings table**: Key-value store already handles typology; natural home for word order settings
- **LexemeDao**: Full CRUD for lexemes; adding closed-class flag means minimal new DAO code
- **GrammarShell sidebar**: Established pattern for adding new sidebar items (just extend `_sidebarItems` list)
- **RulesPage**: Generic rule editor widget reused by Grammar and Lexicon; could inform construction editor design

### Established Patterns
- **Feature structure**: `data/` + `presentation/` + `domain/` subdirectories per feature
- **Riverpod providers**: StreamProvider for reactive data, Provider.family for parameterized queries
- **Drift DAOs**: `@DriftAccessor` annotation, watch streams for reactive updates
- **Auto-save**: project_settings uses update-then-insert upsert pattern (no explicit save button)

### Integration Points
- **Lexemes table**: Closed-class words stored here with flag; search and Anki export auto-include them
- **POS system**: Closed-class words reference existing POS definitions from POS & Dimensions
- **Typology page**: New word order sections added below existing content
- **Grammar sidebar**: New items added to `_sidebarItems` list in `GrammarShell`
- **GoRouter**: New `StatefulShellBranch` entries for `/grammar/particles` and `/grammar/constructions`

</code_context>

<specifics>
## Specific Ideas

- Visual slot editor for phrase constructions — slots as labeled boxes arranged left-to-right
- Live preview on construction rules using real lexicon words (consistent with morphology rule previews)
- Particles page grouped by POS with collapsible sections

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-analytic-grammar*
*Context gathered: 2026-04-13*
