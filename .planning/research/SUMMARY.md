# Project Research Summary

**Project:** Conlang Workbench
**Domain:** Flutter desktop application for constructed language creation
**Researched:** 2026-04-08
**Confidence:** MEDIUM (stack and architecture HIGH; versions and MCP specifics LOW)

## Executive Summary

Conlang Workbench is a locally-run desktop tool for constructing artificial languages, targeting macOS/Windows/Linux via Flutter. The research confirms a clear market gap: no existing free tool (ConWorkShop, Vulgar, PolyGlot, Lexique Pro) combines non-concatenative morphology, interlinear glossing of written text, and an AI co-creator in one offline-first application. The recommended approach is a layered monolith with Flutter + Riverpod for the UI/state, drift + SQLite for per-project data, and a custom PEG-based morphology pattern engine (petitparser) as the architectural centrepiece. Everything else — lexicon, grammar, writing scratchpad, AI integration — depends on that engine being correct.

The single most consequential architectural decision is the morphology pattern mini-language. It must handle templatic (Semitic root-and-pattern), ablaut, concatenative, and suppletive morphology from the start — not as afterthoughts. The data schema must treat derived words as recomputable results of (root, rules), not as stored strings. Both of these decisions are load-bearing for every later phase. If either is deferred or simplified in Phase 1, a rewrite is the likely outcome.

Key risks are: (1) morphology engine designed for concatenative-only forcing a rewrite when Semitic-style languages are attempted; (2) pattern mini-language scope-creeping into a full DSL that linguists cannot write; (3) TTS over-promised — no neural TTS handles arbitrary phoneme inventories, so the feature must be scoped as best-effort with a phoneme-concatenation fallback. All three risks are preventable through upfront design choices rather than implementation heroics.

---

## Key Findings

### Recommended Stack

The stack is built around Flutter 3.22+ as the mandatory cross-platform framework, drift 2.19 (type-safe SQLite ORM with reactive streams) for per-project databases, and Riverpod 2.x with code generation for state management. The database-per-project model (one `conlang.db` per language folder) maps naturally to drift's runtime database opening and Riverpod's provider scoping. petitparser handles the morphology pattern mini-language's PEG grammar. For exports: the `pdf` package for document export, `archive` for Anki `.apkg` (custom implementation — no library needed), and `just_audio` / `flutter_tts` for audio/TTS.

**Core technologies:**
- Flutter + Dart: cross-platform desktop UI — user constraint; macOS/Windows/Linux are Tier 1 targets since Flutter 3.10
- drift: SQLite ORM — reactive watch queries, schema migrations, desktop-native via sqlite3_flutter_libs
- Riverpod 2.x: state management — compile-time typed providers, trivial project scoping via ProviderScope overrides
- petitparser: PEG parser — pure Dart, composable combinators, good error messages for user-facing rule parsing
- freezed: immutable domain models — Phoneme, MorphologyRule, LexiconEntry; catches structural errors at compile time
- just_audio + flutter_tts: audio and TTS — just_audio for IPA chart playback; flutter_tts + IPA SSML for conlang speech approximation
- go_router: navigation — Flutter team's recommended router; supports nested tab routing

All version numbers in STACK.md are marked [VERIFY] — they are training-data estimates and must be confirmed against pub.dev before pinning in pubspec.yaml.

### Expected Features

**Must have (table stakes):**
- Phoneme inventory definition with IPA input — entry point for every new language
- Lexicon management (root + derived words) — core persistent artifact
- Word-level search and filter — critical at thousands of entries
- Part-of-speech tagging — prerequisite for morphology and grammar
- Declension/conjugation tables — single most-requested feature in conlang communities
- Basic grammar documentation — even free-text satisfies this minimally
- Multi-project management with per-project isolation
- Text/CSV export — minimum for users to share work

**Should have (differentiators):**
- Morphology pattern mini-language covering non-concatenative morphology — the core differentiator; no free tool does this
- Interlinear glossing in the writing scratchpad — end-to-end pipeline proof
- Phonotactic violation highlighting (real-time, inline everywhere)
- Clickable IPA reference chart with bundled audio recordings
- AI co-creator via MCP (Claude or compatible host with full project context)
- TTS for conlang speech (best-effort, phoneme-concatenation fallback)
- Swadesh list + Conlanger's Thesaurus semantic coverage view
- Anki export with morphological context in card fields
- Culture/world-building wiki with Markdown and internal links
- Phonological sound change engine (diachronic derivation)
- Etymological tracking with derivation chain display

**Defer (v2+):**
- AI agent feature (high complexity — validate core tool first)
- Cloud sync or multi-user features
- Mobile app
- Syntax tree / phrase structure diagram editor
- Machine translation (wrong product category)
- Version control / branching for language history

### Architecture Approach

The system is a layered monolith with five tiers: Flutter UI, Feature Modules (per subsystem), Engine Layer (pure-Dart computation — no I/O), Data Layer (SQLite repositories), and Service Layer (cross-cutting concerns: TTS, IPA audio cache, MCP server, Anki exporter). The MorphologyEngine sits at the center — lexicon, grammar, scratchpad, and AI agent all depend on it. Riverpod providers wire UI to feature modules; project switching is handled by overriding the `dbProvider` in a ProviderScope, which auto-invalidates all downstream providers without app restarts.

**Major components:**
1. ProjectRegistry — folder management, SQLite open/close, per-project metadata
2. PhonologyEngine (pure Dart) — phonotactics validation, phoneme sequence transcription, compiled DFA for per-keystroke checking
3. MorphologyEngine (pure Dart) — pattern mini-language AST to bytecode, plugin-per-strategy architecture (concatenative, infixation, ablaut, Semitic template, reduplication, suppletive lookup)
4. LexiconRepository — root words, derived forms (materialized cache, not source of truth), FTS5 full-text search
5. GrammarService — user-defined feature categories, paradigm table generation via MorphologyEngine
6. ScratchpadService — orchestrates tokenizer, morphology analysis, phonology validation, interlinear glosser, and TTS pipeline
7. MCPServer — thin JSON-RPC/HTTP delegation layer over existing services; zero business logic in handlers

**Build order determined by dependency graph:** ProjectRegistry, then PhonologyEngine, then MorphologyEngine, then LexiconService, then GrammarService, then ScratchpadService, then CultureWiki, then MCPServer.

### Critical Pitfalls

1. **Morphology engine designed concatenative-only** — prototype a triconsonantal root test case on day 1 of engine design; if it cannot be expressed cleanly, the abstraction is wrong. Use named pattern kinds (AFFIX, TEMPLATE, ABLAUT, LOOKUP) in the type system.

2. **Pattern mini-language scope-creeping into a full DSL** — write a one-page ceiling spec before any parsing code; if the spec exceeds one page, cut features. Phonological conditioning belongs in the separate phonology rule engine, not the morphology pattern.

3. **SQLite schema treating words as flat records** — derived forms must be stored as (root_id, rule_ids, computed_form) where the form is a regenerable cache, not source of truth. Root-rule separation is the schema's load-bearing design.

4. **Forcing completeness before use (UX anti-pattern)** — every feature must work with zero prior setup; empty states are permissive, not gates. A new project must reach any tab without data entry. Design empty states before populating them.

5. **IPA audio fetched from Wikipedia at runtime** — bundle the full IPA sound file set (~100-120 files, ~5-10 MB) as app assets during development. Wikipedia is the source at development time, not at runtime.

---

## Implications for Roadmap

Based on the dependency graph from ARCHITECTURE.md and the phase warnings from PITFALLS.md, the research strongly implies a 7-phase structure. Architecture research provides a validated build order; pitfalls research identifies which decisions cannot be deferred.

### Phase 1: Foundation — Project Shell, Phonology, and Schema

**Rationale:** Every other phase depends on an open project database, a phoneme representation layer, and a derivation-aware schema. These three are prerequisites for lexicon validation, morphology engine output, and scratchpad analysis. Deferring any of them causes rework. The auto-save infrastructure and empty-state UX philosophy must also be established here — both are architecture, not features.

**Delivers:** Working Flutter app shell with navigation rail, project creation and switching, phoneme inventory editor, IPA reference chart with bundled audio, phonotactics rule editor, per-keystroke phonotactics validation, and the database schema with derivation tree structure.

**Addresses (from FEATURES.md):** Phoneme inventory definition, IPA input, persistent local storage, multi-project management.

**Avoids (from PITFALLS.md):** Pitfall 1 (concatenative-only engine), Pitfall 4 (flat word schema), Pitfall 8 (regex phonotactics), Pitfall 9 (state loss), Pitfall 10 (runtime Wikipedia audio), Pitfall 11 (completeness-forcing UX).

### Phase 2: Morphology Engine and Pattern Mini-Language

**Rationale:** The morphology engine is the centrepiece differentiator. Lexicon derived forms, grammar paradigm generation, and scratchpad analysis all require it. Build it before lexicon and grammar UI so those layers build on a stable, tested engine. Plugin architecture (MorphPlugin interface) must be established here — concatenative plugin first, then Semitic/ablaut/reduplication.

**Delivers:** Pattern mini-language (spec to lexer to parser to AST to bytecode runtime), concatenative plugin, Semitic template plugin, ablaut/vowel-change plugin, reduplication plugin, suppletive lookup, MorphologyRepository CRUD, morphology rule editor UI.

**Addresses (from FEATURES.md):** Morphology pattern mini-language (core differentiator), non-concatenative morphology coverage.

**Avoids (from PITFALLS.md):** Pitfall 1 (triconsonantal root prototype in week 1), Pitfall 2 (one-page spec ceiling before implementation).

**Research flag:** High novelty — the pattern mini-language design is a synthesis of linguistics literature and PEG parser techniques with no single canonical reference. Run a design spike on the syntax surface before committing to the DSL. Specifically: how does the mini-language express phonological conditioning (vowel harmony, assimilation) without crossing into DSL scope creep?

### Phase 3: Lexicon

**Rationale:** Lexicon depends on phonology (word validation) and morphology (derived form generation). Both are now stable. Lexicon is also the prerequisite for grammar (which needs words to inflect) and scratchpad (which needs a dictionary to look up tokens). Swadesh list and Anki export belong here since they are lexicon-level concerns.

**Delivers:** LexiconRepository (roots, derived forms, FTS5, etymology chains), LexiconService with derivation triggering on add/edit, root dictionary UI, word detail view, etymology editor, Swadesh list coverage view, Anki export with morphological context.

**Addresses (from FEATURES.md):** Lexicon management, word search and filter, POS tagging, etymological tracking, Swadesh integration, Anki export.

**Avoids (from PITFALLS.md):** Pitfall 4 (schema correctness verified upstream), Pitfall 13 (Anki export with full derivation context, not flat cards), Pitfall 14 (live Swadesh coverage view, not static import).

### Phase 4: Grammar and Paradigm Tables

**Rationale:** Grammar depends on morphology (paradigm generation) and lexicon (words to inflect). Paradigm table generation is the highest-visibility payoff from the morphology engine — the deliverable users will screenshot and share.

**Delivers:** GrammarRepository (user-defined POS, user-defined feature categories), GrammarService with paradigm generation, grammar UI (POS editor, paradigm chart, typology settings), word order and modality strategy documentation.

**Addresses (from FEATURES.md):** Declension/conjugation tables, grammar documentation, typology choice system, modality expression strategy.

**Avoids (from PITFALLS.md):** Pitfall 12 (feature categories are user-defined data, not hardcoded constants).

### Phase 5: Writing Scratchpad and Interlinear Glosser

**Rationale:** The scratchpad is the second major differentiator. It requires the entire upstream stack to be stable: phonology (validation), lexicon (token lookup), morphology (morpheme analysis). ScratchpadService orchestrates all three. Interlinear glosser and phonotactic violation highlighting complete the end-to-end pipeline.

**Delivers:** Tokenizer, InterlinearGlosser, ScratchpadService pipeline, scratchpad UI with interlinear display and violation highlighting, explicit gloss result types (GLOSSED / UNKNOWN_ROOT / PARTIAL_MATCH / RULE_FAILED / TOKENIZATION_ERROR), phonetic reading display, TTSPipeline (flutter_tts + IPA SSML, with phoneme-concatenation fallback).

**Addresses (from FEATURES.md):** Writing scratchpad, interlinear glossing, phonotactic violation linting, TTS (scoped as best-effort).

**Avoids (from PITFALLS.md):** Pitfall 3 (silent failure on unknowns — explicit result types from the start), Pitfall 5 (IPA diacritics via characters package + NFC normalization), Pitfall 6 (TTS scoped as approximation with fallback, not a solved audio problem).

### Phase 6: Culture Wiki

**Rationale:** Culture wiki has no linguistic engine dependencies — it can be built in parallel with Phase 4, but is deprioritized because it is not on the critical differentiator path. It is a standalone Markdown document system with internal linking.

**Delivers:** CultureRepository + CultureService, Markdown editor with flutter_markdown, [[internal link]] resolution, document graph, full-text search over wiki pages.

**Addresses (from FEATURES.md):** Culture/world-building wiki.

**Research flag:** Standard patterns (Markdown editing, document graph). Skip research-phase; use flutter_markdown with custom inline syntax extension.

### Phase 7: AI Agent (MCP Integration)

**Rationale:** MCP server is a thin delegation layer over existing services. It must be built last because it depends on all services being stable — building it earlier means the API surface keeps shifting. Validate the core tool (Phases 1-6) before adding network and AI complexity.

**Delivers:** MCPServer (local HTTP or stdio JSON-RPC), semantic tool manifest (get_phoneme_inventory, search_lexicon, get_paradigm_table, analyze_phrase, add_root_word, and others), read/write separation in tool manifest, async tool handlers on isolate.

**Addresses (from FEATURES.md):** AI tutor + co-creator, linguistic terminology Q&A, vocabulary suggestion.

**Avoids (from PITFALLS.md):** Pitfall 7 (semantic tools not raw DB exposure), Pitfall 15 (async handlers, no UI thread blocking).

**Research flag:** MCP Dart library maturity is LOW confidence as of training cutoff (August 2025). Verify current pub.dev state of dart_mcp before Phase 7 planning. If immature, budget ~200 lines of custom JSON-RPC implementation.

### Phase Ordering Rationale

- Layers 0-2 from ARCHITECTURE.md (infrastructure, phonology, morphology) map directly to Phases 1-2 — they are prerequisites for everything upstream.
- Phases 3-4 (lexicon, grammar) depend on Phase 2; they could be partially parallelized but grammar UI needs lexicon data.
- Phase 5 (scratchpad) is the integration phase — it only works when Phases 1-4 are stable.
- Phase 6 (culture wiki) is independent and can be parallelized with Phase 4 if resources allow.
- Phase 7 (MCP) deliberately comes last: the services it wraps must be stable before their API surface is published to an AI agent.

### Research Flags

Phases requiring deeper research during planning:
- **Phase 2 (Morphology Engine):** Pattern mini-language DSL design is a synthesis without a canonical reference. Run a design spike on the syntax surface before committing. Key question: how does the mini-language express phonological conditioning without crossing into scope creep?
- **Phase 7 (MCP):** dart_mcp library maturity is unknown post-training-cutoff. Verify pub.dev state; if immature, implementation path changes significantly.
- **Phase 5 (TTS):** OGG audio playback on Windows with just_audio may require FFmpeg bundling. Verify platform-specific audio decoder availability before finalizing the TTS/audio pipeline design.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Project Shell + Phonology):** Flutter desktop app shell, drift SQLite, Riverpod project scoping — all well-documented official patterns.
- **Phase 3 (Lexicon):** CRUD + FTS5 + reactive Riverpod streams — standard drift patterns.
- **Phase 4 (Grammar):** Paradigm table generation is algorithmic (feature matrix multiplied by morphology engine) — no research needed.
- **Phase 6 (Culture Wiki):** flutter_markdown with custom link syntax — documented extension API.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Architecture recommendations are HIGH; all version numbers are LOW (marked [VERIFY], cannot confirm against live pub.dev) |
| Features | MEDIUM | Competitive analysis is training-data only; ConWorkShop/PolyGlot feature sets should be verified against current versions before finalizing differentiator claims |
| Architecture | HIGH | Layered monolith, Riverpod project scoping, derivation tree schema, plugin-per-morphology-strategy — all grounded in established Flutter and database design principles |
| Pitfalls | HIGH | Concatenative-only morphology failure, flat schema problems, interlinear glosser silent failures, TTS phoneme coverage limits — all well-established failure modes in their respective domains |

**Overall confidence:** MEDIUM-HIGH for architecture and approach; LOW for specific versions and MCP library state.

### Gaps to Address

- **All pub.dev version numbers:** Must be verified against live pub.dev before writing pubspec.yaml. Every version in STACK.md is marked [VERIFY]. Do this before Phase 1 planning.
- **dart_mcp library maturity:** MCP spec was rapidly evolving as of August 2025. Check current state before Phase 7 planning. Decision point: use library or implement ~200 lines of JSON-RPC directly.
- **OGG on Windows (just_audio):** Verify whether just_audio's Windows backend handles OGG natively or requires FFmpeg bundling. Affects IPA audio asset format decision in Phase 1.
- **macOS SSML IPA support (flutter_tts):** AVSpeechSynthesizer's phoneme SSML support should be tested on the development machine before committing to the SSML-based TTS path.
- **ConWorkShop/PolyGlot current feature state:** Both tools are actively developed. Verify competitor feature matrices against current versions before finalizing differentiator claims.
- **Conlanger's Thesaurus PDF extraction:** Parse the PDF once during Phase 3 planning to confirm the pre-extraction-to-JSON approach is feasible with the actual document structure.

---

## Sources

### Primary (HIGH confidence)
- Flutter official docs (docs.flutter.dev) — app architecture, desktop platform status, lifecycle
- Riverpod 2.x official docs (riverpod.dev) — provider scoping, AsyncNotifier, StreamNotifier
- SQLite official docs (sqlite.org/wal.html) — WAL mode, FTS5
- MCP protocol specification (modelcontextprotocol.io) — tool manifest design, JSON-RPC transport
- Linguistics literature (McCarthy 1979 on Arabic root-and-pattern morphology; Comrie, Haspelmath on morphological typology) — morphology strategy taxonomy

### Secondary (MEDIUM confidence)
- Training knowledge of conlang tool ecosystem (ConWorkShop, Vulgar, PolyGlot, Lexique Pro, Zompist SCA2, Awkwords) — feature gap analysis; verify current versions
- r/conlangs and Linguifex community discussions (training corpus) — user-requested features and pain points
- Anki .apkg format documentation (github.com/ankitects/anki) — collection schema
- Conlanger's Thesaurus (fiatlingua.org) — semantic domain coverage approach
- Wikipedia IPA audio files (en.wikipedia.org/wiki/IPA_pulmonic_consonant_chart_with_audio) — Creative Commons audio sourcing

### Tertiary (LOW confidence)
- All pub.dev version numbers in STACK.md — training data estimates; must be verified before use
- dart_mcp package state — was in early development as of August 2025; current maturity unknown
- flutter_tts SSML IPA support on Windows/Linux — documented for macOS; Windows/Linux behavior needs runtime verification

---

*Research completed: 2026-04-08*
*Ready for roadmap: yes*
