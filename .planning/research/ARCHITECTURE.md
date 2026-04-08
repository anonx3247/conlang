# Architecture Patterns

**Domain:** Flutter desktop conlang construction tool
**Researched:** 2026-04-08
**Confidence:** HIGH (Flutter/Dart/SQLite/MCP are stable, well-documented domains)

---

## Recommended Architecture

The system follows a **layered, plugin-capable monolith** with a clear separation between:

1. **UI layer** — Flutter widgets, screen state, navigation
2. **Feature modules** — domain logic per subsystem (phonology, lexicon, morphology, grammar, culture, scratchpad)
3. **Engine layer** — pure-Dart computation engines (morphology, phonotactics, parser, glosser)
4. **Data layer** — SQLite repositories, project registry, file I/O
5. **Service layer** — cross-cutting concerns (TTS pipeline, IPA audio, MCP server, Anki export)

The morphology engine and its pattern mini-language sit at the center: lexicon, grammar, scratchpad, and AI agent all depend on it.

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter UI                           │
│  [Phonology] [Lexicon] [Grammar] [Culture] [Scratchpad]     │
└──────────────┬──────────────────────────────────────────────┘
               │ Riverpod providers
┌──────────────▼──────────────────────────────────────────────┐
│                    Feature Modules                          │
│  PhonologyService  LexiconService  GrammarService           │
│  CultureService    ScratchpadService                        │
└──────────┬──────────────┬──────────────┬────────────────────┘
           │              │              │
┌──────────▼──────┐ ┌─────▼──────┐ ┌───▼───────────────────┐
│  Engine Layer   │ │ Data Layer │ │   Service Layer        │
│                 │ │            │ │                        │
│ MorphologyEngine│ │ SQLite     │ │ TTS Pipeline           │
│ PhonologyEngine │ │ Repos      │ │ IPA Audio Cache        │
│ Parser/Glosser  │ │ Project    │ │ MCP Server             │
│ PatternRuntime  │ │ Registry   │ │ Anki Exporter          │
└─────────────────┘ └────────────┘ └────────────────────────┘
```

---

## Component Boundaries

### Component: ProjectRegistry

**Responsibility:** Knows where all project folders live. Opens, creates, and switches projects. Each project is a directory containing a `conlang.db` SQLite file and a `meta.json`.

**Communicates with:** All repositories (passes open DB connection), UI navigation layer.

**Does not:** Know anything about linguistic content.

---

### Component: PhonologyEngine (pure Dart, no I/O)

**Responsibility:** Validate sequences against phonotactics rules. Apply phonological rules (SPE-style: `a / _[+nasal] → ã`). Generate candidate word forms from phonotactics templates. Produce Latin transcription from internal representation.

**Communicates with:** PhonologyRepository (reads rules), MorphologyEngine (validates engine output), ScratchpadService (phonetic reading generation).

**Does not:** Store data, play audio, touch the UI.

**Key design:** Phonotactics are compiled to a fast DFA at load time so per-keystroke validation is O(n) per character. Store compiled DFA in memory, invalidate on rule edits.

---

### Component: PhonologyRepository

**Responsibility:** CRUD for phoneme inventory, phonotactics patterns, phonological rule definitions, Latin transcription mappings. All backed by SQLite tables in the active project DB.

**Communicates with:** PhonologyEngine (supplies rules), PhonologyService (orchestrates).

---

### Component: IPAAudioService

**Responsibility:** Cache and serve IPA recording audio files sourced from Wikipedia. Downloads lazily on first access, stores in `~/Library/Application Support/ConlangWorkbench/ipa_cache/`. Provides a stream/future API for audio playback.

**Communicates with:** PhonologyService (triggered from IPA chart UI), no project DB dependency (global cache).

**Does not:** Know about conlang-specific phonemes — it serves standard IPA symbol recordings only.

---

### Component: MorphologyEngine (pure Dart, no I/O)

**Responsibility:** Parse, compile, and execute the pattern mini-language. Apply rules to produce derived forms. Support all morphological strategies:
- Concatenative: prefix/suffix/circumfix
- Infixation: positional insertion
- Vowel replacement / ablaut
- Triconsonantal templates (Semitic): `C1VC2VC3` skeleton + vowel pattern
- Reduplication
- Suppletion (lookup table fallback)

**Communicates with:** MorphologyRepository (loads pattern definitions), LexiconService (derives words on demand), GrammarService (generates declension/conjugation tables), ScratchpadService (applies rules during parsing).

**Does not:** Store derived words persistently (derived words are recomputed from rules + roots, cached in DB as a materialized view).

**Key design:** The pattern mini-language is compiled to a small AST → bytecode interpreter. This makes the plugin architecture natural: a plugin is a compiled pattern program. Pattern programs are pure functions `(input: MorphInput) → MorphOutput` so they are trivially testable and composable.

---

### Component: PatternRuntime (plugin architecture)

**Responsibility:** Host the pattern mini-language execution environment. Expose a registration API so each morphological strategy is a named plugin:
```
PatternRuntime.register('semitic-template', SemiticTemplatePlugin());
PatternRuntime.register('vowel-harmony', VowelHarmonyPlugin());
```

**Communicates with:** MorphologyEngine (runtime is embedded within engine), plugin implementations.

**Design rationale:** Rather than a large switch statement, each strategy is a class implementing `MorphPlugin` with `matches(PatternNode)` and `apply(MorphInput) → MorphOutput`. New morphological strategies ship as new plugin classes without touching the engine core. This is the extensibility seam for future language type support.

---

### Component: MorphologyRepository

**Responsibility:** CRUD for morphological rule definitions (stored as pattern mini-language source strings + metadata). Persists rule sets, rule ordering, rule groups. Caches compiled bytecode (invalidated on edit).

**Communicates with:** MorphologyEngine (supplies compiled rules), LexiconRepository (join for derived word storage).

---

### Component: LexiconService

**Responsibility:** Orchestrate root word management and derived word resolution. Trigger MorphologyEngine for derivation. Manage etymology chains. Integrate Swadesh list and Conlanger's Thesaurus lookups. Trigger Anki export.

**Communicates with:** LexiconRepository, MorphologyEngine, PhonologyEngine (validates new words), AnkiExporter.

---

### Component: LexiconRepository

**Responsibility:** CRUD for root words, derived words (materialized), etymologies. FTS5 full-text search index over headwords and definitions. Phonotactics violation flags (computed column or stored flag updated on phonology rule change).

**Communicates with:** LexiconService, MorphologyRepository.

**Key design:** Derived words table stores `(root_id, rule_id, surface_form, gloss)`. Surface form is recomputed and re-stored when rules change — treat it as a materialized cache, not source of truth. Source of truth is `(root, rule)` pair.

---

### Component: GrammarService

**Responsibility:** Parts-of-speech definitions, declension/conjugation rule system management, word order rules, typology choices (ergative/accusative, etc.), modality expression strategy (morphological vs analytic). Generate complete paradigm tables by feeding words through MorphologyEngine.

**Communicates with:** GrammarRepository, MorphologyEngine (paradigm generation), LexiconService (per-word exception lookup).

---

### Component: GrammarRepository

**Responsibility:** CRUD for POS definitions, feature categories (case, tense, aspect, mood, number, gender...), rule assignments, typology flag settings, word order constraints, per-word paradigm exceptions.

**Communicates with:** GrammarService.

---

### Component: CultureService + CultureRepository

**Responsibility:** Wiki-style Markdown document management with internal `[[link]]` syntax. Document graph (pages link to each other). Full-text search. Image attachments stored as files in project folder.

**Communicates with:** UI directly (lightweight — no linguistic computation). File system for attachments.

---

### Component: ScratchpadService

**Responsibility:** Orchestrate the full writing analysis pipeline:
1. Tokenizer: split text into tokens (respects known word boundaries)
2. MorphologyEngine: analyze each token against all active rules, producing morpheme segmentation
3. PhonologyEngine: generate phonetic reading
4. InterlinearGlosser: align morpheme analyses with source text for interlinear display
5. TTSPipeline: feed phonetic reading to TTS

Also: unknown word detection (token not in lexicon after analysis → flagged), phonotactics violation highlighting (token fails phonotactics → red underline).

**Communicates with:** LexiconRepository (token lookup), MorphologyEngine, PhonologyEngine, TTSPipeline.

---

### Component: TTSPipeline

**Responsibility:** Convert phonetic transcription (output of PhonologyEngine) into audible speech. Strategy: use a configurable backend — initially `flutter_tts` with phoneme-to-SSML mapping; optionally a local ML model (e.g., MaryTTS or Kokoro) for better phoneme control.

**Communicates with:** ScratchpadService (input: phonetic string), audio output device.

**Key design:** Separate the phoneme-to-speech-backend mapping into a `TTSBackend` interface. This isolates the ML model swap without touching ScratchpadService.

---

### Component: MCPServer

**Responsibility:** Expose all project data as MCP tools so an AI agent (Claude or other) can read and write to the conlang project. Runs as a local subprocess or in-process HTTP server on a fixed port. Exposes tools:
- `get_phoneme_inventory`, `get_phonotactics_rules`
- `search_lexicon`, `get_word_etymology`, `add_root_word`
- `get_grammar_rules`, `get_paradigm_table`
- `get_culture_page`, `list_culture_pages`
- `analyze_phrase` (runs ScratchpadService pipeline)
- `get_project_summary`

**Communicates with:** All repositories (read) and services (write path for `add_root_word`, etc.). Does not bypass service layer — always goes through services to maintain consistency.

**Key design:** MCP server is a thin JSON-RPC/HTTP layer over the existing service API. No business logic lives in MCP handlers — they delegate immediately to services. This means the MCP server can be tested by testing services independently.

---

## Data Flow

### Flow 1: Adding a new root word

```
UI (Lexicon tab)
  → LexiconService.addRoot(form, gloss, POS)
    → PhonologyEngine.validate(form) [phonotactics check]
    → LexiconRepository.insertRoot()
    → MorphologyEngine.deriveAll(root, activeRules)
    → LexiconRepository.upsertDerivedForms()
    → LexiconService emits updated word list
  → UI rebuilds via Riverpod watch
```

### Flow 2: Scratchpad phrase analysis

```
User types phrase in scratchpad
  → ScratchpadService.analyze(text)
    → Tokenizer.tokenize(text) → [tokens]
    → for each token:
        LexiconRepository.lookup(token) → root candidate
        MorphologyEngine.analyze(token, activeRules) → morpheme segments
        PhonologyEngine.validate(token) → violation? (flag red)
    → InterlinearGlosser.build(segments) → interlinear lines
    → PhonologyEngine.transcribe(text) → phonetic string
    → result: InterlinearGloss + ViolationMap + PhoneticReading
  → UI renders interlinear display + highlights
```

### Flow 3: Paradigm table generation

```
UI (Grammar tab, word selected)
  → GrammarService.generateParadigm(wordId, posId)
    → GrammarRepository.getFeatureMatrix(posId) → [case × number × gender...]
    → GrammarRepository.getRules(posId) → rule list
    → LexiconRepository.getRoot(wordId) → root form
    → for each cell in matrix:
        MorphologyEngine.apply(root, rules, features) → surface form
        GrammarRepository.getException(wordId, features) → override if exists
    → returns: ParadigmTable
  → UI renders table
```

### Flow 4: MCP tool call (AI agent)

```
AI agent calls analyze_phrase tool
  → MCPServer.handleToolCall("analyze_phrase", {text})
    → ScratchpadService.analyze(text)  [same as Flow 2]
    → serialize result as JSON
  → AI agent receives structured gloss + violations
```

### Flow 5: Project switch

```
UI (project picker)
  → ProjectRegistry.openProject(path)
    → Close current SQLite connection
    → Open new connection at path/conlang.db
    → Invalidate all Riverpod providers (via ProviderContainer.invalidate or scoped container)
    → All repos now hold reference to new DB connection
  → UI rebuilds from fresh state
```

---

## Suggested Build Order

Dependencies determine the build order. Each layer must be stable before the next layer builds on it.

### Layer 0: Project Infrastructure (prerequisite for everything)

1. `ProjectRegistry` — folder management, SQLite open/close, project metadata
2. Database schema migration system (drift or sqflite migrations)
3. Riverpod provider scaffold — `projectProvider`, `dbProvider`
4. Basic Flutter shell: navigation rail (Phonology / Lexicon / Grammar / Culture / Scratchpad tabs)

**Why first:** Every other component needs an open DB connection and a running app shell.

### Layer 1: Phonology Engine + Repository (prerequisite for lexicon validation)

5. `PhonologyRepository` — phoneme and rule CRUD
6. `PhonologyEngine` — validator and transcriber (pure Dart, fully testable in isolation)
7. Phonology UI: phoneme inventory editor, phonotactics rule editor
8. `IPAAudioService` — IPA chart audio (can be done in parallel, no dependencies)

**Why second:** The phonology validator is needed before lexicon (words need validation). The engine is pure Dart — build and test it before wiring to UI.

### Layer 2: Morphology Engine + Pattern Mini-Language (prerequisite for lexicon derived forms, grammar)

9. Pattern mini-language: lexer → parser → AST
10. `PatternRuntime` with plugin registration
11. Concatenative plugin (prefix/suffix) — simplest strategy
12. `MorphologyRepository` — rule definition CRUD
13. `MorphologyEngine` — orchestrates runtime + repos
14. Additional strategy plugins: infixation, ablaut, Semitic template, reduplication

**Why third:** The morphology engine is the centerpiece. Lexicon cannot store derived forms, Grammar cannot generate paradigms, and Scratchpad cannot analyze text without it. Build concatenative first (covers 80% of use cases), add Semitic/ablaut after.

### Layer 3: Lexicon (depends on phonology + morphology)

15. `LexiconRepository` — root word CRUD, FTS5, derived forms table
16. `LexiconService` — orchestration, derivation triggering
17. Lexicon UI: root dictionary view, word detail, etymology editor
18. Swadesh list integration (static bundled data)
19. Anki export

### Layer 4: Grammar (depends on morphology + lexicon)

20. `GrammarRepository` — POS, feature categories, rules, exceptions
21. `GrammarService` — paradigm generation
22. Grammar UI: POS editor, paradigm chart, typology settings

### Layer 5: Scratchpad + Writing Analysis (depends on phonology + morphology + lexicon)

23. Tokenizer
24. `InterlinearGlosser`
25. `ScratchpadService` — pipeline orchestration
26. Scratchpad UI: text input, interlinear display, violation highlights
27. `TTSPipeline` — phonetic → audio (integrate `flutter_tts` first, ML model later)
28. Phonetic reading display

### Layer 6: Culture Wiki (independent of linguistic engines)

29. `CultureRepository` + `CultureService`
30. Markdown editor + renderer with `[[internal link]]` support
31. Document graph / link resolution

**Note:** Culture can be built in parallel with Layer 4 since it has no linguistic dependencies.

### Layer 7: MCP Server (depends on all services being stable)

32. MCP server scaffold (local HTTP or stdio JSON-RPC)
33. Tool handlers delegating to existing services
34. AI agent connection testing

**Why last:** The MCP server is a thin wrapper. It should be built after the services it exposes are stable — otherwise the API surface keeps shifting.

---

## State Management: Flutter Desktop

**Recommendation: Riverpod 2.x with code generation (`@riverpod` annotation)**

Rationale:
- Compile-time safety: providers are typed, no string-based lookup
- Scoping: project-scoped providers can be overridden per project (critical for multi-project support)
- Async support: `AsyncNotifier` and `StreamNotifier` handle DB queries naturally
- Testability: providers can be overridden in tests without a widget tree

**Multi-project provider scoping pattern:**

Use a `ProviderScope` override at the project level. When a project switches, the `dbProvider` is overridden with the new connection, and all downstream providers (which depend on `dbProvider`) auto-invalidate.

```dart
// Conceptual — not prescriptive implementation
final dbProvider = Provider<Database>((ref) => throw UnimplementedError());
final phonemeProvider = FutureProvider<List<Phoneme>>((ref) async {
  final db = ref.watch(dbProvider);
  return PhonologyRepository(db).getAll();
});
// On project switch: rebuild ProviderScope with new dbProvider override
```

**Avoid:** `setState` for anything shared across tabs. `ChangeNotifier` is acceptable for pure UI state within a single widget (e.g., which phoneme is selected in a table row), not for domain state.

---

## Plugin Architecture for the Pattern Mini-Language

The pattern mini-language needs to handle morphological diversity without a monolithic codebase. The architecture:

```
Pattern Source String
        │
        ▼
   Lexer (tokenize)
        │
        ▼
   Parser (build AST)
        │
        ▼
   PatternNode tree
        │
        ▼
   PatternRuntime.execute(node, MorphInput)
        │  ← dispatches to registered plugin
        ▼
   MorphPlugin.apply(input) → MorphOutput
```

**Plugin interface:**

```dart
abstract class MorphPlugin {
  // Returns true if this plugin handles this pattern node type
  bool matches(PatternNode node);
  // Pure function: input → output, no side effects
  MorphOutput apply(MorphInput input, PatternNode node);
}
```

**Registration is declarative:**

```dart
final runtime = PatternRuntime()
  ..register(ConcatenativePlugin())      // prefix:, suffix:, circumfix:
  ..register(InfixPlugin())              // infix: at position/before/after
  ..register(VowelReplacementPlugin())   // ablaut: pattern
  ..register(SemiticTemplatePlugin())    // template: C1vC2vC3
  ..register(RedupPlugin());             // redupl: full|partial
```

**New morphological strategy = new plugin class.** No engine changes required. This is the primary extensibility axis.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing Derived Words as Source of Truth

**What goes wrong:** UI edits a derived form directly, disconnecting it from its generating rule. After a rule change, half the derived forms are stale.

**Instead:** Derived forms are always recomputed from `(root, rule)`. Store the surface form as a cache for query performance. Invalidate on rule edit.

### Anti-Pattern 2: Putting Morphology Logic in the Grammar Module

**What goes wrong:** Grammar and lexicon both need morphology. If morphology logic lives in Grammar, Lexicon has to call Grammar to derive words — a circular dependency.

**Instead:** MorphologyEngine is a shared pure-computation layer with no domain knowledge of "grammar" or "lexicon". Both call it directly.

### Anti-Pattern 3: One Global SQLite Connection for All Projects

**What goes wrong:** Switching projects requires restarting the app or complex connection state management. Cross-project queries become possible bugs.

**Instead:** DB connection is scoped to the active project via Riverpod override. Switching projects rebuilds the provider scope with a new connection.

### Anti-Pattern 4: MCP Handlers Containing Business Logic

**What goes wrong:** Business rules exist in two places (MCP handler + service). They diverge. AI agent gets different behavior than the UI.

**Instead:** MCP handlers are pure delegation — parse JSON, call service, serialize response. Zero logic.

### Anti-Pattern 5: Phonotactics Validated Only on Save

**What goes wrong:** User types a word, saves it, gets an error. Edit-save loop for phonotactics issues is frustrating. Violation not visible in other views.

**Instead:** Phonotactics validation runs on every keystroke (debounced 200ms) during word editing. Violation flags are stored on the word record and shown inline everywhere the word appears (lexicon list, scratchpad, etc.).

### Anti-Pattern 6: TTS Blocking the UI Thread

**What goes wrong:** Phonetic synthesis stalls the UI during scratchpad analysis, especially for longer phrases.

**Instead:** TTS pipeline runs in a Dart `Isolate` (or via `compute()`). Results are streamed back. UI shows a progress indicator and updates incrementally.

---

## Scalability Considerations

| Concern | At 500 words | At 5K words | At 50K words |
|---------|--------------|-------------|--------------|
| Lexicon search | In-memory list filter | FTS5 index (already recommended) | FTS5 + pagination |
| Derivation on rule change | Recompute all derived forms eagerly | Background isolate recompute, progress indicator | Incremental recompute with dirty-flagging |
| Scratchpad tokenization | Synchronous, fast | Debounce + isolate | Isolate + streaming tokens |
| Grammar paradigm generation | Eager all cells | Lazy: compute cells on scroll | Cache paradigm tables in DB |
| SQLite file size | <1MB | ~10MB (with audio refs) | ~100MB — consider WAL mode, VACUUM schedule |

SQLite WAL mode should be enabled from day one. It gives better concurrent read performance (MCP server reads while UI writes) and is trivial to enable.

---

## Sources

- Flutter architecture guidance: https://docs.flutter.dev/app-architecture (HIGH confidence — official)
- Riverpod 2.x documentation: https://riverpod.dev/docs/introduction/getting_started (HIGH confidence — official)
- SQLite WAL mode: https://www.sqlite.org/wal.html (HIGH confidence — official SQLite docs)
- MCP protocol specification: https://modelcontextprotocol.io/specification (HIGH confidence — official Anthropic spec)
- Morphological typology (agglutinative, Semitic, fusional, analytic): standard linguistics literature — Comrie, Haspelmath (HIGH confidence — well-established domain knowledge)
- Pattern mini-language design: informed by existing conlang tools (Lexurgy, LING morphology), regex engine design patterns, and PEG parser literature (MEDIUM confidence — design synthesis, not a single canonical source)
