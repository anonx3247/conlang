# Project Research Summary

**Project:** Conlang Workbench v2.0
**Domain:** Flutter desktop constructed-language authoring tool
**Researched:** 2026-04-13
**Confidence:** HIGH (architecture from direct codebase inspection; stack versions live-verified; features competitor-verified; pitfalls codebase-grounded)

## Executive Summary

Conlang Workbench v2.0 extends a working Flutter/Drift/Riverpod desktop app (schema v13, six shipped feature modules) with six new capabilities: analytic grammar, writing scratchpad with interlinear glossing, AI/MCP integration, language evolution via sound change modeling, custom writing systems, and automatic etymology suggestions. The existing architecture is mature and well-patterned — every new feature should follow the established `data/ → domain/ → presentation/` module structure and the null-guard Riverpod provider pattern for no-project state. No major architectural overhaul is needed; this is additive extension work.

The headline differentiator is parse-driven interlinear glossing with full project context — no competitor (PolyGlot, ConWorkShop, SCA2/Zompist) offers it. The combination of automatic morphological reverse-analysis, MCP-powered AI co-creator, and sound change applier with diff output in a single offline desktop app is unmatched as of April 2026. The technical risk center of gravity is the morphological reverse-analysis engine required by the scratchpad: forward application (root → inflected form) is already built; reverse lookup (inflected form → root + rules) must be pre-computed as an indexed map, not brute-forced per token.

The primary architectural risk is accidental data mutation: sound change must never write to live lexeme rows; etymology auto-detection must never overwrite user-authored content; the MCP server must run as a separate process with a read-only DB connection. All three of these are non-negotiable pre-conditions on their respective phases. The build order is fixed by dependency: analytic grammar must exist before the scratchpad tokenizer is built, since the tokenizer reads both lexeme roots and analytic particles as distinct data sources.

---

## Key Findings

### Recommended Stack

The v1.0 stack (drift, riverpod, petitparser, go_router, just_audio, archive, sqlite3) is unchanged. v2.0 adds six packages: `anthropic_sdk_dart ^1.5.0` (Claude API + streaming + MCP), `mcp_client ^1.1.0` + `mcp_server ^1.0.3` (MCP transport layer for Claude Desktop mode), `flutter_tts ^4.2.5` (IPA-driven synthesis via macOS AVSpeechSynthesizer SSML), `flutter_svg ^2.2.4` (SVG glyph rendering for custom script Tier 3), and `flutter_markdown_plus ^1.0.7` (replacement for the discontinued `flutter_markdown`).

Notably, four of the six planned features require no new packages — interlinear gloss layout uses Flutter primitives (Row/Column/WidgetSpan), sound change modeling extends the existing petitparser DSL, automatic etymology uses pure Dart string matching, and the writing system Tier 1 (custom TTF/OTF font) uses Flutter's built-in FontLoader. The AI integration follows a two-mode design: Mode A (in-app chat) sends the Claude API directly with project context in the system prompt; Mode B (MCP server) exposes the project DB as tools for Claude Desktop or the claude CLI.

**Core new technologies:**
- `anthropic_sdk_dart ^1.5.0`: Claude API client — streaming SSE, tool use, extended thinking, built-in MCP; the only well-maintained official-quality Dart Claude SDK
- `mcp_client ^1.1.0` + `mcp_server ^1.0.3`: STDIO transport for spawning/connecting to the local MCP companion process
- `flutter_tts ^4.2.5`: macOS AVSpeechSynthesizer with SSML `<phoneme alphabet="ipa">` — highest-fidelity path for conlang IPA-driven synthesis, offline
- `flutter_svg ^2.2.4`: SVG glyph rendering for users who want in-app glyph definition without external font tools (Tier 3 only)
- `flutter_markdown_plus ^1.0.7`: Drop-in community replacement for discontinued `flutter_markdown`; same API

**macOS entitlement required:** `com.apple.security.network.client` in both entitlement files for Claude API outbound calls.

### Expected Features

**Must have for v2.0 launch (table stakes + P1 differentiators):**
- Interlinear gloss output in Leipzig format — the standard linguistics text analysis output; every conlanger who knows linguistics will expect it immediately
- Tokenization + morpheme boundary detection — prerequisite for all scratchpad features
- Unknown word flagging (red/amber/grey token state) — users expect honest parsing gaps
- Closed-class word inventory (particles, auxiliaries, determiners) — separate from root lexicon; prerequisite for correct scratchpad tokenization
- Orthography-to-phoneme mapping (writing system tab) — grapheme to phoneme rules with priority ordering; parity with PolyGlot's existing feature
- Sound change applier — ordered context-sensitive rules applied to full lexicon with before/after diff; de facto community expectation (SCA2 is the reference, but web-only with no diff)
- MCP server exposing project data as tools — prerequisite for all AI features; exposes phoneme inventory, lexicon, grammar, morphology patterns
- Automatic etymology suggestions — compound detection + derivation chain surfacing as non-destructive suggestions in the word detail panel
- AI chat panel (tutor + co-creator) — built on top of MCP server with minimal added effort

**Should have (add in v2.x iterations after core validated):**
- Interlinear gloss export (LaTeX gb4e / Leipzig.js HTML) — low effort, high credibility signal
- Sound change rule-trace diff (which rule caused each change) — the key differentiator over SCA2
- Custom script rendering in scratchpad (third interlinear tier) — depends on writing system tab being stable
- Allophone-to-phoneme promotion wizard — surgical evolution tool; requires guided multi-table wizard
- Analytic construction rules (phrase slot templates) — builds on closed-class inventory

**Defer to v3+:**
- TTS synthesis — already deferred from v1.0; remains very high complexity
- AI-generated word suggestions with phonotactic filtering — requires stable AI integration first
- Culture wiki (relaunched from staging branch) — needs rework; separate migration risk

**Anti-features to reject outright:** automatic free translation (conlang to English), full NLP pipeline/dependency trees, version-controlled language branching, real-time collaborative editing, bulk AI lexicon generation, in-app glyph/font editor.

### Architecture Approach

v2.0 adds four new top-level feature modules (`scratchpad/`, `evolution/`, `writing_system/`, `ai/`) and two sub-features extending existing modules (analytic grammar under `grammar/`, etymology under `lexicon/`). All follow the established `data/ → domain/ → presentation/` pattern with null-guard Riverpod providers. The `MorphologyEngine` remains the central computation core — the scratchpad adds a reverse-analysis mode (a new `MorphologyAnalyzer` wrapper), not a replacement. The router adds two new top-level `StatefulShellBranch` entries (Scratchpad, Writing System); Evolution nests under the Phonology tab as a fourth sub-tab to keep top-level navigation to five tabs maximum. The MCP server module (`ai/`) has no dedicated UI tab — it lives in the project menu as a settings panel.

**Major components:**
1. `ScratchpadEngine` (new) — orchestrates tokenize → morphological reverse-analysis → interlinear gloss pipeline; reads from `allLexemeListProvider` + new `analyticWordsDaoProvider`
2. `MorphologyAnalyzer` (new, in `morphology/domain/`) — pre-computed indexed reverse-lookup map from inflected forms to (root, rule) pairs; invalidated by Riverpod on lexeme/rule changes
3. `SoundChangeEngine` (new, in `evolution/domain/`) — wraps existing `PhonologicalRewriteRule` DSL; applies ordered rule chain to lexeme IPA forms; returns diff map, never mutates lexemes directly
4. `ProjectSnapshotService` (new, in `ai/data/`) — assembles full project JSON from existing DAOs; used by both MCP server and export features
5. `EtymologySuggester` (new, in `lexicon/domain/`) — pure Dart function run in `compute()` isolate; keyed `FutureProvider.family` per lexeme ID
6. `ScriptRenderer` / `GlyphRenderer` interface (new, in `writing_system/domain/`) — abstracts font-based vs SVG-based glyph rendering behind a common interface

**Schema bumps:** v13 → v14 (AnalyticWords, PhraseRules) → v15+ (SoundChanges, EvolutionProjects, ScriptCharacters, ScriptSettings). No new schema for etymology (uses existing `LexemeParents`) or MCP (read-only).

### Critical Pitfalls

1. **Drift orphan table collision (culture_pages)** — The `culture_pages` table exists in v13+ project files via raw `customStatement` but has no Dart `Table` class. If a v2.0 `CulturePages` Dart class is added without a guard migration, `createAll()` crashes on any existing project file. Audit every raw `customStatement` before touching the Culture Wiki branch; add `CREATE TABLE IF NOT EXISTS` guard in the numbered `from < N` block.

2. **Scratchpad brute-force reverse morphology** — Trying every (root x rule) combination per token is O(roots x rules) per word; freezes UI at any real lexicon size. Must pre-compute an indexed `inflectedForm -> (root, rule)` map at load time. This architecture decision must be locked in before the first line of glosser code.

3. **Analytic grammar as a parallel silo** — Particles/auxiliaries are lexeme entries with a specialized POS and grammar role flag — not a separate data model. Building an `AnalyticMarkers` table without a `lexemeId` foreign key forces two separate lookup queries in the scratchpad and breaks unified lexicon features (search, Anki export).

4. **MCP server on the main Flutter isolate** — Sharing `AppDatabase` across isolate boundaries is unsupported by Drift and causes UI jank. The MCP server must run as a separate Dart process (stdio transport) with its own read-only SQLite connection via `NativeDatabase.createInBackground`. It never participates in the Flutter provider graph.

5. **Destructive sound change application** — Writing evolved forms back to `lexemes.ipa` destroys the original language permanently with no recovery path. Sound changes must be stored as a non-destructive `SoundChangeLayers` stack; evolved forms are computed at query time.

6. **Auto-etymology overwriting user content** — Add a separate `autoEtymologyJson TEXT` column for machine-generated suggestions. The existing `etymology TEXT` column is user-authored and must never be auto-overwritten.

7. **Writing system feature scope conflation** — Grapheme-to-phoneme mapping and custom glyph rendering are independent concerns. Phase them: orthography rules work immediately with any system font; custom font/SVG glyph support is a follow-on enhancement pass.

---

## Implications for Roadmap

Based on the dependency graph in ARCHITECTURE.md and the pitfall-to-phase mapping in PITFALLS.md, a six-phase build order is strongly recommended. The order is fixed by data dependencies, not preference.

### Phase 1: Analytic Grammar
**Rationale:** The scratchpad tokenizer must query both open-class lexemes AND closed-class particles. Building analytic grammar first means the tokenizer can be written once correctly, not patched later. No blocking dependencies on other new features.
**Delivers:** Closed-class word inventory (particles, auxiliaries, determiners, classifiers) with gloss tags; phrase construction rules; word order settings.
**Implements:** `AnalyticWords`, `PhraseRules` tables (schema v14); `AnalyticGrammarDao`; 4th sub-tab in GrammarShell; `AnalyticGrammarEngine`.
**Critical pitfall:** Analytic words MUST be lexeme entries (with `analyticRole` flag / POS link), not an independent silo. Verify: analytic particles appear in unified lexicon search and Anki export.
**Research flag:** Standard patterns — no additional research phase needed.

### Phase 2: Writing Scratchpad
**Rationale:** The headline v2.0 feature. Can only be built correctly once analytic grammar is available (tokenizer reads both data sources). All v1.0 dependencies (morphology engine, phonology rules, lexicon) are stable.
**Delivers:** Text input → tokenize → morpheme reverse-analysis → Leipzig interlinear gloss → IPA transcription tier → unknown word highlighting.
**Critical architecture decision:** Pre-computed `inflectedForm -> (root, rule)` index in `MorphologyAnalyzer`. This must be designed in Plan 1 of this phase before any code.
**Implements:** Full `scratchpad/` feature module; `MorphologyAnalyzer` in `morphology/domain/`; new top-level Scratchpad tab.
**Stack:** No new packages — uses existing petitparser, existing phonology rule engine, existing `allLexemeListProvider`.
**Avoids:** Reverse morphology brute force (Pitfall 2). Use 300ms debounce + `Isolate.run()` for analysis.
**Research flag:** Needs `/gsd-research-phase` — morphological reverse analysis for Semitic root-and-pattern morphology types needs validation; pre-computed index design may require empirical benchmarking.

### Phase 3: Automatic Etymology
**Rationale:** Lightweight additive feature with no new schema. Low-risk and delivers visible value (word detail panel enhancement) while the scratchpad is being validated by users.
**Delivers:** Compound word and derivation chain suggestions in word detail panel; accept/reject UI; `autoEtymologyJson` column for machine-generated content.
**Implements:** `EtymologySuggester` in `lexicon/domain/`; etymology suggestion chips in `WordDetailPanel`.
**Avoids:** Auto-etymology overwrite (Pitfall 6) — separate `autoEtymologyJson` column, never touch user `etymology` field.
**Research flag:** Standard patterns — pure Dart string matching, no deep unknowns.

### Phase 4: Language Evolution
**Rationale:** Reuses the existing `PhonologicalRewriteRule` DSL and `PhonemeInventory` types — no new DSL to write. Depends on phonology being stable (it is). Must be non-destructive by architecture.
**Delivers:** Sound change applier with ordered context-sensitive rules; before/after lexicon diff; `EvolutionProjects` snapshots; allophone-to-phoneme promotion wizard (v2.x).
**Implements:** `SoundChanges`, `EvolutionProjects` tables; `SoundChangeEngine`; `EvolutionDao`; Evolution sub-tab in PhonologyShell.
**Avoids:** Destructive sound change (Pitfall 5) — `SoundChangeLayers` stack, lexeme IPA never modified by preview. Non-destructive architecture locked in Plan 1.
**Research flag:** Needs `/gsd-research-phase` for feeding/bleeding order edge cases — classical Neogrammarian feeding (change A creates environment for change B) is tricky to implement correctly and must be test-driven.

### Phase 5: Writing System
**Rationale:** Self-contained feature with no blocking dependencies on other v2.0 phases. Phases the deliverable into orthography rules first (no font needed), custom rendering second.
**Delivers:** Grapheme-to-phoneme mapping rules with priority ordering; custom TTF/OTF font loading via `FontLoader`; SVG glyph tier via `flutter_svg`; custom script tier in scratchpad interlinear display.
**Implements:** `ScriptCharacters`, `ScriptSettings` tables; `ScriptRenderer` + `GlyphRenderer` interface; `WritingSystemShell` new top-level tab.
**Avoids:** Writing system scope conflation (Pitfall 7) — grapheme mapping table works from day one with zero glyph/font work; font rendering is an additive enhancement pass.
**Research flag:** Standard patterns for font loading and flutter_svg. GlyphRenderer interface is straightforward composition.

### Phase 6: AI / MCP Integration
**Rationale:** The MCP server exposes what already exists in the app. Building it last means the tool API surface is stable and complete — `get_phoneme_inventory`, `search_lexicon`, `get_paradigm_table`, `analyze_phrase` all have stable backing services.
**Delivers:** Local MCP server (stdio transport) exposing project data as read-only tools; in-app AI chat panel (Mode A: direct Claude API with system prompt context); `ProjectSnapshotService`; MCP settings panel in project menu.
**Implements:** Full `ai/` feature module; `ProjectSnapshotService`; `mcp_server` stdio process; `anthropic_sdk_dart` streaming chat widget.
**Stack:** `anthropic_sdk_dart ^1.5.0`, `mcp_client ^1.1.0`, `mcp_server ^1.0.3`.
**Avoids:** MCP on main isolate (Pitfall 4) — separate Dart process with read-only `NativeDatabase.createInBackground`; never shares `AppDatabase` instance; never uses Riverpod providers from within MCP handlers.
**Security constraints:** All MCP tools are named, typed, read-only by default. Write tools return `DryRunResult` first; a separate `confirm_action(actionId)` tool commits. No generic SQL execution tool.
**Research flag:** Needs `/gsd-research-phase` — MCP ecosystem in Flutter is still maturing; multi-isolate Drift behavior under MCP tool calls needs empirical validation; confirm STDIO transport works on macOS/Windows/Linux.

### Phase Ordering Rationale

- Analytic grammar before scratchpad is mandatory — the tokenizer has two lexical data sources; building it before both sources exist forces a rewrite
- Scratchpad before all others (except analytic grammar) because it is the headline feature and must be validated against real usage before dependent v2.x features are built
- Etymology before evolution because it is lower risk, delivers value sooner, and has no dependency relationship with evolution
- Writing system before AI because the MCP server's `analyze_phrase` tool is richer with custom script output available; the writing system scratchpad tier should be stable before AI integration references it
- AI last because it exposes everything else; a stable, complete API surface at build time prevents tool redesign mid-implementation

### Research Flags

Phases likely needing `/gsd-research-phase` during planning:
- **Phase 2 (Scratchpad):** Morphological reverse analysis architecture — particularly for Semitic root-and-pattern morphology types; pre-computed index design needs validation
- **Phase 4 (Language Evolution):** Sound change feeding/bleeding order handling; classical Neogrammarian edge cases need test-driven design
- **Phase 6 (AI/MCP):** MCP ecosystem maturity on Flutter desktop; multi-isolate Drift behavior; STDIO transport cross-platform reliability

Phases with standard well-documented patterns (skip research-phase):
- **Phase 1 (Analytic Grammar):** Standard Drift schema extension + Riverpod provider pattern; fully established
- **Phase 3 (Etymology):** Pure Dart string matching + FutureProvider.family; no unknowns
- **Phase 5 (Writing System):** Flutter FontLoader + flutter_svg patterns are documented; GlyphRenderer interface is straightforward composition

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All 6 new package versions live-verified on pub.dev as of 2026-04-13; no version conflicts with existing Dart SDK ^3.10.4 |
| Features | MEDIUM-HIGH | PolyGlot, SCA2, Leipzig Glossing Rules verified live April 2026; ConWorkShop partial; competitive gap analysis is solid |
| Architecture | HIGH | Derived entirely from direct codebase inspection (schema v13, router, app_shell, provider patterns) — not assumptions |
| Pitfalls | HIGH (Flutter/Drift/Riverpod); MEDIUM (MCP-in-Flutter) | MCP ecosystem still maturing; multi-isolate behavior needs empirical validation |

**Overall confidence:** HIGH

### Gaps to Address

- **MCP multi-isolate Drift behavior:** MEDIUM confidence — the `mcp_server` package's behavior under concurrent reads alongside a Flutter Drift instance needs empirical validation during Phase 6 Plan 1. Fallback: implement lightweight JSON-RPC over STDIO manually (~200 lines) if the package proves problematic.
- **Semitic morphology reverse analysis:** The existing `MorphologyEngine` was designed for agglutinative patterns. Root-and-pattern template matching in reverse is algorithmically different. Phase 2 research should validate whether the existing engine's type system accommodates it or whether a separate code path is needed.
- **GoRouter branch index shifts:** Adding Scratchpad and Writing System as new `StatefulShellBranch` entries shifts existing branch indices. Every `goBranch(index)` call site in `app_shell.dart` must be updated atomically; test routing before any feature work begins in Phase 2.
- **Culture wiki re-integration timing:** The `culture_pages` table exists in v13 via raw SQL without a Dart class. If the culture wiki is re-introduced from `culture-wiki-v2-staging` in a future phase (v3+), the orphan table migration (Pitfall 1) is the first task. No phase in this roadmap touches it, but the risk must be flagged.

---

## Sources

### Primary (HIGH confidence)
- `/Users/neosapien/dev/conlang/lib/db/app_database.dart` — schema v13/v14 migration history, table declarations, raw SQL culture_pages stub
- `/Users/neosapien/dev/conlang/lib/router/app_router.dart` — StatefulShellBranch structure, branch indices
- `/Users/neosapien/dev/conlang/lib/features/morphology/domain/morphology_engine.dart` — forward-only architecture confirmed; no reverse lookup
- `/Users/neosapien/dev/conlang/lib/features/grammar/data/grammar_providers.dart` — Riverpod/Drift constraint documentation inline
- [Leipzig Glossing Rules (MPI Eva)](https://www.eva.mpg.de/lingua/resources/glossing-rules.php) — interlinear format standard
- pub.dev/packages/anthropic_sdk_dart — v1.5.0 live-verified
- pub.dev/packages/mcp_client — v1.1.0 live-verified
- pub.dev/packages/mcp_server — v1.0.3 live-verified
- pub.dev/packages/flutter_tts — v4.2.5 live-verified
- pub.dev/packages/flutter_markdown_plus — v1.0.7 live-verified

### Secondary (MEDIUM confidence)
- [PolyGlot documentation](https://draquet.github.io/PolyGlot/readme.html) — verified April 2026; confirmed absent features
- [Zompist SCA2](https://www.zompist.com/sounds.htm) — sound change applier reference; web-only, no diff
- [FrathWiki software tools list](https://www.frathwiki.com/Software_tools_for_conlanging) — ecosystem overview
- [Model Context Protocol spec](https://modelcontextprotocol.io/specification/2025-11-25) — MCP standard
- [Drift migration API](https://drift.simonbinder.eu/migrations/api/) — migration patterns
- [Flutter MCP server docs](https://docs.flutter.dev/ai/mcp-server) — Flutter team guidance

### Tertiary (LOW confidence / needs validation)
- MCP multi-isolate Drift behavior — needs empirical validation during Phase 6 Plan 1
- `mcp_server` pub.dev package multi-process behavior — ecosystem still maturing per research notes

---
*Research completed: 2026-04-13*
*Ready for roadmap: yes*
