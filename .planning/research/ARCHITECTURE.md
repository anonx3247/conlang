# Architecture Research

**Domain:** Flutter desktop conlang workbench — v2.0 feature integration
**Researched:** 2026-04-13
**Confidence:** HIGH (all conclusions drawn from direct codebase inspection, not assumptions)

---

## What the Existing Architecture Actually Is

Direct inspection of the codebase reveals the following concrete structure (not aspirational — what exists today):

**Navigation:** Two-level `StatefulShellRoute` in go_router. Outer shell = `AppShell` (3 top-level tabs: Phonology, Grammar, Lexicon). Inner shells = per-tab `PhonologyShell`, `GrammarShell`, `LexiconShell` each with 3-4 sub-tabs.

**State management:** Mix of Riverpod codegen (`@riverpod` annotation) and hand-written providers. Hand-written providers are used wherever Drift-generated types appear (because `riverpod_generator` 3.x cannot resolve Drift part-file types at codegen time — this is an established constraint, documented inline in `grammar_providers.dart`).

**Database:** Drift/SQLite, schema v13. Single `AppDatabase` with all feature tables registered. One database file per project (`project.db`). All feature DAOs are properties of `AppDatabase`. Project switching works via `currentDatabaseProvider` returning the open `AppDatabase` — all feature DAO providers watch `currentDatabaseProvider` and return null when no project is open.

**Feature pattern:** Every feature follows `data/` (DAO + providers) → `domain/` (pure Dart logic) → `presentation/` (widgets). This is the established, working pattern.

**Central computation:** `MorphologyEngine` (pure Dart, in `morphology/domain/`) is the evaluation core. `ParadigmEngine` (`grammar/domain/`) wraps it for paradigm cell resolution. `PhonemeInventory` is the shared vocabulary-of-phonemes type passed between engines.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AppShell (go_router)                    │
│  [Phonology] [Grammar] [Lexicon] [Scratchpad*] [Writing Sys.*]  │
└─────┬────────────┬────────────────────┬────────────────────────┘
      │            │                    │
      ▼            ▼                    ▼
  Phonology    Grammar               Lexicon
  Shell        Shell                 Shell
  (existing)   (existing +           (existing +
               analytic grammar)     etymology)
      │            │                    │
      └─────────┬──┘────────────────────┘
                │ Riverpod providers (currentDatabaseProvider)
                ▼
         AppDatabase (Drift/SQLite)
         schema v13 → v14+ for new tables
                │
         Feature DAOs (one per feature)
                │
         Pure Domain Engines
         MorphologyEngine ← central
         ParadigmEngine
         PhonologyEngine (word_generator + phonotactic_dsl)
         AnalyticGrammarEngine* (NEW)
         ScratchpadEngine* (NEW)
         SoundChangeEngine* (NEW)

* = new in v2.0
```

---

## New Features and Their Integration Points

### 1. Analytic Grammar System

**What it is:** Closed-class word inventory (particles, auxiliaries, determiners), phrase-level construction rules, word order patterns. Complements the existing morphological grammar system (which covers inflectional/derivational word forms).

**New vs modified:**
- NEW: `lib/features/grammar/data/analytic_grammar_dao.dart` — CRUD for closed-class words, phrase construction rules, word order settings
- NEW: `lib/features/grammar/domain/analytic_grammar_engine.dart` — evaluates phrase patterns
- NEW: `lib/features/grammar/presentation/analytic/` — UI sub-tab in GrammarShell
- MODIFIED: `lib/db/app_database.dart` — new tables (`AnalyticWords`, `PhraseRules`, `WordOrderSettings`), schema bump to v14
- MODIFIED: `lib/router/app_router.dart` — add `/grammar/analytic` branch to GrammarShell
- MODIFIED: `lib/features/grammar/presentation/grammar_shell.dart` — add 4th tab

**Key integration point:** `AnalyticWords` table needs to be searchable from the Scratchpad tokenizer (analytic particles must be recognized alongside lexeme roots). Add a `analyticsWordsDaoProvider` following the same null-when-no-project pattern as all other DAO providers.

**Data dependencies:** Reads `PartsOfSpeech` (to classify closed-class words by POS). No write dependency on other features.

**Schema additions:**
```
AnalyticWords: id, form (IPA), romanization, meaning, posId(FK), wordOrderRole
PhraseRules:   id, name, pattern (DSL string), ordering
WordOrderSettings: projectSettings key-value (reuse existing ProjectSettings table)
```

---

### 2. Writing Scratchpad

**What it is:** Text input area where the user writes phrases in their conlang and gets automatic parsing: tokenization → morphological analysis → interlinear gloss, with IPA transcription and error highlighting.

**New vs modified:**
- NEW: `lib/features/scratchpad/` — full new feature module
  - `data/scratchpad_providers.dart`
  - `domain/tokenizer.dart` — splits romanized/IPA text on known word boundaries
  - `domain/scratchpad_engine.dart` — orchestrates tokenize → analyze → gloss pipeline
  - `domain/interlinear_gloss.dart` — result model
  - `presentation/scratchpad_shell.dart` — new top-level tab shell
  - `presentation/scratchpad_page.dart`
  - `presentation/interlinear_display.dart` — renders aligned morpheme tiers
- NEW: `lib/features/scratchpad/domain/morph_analyzer.dart` — wraps MorphologyEngine for analysis mode (as opposed to generation mode)
- MODIFIED: `lib/shared/widgets/app_shell.dart` — add "Scratchpad" tab to `_tabs` list
- MODIFIED: `lib/router/app_router.dart` — add Branch 3: `/scratchpad`

**Key integration points:**

1. **Tokenizer reads from lexicon.** The tokenizer must look up every candidate token against `LexemeDao.watchAllLexemes()` to recognize known words. Use the existing `allLexemeListProvider` from `lexeme_providers.dart` — it already streams the full lexeme list.

2. **Tokenizer reads from AnalyticWords.** Closed-class words (particles, aux verbs) defined in the analytic grammar system must also be recognized. The tokenizer needs to watch `AnalyticWordsDaoProvider` as well.

3. **Morphological analysis reuses MorphologyEngine.** The scratchpad needs analysis direction (unknown surface form → which root + which rules?), which is the reverse of the existing generation direction (root + rules → surface form). This is a new `analyze()` method on `MorphologyEngine` or a separate `MorphologyAnalyzer` that tries all active rules against the token and returns candidate parses.

4. **IPA transcription reuses RomanizationBijection.** Already in `phonology/data/romanization_bijection.dart` — use it to convert romanized tokens to IPA for phonetic display.

5. **Phonotactic violation highlighting reuses existing logic.** `PhonotacticValidationProvider` in `lexicon/data/` already does this. The scratchpad can either depend on it directly or replicate the call pattern.

**Data flow:**
```
User types text
  → debounce 300ms
  → ScratchpadEngine.analyze(text)
      → Tokenizer.tokenize(text, knownWords, analyticWords)
      → for each token:
          if in lexicon: MorphologyAnalyzer.analyze(token, activeRules) → segments
          if unknown: flag as unknown (red underline)
          PhonologyEngine.applyRewriteRules(token) → phonetic form
      → InterlinearGloss assembled from segments
  → UI rebuilds via Riverpod watch
```

---

### 3. AI Integration (MCP)

**What it is:** A local MCP server exposing project data as tools so an external AI agent (Claude Desktop, claude CLI) can read and modify the conlang. The app itself does not host an AI — it hosts the MCP server.

**New vs modified:**
- NEW: `lib/features/ai/` — MCP server feature module
  - `data/mcp_server.dart` — stdio or HTTP JSON-RPC server
  - `data/mcp_tool_handlers.dart` — per-tool handler functions
  - `data/project_snapshot_service.dart` — assembles full project JSON snapshot
- NEW: `lib/features/ai/presentation/` — settings panel for MCP server (port, enable/disable)
- MODIFIED: `lib/features/project/presentation/project_menu.dart` — add "Start MCP Server" menu item
- MODIFIED: `pubspec.yaml` — add HTTP server package (e.g., `shelf` + `shelf_router`) for HTTP transport, OR implement stdio transport (simpler for Claude Desktop)

**Key integration points:**

1. **MCP server reads existing providers, never bypasses DAOs.** Every tool handler calls the same service/provider chain the UI uses. No direct SQL queries in MCP handlers.

2. **Project data access pattern:** MCP server needs a reference to the current `AppDatabase`. The cleanest approach is a `ProjectSnapshotService` that reads from all DAOs and assembles a JSON-serializable snapshot. This service is also useful for analytics and export.

3. **Transport choice:** For Claude Desktop integration, stdio transport is simpler (no port conflicts, no HTTP setup). For claude CLI (`/mcp add`), both work. Recommend stdio transport first.

4. **Tool surface:** Start minimal — `get_phoneme_inventory`, `search_lexicon`, `get_paradigm_table`, `analyze_phrase`. Add write tools (`add_word`, `add_rule`) only after read tools are stable.

5. **No UI dependency:** The MCP server runs headlessly alongside the Flutter app. Use a `StateNotifierProvider` or simple bool flag to track server running state for the UI indicator.

**No new DB schema needed.** MCP tools are read-only by default; write tools go through existing DAOs.

---

### 4. Language Evolution (Sound Change Modeling)

**What it is:** Sound change simulation — apply historically-motivated sound changes (Grimm's law, vowel shifts, etc.) to project phonemes and words to model a daughter language. Allophone-to-phoneme promotion lets a conditioned variant become a phonemic contrast.

**New vs modified:**
- NEW: `lib/features/evolution/` — new feature module
  - `data/evolution_dao.dart` — CRUD for sound change rules, evolution project metadata
  - `domain/sound_change_engine.dart` — applies diachronic rules to word lists
  - `presentation/evolution_shell.dart` — new tab or sub-feature
- NEW: `lib/db/app_database.dart` tables: `SoundChanges` (ordered rules with context DSL), `EvolutionProjects` (named evolution snapshots)
- MODIFIED: `lib/shared/widgets/app_shell.dart` — either add top-level "Evolution" tab or nest it within Phonology shell

**Key integration points:**

1. **SoundChangeEngine reuses PhonologicalRewriteRule DSL.** Diachronic sound changes follow the same SPE-style `A → B / C_D` notation already implemented in `phonology/domain/phonotactic_dsl.dart`. Reuse the parsing and matching infrastructure.

2. **SoundChangeEngine inputs the full lexeme list.** It reads from `LexemeDao` (all words in IPA) and applies the rule chain to each, producing a new phonemic form. The result can either (a) create a new derived project, or (b) produce a diff preview showing what would change.

3. **Allophone promotion modifies PhonemeDao.** When the user promotes an allophone, a new phoneme row is added to `Phonemes` and `RewriteRules` is updated to remove the conditioned rule. This is a multi-table transaction.

4. **Evolution "snapshots" should not modify the live project.** Sound change application should preview output, not rewrite existing lexemes. Store snapshots in a separate table or export to a new project file.

**Nesting recommendation:** Put Evolution as a sub-feature under the Phonology tab (4th sub-tab in `PhonologyShell`) rather than a new top-level tab. It is phonology-centric, and adding another top-level tab increases cognitive load.

---

### 5. Writing System Tab

**What it is:** Define a custom script or orthography for the conlang — character mappings, glyph definitions, rendering rules. Preview text rendered in the custom script.

**New vs modified:**
- NEW: `lib/features/writing_system/` — new feature module
  - `data/writing_system_dao.dart` — CRUD for character mappings, glyph metadata
  - `domain/script_renderer.dart` — maps phoneme/grapheme → custom symbol, handles directionality
  - `presentation/writing_system_shell.dart`
  - `presentation/script_editor_page.dart`
  - `presentation/script_preview_page.dart`
- NEW: DB tables: `ScriptCharacters` (unicode codepoint or SVG path, phoneme mapping), `ScriptSettings` (direction, case system)
- MODIFIED: `lib/shared/widgets/app_shell.dart` — add "Writing" tab
- MODIFIED: `lib/router/app_router.dart` — add Branch N: `/writing`

**Key integration points:**

1. **Script rendering hooks into RomanizationMappings.** The romanization system (`RomanizationMappings` table) already maps IPA → Latin. The writing system is a parallel mapping: IPA → custom script symbol. These two systems are independent columns on the same conceptual data (how is this phoneme written?).

2. **Scratchpad previews in custom script.** Once writing system is defined, the Scratchpad can show a third tier in the interlinear display: [custom script] / [romanization] / [IPA] / [gloss]. This is additive — write system support in Scratchpad is a `if (writingSystemDefined) ...` render path.

3. **Font rendering for custom scripts:** If the custom script uses existing Unicode characters (e.g., Cyrillic, Tengwar PUA encodings), a custom font can be loaded via Flutter's `FontLoader`. If it uses SVG path glyphs, custom `CustomPainter` drawing is needed. The script renderer should abstract this behind a `GlyphRenderer` interface.

---

### 6. Automatic Etymology

**What it is:** The lexicon already supports manual etymology links (`LexemeParents` table, `derivedFromLexemeId`/`derivedViaRuleId` on `Lexemes`). Automatic etymology detects compound words and common morphological patterns and suggests etymology links.

**New vs modified:**
- NEW: `lib/features/lexicon/domain/etymology_suggester.dart` — pure Dart analysis
- NEW: `lib/features/lexicon/presentation/dictionary/etymology_suggestion_widget.dart` — inline suggestion chips in word detail
- MODIFIED: `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — add etymology suggestion section
- No new DB schema needed — uses existing `LexemeParents` and `derivedViaRuleId`

**Key integration points:**

1. **EtymologySuggester gets existing roots + derivational rules as input.** It is a pure function: `suggest(targetLexeme, allLexemes, derivationalRules) → List<EtymologySuggestion>`. Suggestions are: "This word matches rule X applied to root Y" or "This word is a possible compound of A + B".

2. **Suggestion acceptance writes to existing `LexemeParents` DAO.** No new schema needed. The user accepts a suggestion and `LexemeParentsDao.insertParent()` is called.

3. **Computation can be expensive for large lexicons.** Run in a `compute()` isolate call, not on the main thread. Cache suggestions per-word in a `FutureProvider.family` keyed on lexeme ID. Invalidate when lexemes or rules change.

---

## Data Flow Changes Summary

### What changes in existing flows:

**Flow: Adding a root word** — unchanged. No new code path needed; etymology suggester runs lazily when the word detail is opened.

**Flow: Paradigm table generation** — unchanged. Analytic grammar is a separate system alongside morphological grammar, not replacing it.

**Flow: Project switch** — unchanged. New DAO providers follow the same `currentDatabaseProvider` null-guard pattern.

### What is new:

**Flow: Scratchpad analysis (NEW)**
```
User types text
  → ScratchpadEngine(ref).analyze(text)
      reads: allLexemeListProvider, analyticWordsProvider, activeMorphRulesProvider
      reads: phonemeInventoryProvider (for rewrite rules)
      → Tokenizer.tokenize(text, lexemes, analyticWords)
      → MorphologyAnalyzer.analyze(token, rules, inventory)
      → InterlinearGloss assembled
  → ScratchpadResultProvider emits new value
  → InterlinearDisplayWidget rebuilds
```

**Flow: MCP tool call (NEW)**
```
External AI agent → stdio/HTTP → MCP server
  → MCPToolHandler.dispatch(toolName, params)
  → reads from existing providers/DAOs (no bypass)
  → serializes to JSON
  → returns to AI agent
```

**Flow: Sound change preview (NEW)**
```
User defines SoundChange rules in Evolution tab
  → SoundChangeEngine.preview(rules, lexemes, inventory)
      reuses PhonologicalRewriteRule parsing
      applies chain to each lexeme.ipa
      returns Map<lexemeId, newForm>
  → EvolutionPreviewPage shows diff table
```

---

## New Folder Structure

```
lib/features/
├── phonology/          # EXISTING — minor evolution sub-tab addition
├── morphology/         # EXISTING — add MorphologyAnalyzer in domain/
├── lexicon/            # EXISTING — add etymology_suggester in domain/
├── grammar/            # EXISTING — add analytic/ sub-feature
│   ├── data/
│   │   └── analytic_grammar_dao.dart  # NEW
│   ├── domain/
│   │   └── analytic_grammar_engine.dart  # NEW
│   └── presentation/
│       └── analytic/  # NEW sub-tab
├── scratchpad/         # NEW full feature module
│   ├── data/
│   ├── domain/
│   └── presentation/
├── evolution/          # NEW full feature module
│   ├── data/
│   ├── domain/
│   └── presentation/
├── writing_system/     # NEW full feature module
│   ├── data/
│   ├── domain/
│   └── presentation/
├── ai/                 # NEW MCP server module
│   ├── data/
│   └── presentation/
└── ...existing features
```

---

## Suggested Build Order

Dependencies determine order. This order minimizes blocked work.

### Phase 1: Analytic Grammar (no new dependencies)

Build first because Scratchpad depends on knowing both lexeme words AND analytic words (particles). Having the analytic word inventory available before building the tokenizer avoids a partial tokenizer that must be revisited.

1. Schema migration: add `AnalyticWords`, `PhraseRules` tables (schema v14)
2. `AnalyticGrammarDao` + DAO provider
3. Grammar UI: analytic sub-tab in existing GrammarShell (4th tab)
4. `AnalyticGrammarEngine` (phrase construction rule evaluation)
5. Word order settings (reuse `ProjectSettings` table)

### Phase 2: Writing Scratchpad (depends on analytic grammar for full tokenizer)

Scratchpad is the centerpiece feature — most user-visible. Build it once the tokenizer's two lexical sources (lexemes + analytic words) are both available.

6. `Tokenizer` (reads `allLexemeListProvider` + new `analyticWordsDaoProvider`)
7. `MorphologyAnalyzer` wrapper in `morphology/domain/` (analysis direction for existing engine)
8. `ScratchpadEngine` (pipeline: tokenize → analyze → gloss)
9. `InterlinearGloss` result model
10. Scratchpad UI: new top-level tab, text input, interlinear display, error highlighting
11. Phonetic reading (IPA transcription tier via `RomanizationBijection`)

### Phase 3: Automatic Etymology (depends on stable lexicon — no blocking deps)

Lightweight addition to existing lexicon feature. No schema changes.

12. `EtymologySuggester` (pure Dart, in `lexicon/domain/`)
13. Word detail panel addition — suggestion chips + acceptance action

### Phase 4: Language Evolution (depends on phonology primitives being stable)

Reuses SPE DSL parser and PhonemeInventory types. No new DSL to write.

14. Schema migration: `SoundChanges`, `EvolutionProjects` tables
15. `SoundChangeEngine` (wraps existing `PhonologicalRewriteRule` parsing)
16. `EvolutionDao` + provider
17. Evolution UI: sub-tab in PhonologyShell (or separate tab — decision deferred)

### Phase 5: Writing System (no hard dependencies, but completes Scratchpad third tier)

Self-contained feature. Once writing system is defined, a Scratchpad enhancement can add the custom script tier.

18. Schema migration: `ScriptCharacters`, `ScriptSettings` tables
19. `ScriptRenderer` + `GlyphRenderer` interface
20. Writing system UI: new top-level tab
21. Scratchpad integration: custom script tier in interlinear display (optional, Phase 5 exit criteria)

### Phase 6: AI / MCP Integration (depends on all other features being stable)

The MCP server exposes what already exists. Build last so the tool API surface is stable.

22. `ProjectSnapshotService` (assembles full project data from existing DAOs)
23. MCP server scaffold (stdio transport first)
24. Read tool handlers: phoneme inventory, lexicon search, paradigm table, analyze phrase
25. Write tool handlers: add word, add rule (optional — read-only is a valid v2.0 boundary)
26. MCP server UI: settings panel, status indicator in app menu

---

## Key Architectural Constraints (Carry Forward from v1.0)

**1. Hand-written providers for Drift types.** The `riverpod_generator` 3.x constraint means any provider that returns a Drift-generated type (`Dimension`, `MorphologicalRule`, `Lexeme`, etc.) must be written as a plain `Provider` or `StreamProvider`, not annotated with `@riverpod`. New feature providers must follow this pattern.

**2. Null-guard pattern for no-project state.** Every DAO provider returns `null` when `currentDatabaseProvider` returns null. Feature code must guard: `if (dao == null) return Stream.value(const []);`. This is the established pattern in all six existing features.

**3. No codegen for Drift DAOs.** Drift DAOs are part files (`part 'x_dao.g.dart'`) generated by `drift_dev`. New DAOs follow the same `@DriftAccessor` pattern. Run `dart run build_runner build` after adding new table definitions.

**4. AppShell tab limit.** The `AppShell._tabs` list currently has 3 entries. v2.0 adds Scratchpad and Writing System as top-level tabs (5 total). Evolution nests under Phonology to keep top-level nav manageable. AI/MCP has no dedicated tab — it lives in the project menu.

---

## Anti-Patterns to Avoid in v2.0

### Scratchpad running analysis synchronously on every keystroke

The tokenizer + morphological analysis across the full lexicon is not O(1). Run inside `compute()` with a 300ms debounce. Return an `AsyncValue` — show a subtle spinner in the scratchpad status bar while analysis is in flight.

### MCP handlers containing business logic

MCP tool handlers must be pure delegation: receive JSON params, call existing DAO/service, serialize response. No linguistic logic in MCP handlers. If a capability doesn't exist as a service method yet, create the service method first, then wrap it in MCP.

### Sound change engine writing to live lexeme rows

Sound change preview must not modify `Lexemes.ipa`. It returns a diff map. Only when the user explicitly applies a change set (a distinct, confirmable action) should lexeme rows be updated — and that should be a transactional batch update with an undo snapshot.

### Writing system defined in terms of romanization (not phonemes)

The writing system should map from **IPA phonemes** to script characters, not from romanization strings. Romanization is a display layer that can change; IPA is the canonical internal form. This keeps the writing system independent of romanization choices.

### Etymology suggester blocking on the full lexicon at word-open time

For a 500-word lexicon, suggesting etymology on open is fast. At 5K words, it is noticeable. Run `EtymologySuggester.suggest()` inside a `FutureProvider.family` so it is computed lazily per word and cached by Riverpod until lexeme/rule data changes.

---

## Sources

All findings from direct codebase inspection:
- `/Users/neosapien/dev/conlang/lib/db/app_database.dart` (schema, table definitions)
- `/Users/neosapien/dev/conlang/lib/router/app_router.dart` (navigation structure)
- `/Users/neosapien/dev/conlang/lib/shared/widgets/app_shell.dart` (tab structure)
- `/Users/neosapien/dev/conlang/lib/features/grammar/data/grammar_providers.dart` (provider pattern, Drift constraint documentation)
- `/Users/neosapien/dev/conlang/lib/features/grammar/domain/paradigm_engine.dart` (engine composition pattern)
- `/Users/neosapien/dev/conlang/lib/features/morphology/domain/morphology_engine.dart` (central engine interface)
- `/Users/neosapien/dev/conlang/pubspec.yaml` (dependency versions)
