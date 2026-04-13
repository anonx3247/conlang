# Pitfalls Research

**Domain:** Adding analytic grammar, interlinear glossing, AI/MCP integration, language evolution, writing systems, and automatic etymology to an existing Flutter desktop conlang workbench
**Researched:** 2026-04-13
**Confidence:** HIGH for Flutter/Drift/Riverpod integration patterns; MEDIUM for MCP-in-Flutter specifics (ecosystem still maturing)

---

## Critical Pitfalls

### Pitfall 1: Drift Schema Jump Without Orphan Table Audit

**What goes wrong:**
v14 is the current schema. Adding v2.0 features means reaching v15–v20+. The `culture_pages` table was created in v13 via raw `customStatement` (not a Drift `Table` class) because the feature was retired to a branch. If a v2.0 Dart `Table` class named `CulturePages` is added to re-enable the wiki, Drift's schema generator will try to create the table on new databases — but existing databases already have it from v13. Drift's `CREATE TABLE IF NOT EXISTS` in `onCreate` does not guard against this for `createAll()`, which creates every declared table unconditionally. The result is a crash on any existing `.conlang` project file.

**Why it happens:**
The v13 migration kept the raw SQL as a forward-compat stub without a corresponding Drift table class. The v2 branch re-adds the class without auditing whether existing DBs already have the table.

**How to avoid:**
Before re-integrating the Culture Wiki from `culture-wiki-v2-staging`, audit every raw `customStatement` in the migration chain. Any table created via raw SQL but not in a Drift `Table` class needs a guard migration: `CREATE TABLE IF NOT EXISTS` or a full drop-and-recreate inside the numbered `from < N` block. The new schema version's `if (from < N)` block for CulturePages must do nothing if the table already exists. Test with a v1.0 project file opened against the v2.0 binary.

**Warning signs:**
- The `culture_pages` table appears in raw SQL migration but not in any `@DriftDatabase(tables: [...])` annotation.
- No test opens a v13 project file against the v2.0 code.
- Migration uses `m.createTable(culturePages)` without a guard.

**Phase to address:** Culture Wiki re-integration phase (first phase that touches `CulturePages`). Non-negotiable pre-condition.

---

### Pitfall 2: Writing Scratchpad Parser Reuses Morphology Engine Incorrectly

**What goes wrong:**
The scratchpad needs to tokenize a phrase, look up each token in the lexicon, and apply morphological reverse-analysis (segmenting an inflected form back to root + rule). The temptation is to feed the existing `MorphologyEngine.apply(rule, root)` in reverse — trying every root × rule combination until an output matches the token. This is O(roots × rules) per token and will freeze the UI for any real lexicon. A 500-word lexicon with 20 rules = 10,000 tries per word.

**Why it happens:**
Forward application (root → inflected form) is cheap. Reverse lookup (inflected form → root) looks like the same operation run backwards. It is not — it is a search problem, not a transformation problem.

**How to avoid:**
Build an indexed reverse lookup table at lexicon load time. For every (root, rule) pair, pre-compute the inflected form and store a map of `inflectedForm → (root, rule)`. This index is built once (or invalidated on rule/lexicon change via Riverpod invalidation) and lookup is O(1) per token. The Scratchpad glosser reads from this index, never from exhaustive forward application.

**Warning signs:**
- The glosser function signature takes `List<LexemeData> allRoots` and `List<MorphologicalRule> allRules` and loops over both.
- No pre-computed reverse lookup table exists.
- The scratchpad noticeably lags on phrases longer than 3 words.

**Phase to address:** Writing Scratchpad phase, before any UI is built. The index architecture must be decided before the first glosser line is written.

---

### Pitfall 3: Analytic Grammar Items Stored as a New Feature Silo Instead of Extending Existing Lexeme System

**What goes wrong:**
Analytic grammar markers (particles, auxiliaries, determiners, classifiers) are treated as a separate data model — a new `AnalyticMarkers` table, a new UI section, new providers. In fact, these are closed-class words in the lexicon with special grammatical roles. The scratchpad then must query two data sources to parse a phrase: the lexicon for open-class words and the analytic system for closed-class words. Cross-feature queries proliferate. The paradigm viewer cannot show how an analytic particle interacts with an inflectional paradigm.

**Why it happens:**
The analytic grammar feature is conceptually new (v2.0 requirement) so it feels like a new system. The existing grammar system handles morphological (synthetic) rules; analytic feels like a different domain.

**How to avoid:**
Analytic grammar markers ARE lexeme entries with a specialized POS and a grammar role flag. Extend the existing `Lexemes` table or `PartsOfSpeech` table with an `isClosedClass` / `analyticRole` column rather than building a parallel table. Phrase-level construction rules live in their own table (they are structural, not lexical), but the markers themselves are just words. The scratchpad's lookup pipeline stays unified: tokenize → check lexicon → apply morphological analysis → check phrase-level construction patterns.

**Warning signs:**
- A `AnalyticMarkers` table is proposed that does not have a `lexemeId` foreign key.
- The scratchpad has two separate "lookup" calls: one for lexicon, one for analytic markers.
- Analytic markers cannot be exported in the Anki export.

**Phase to address:** Analytic Grammar phase — specifically during the data model design plan before any DAO or UI work.

---

### Pitfall 4: MCP Server Built as a Dart Process Inside the Flutter App's Isolate

**What goes wrong:**
The MCP server is implemented as a class that runs inside the Flutter app's main isolate. Tool handlers call Drift queries synchronously (or via `await` on the main thread). Any slow query — a full lexicon scan for semantic search, etymology chain traversal — blocks UI rendering. The Flutter frame budget is 16ms; a 50ms DB query causes 3 dropped frames per AI tool call.

**Why it happens:**
The simplest implementation is a single-process app where everything shares one `AppDatabase` instance. Adding the MCP server as another class in the same process feels natural.

**How to avoid:**
The MCP server must run as a separate Dart process or in a dedicated isolate. The `mcp_server` (pub.dev) and `dart_mcp` packages are both designed for stdio-transport standalone processes — use that architecture. The Flutter app communicates with the MCP server process via a local socket or shared SQLite (read-only access from MCP side). All Drift queries in tool handlers are fully async and run in their own isolate context. Never share a `AppDatabase` instance across isolate boundaries.

**Warning signs:**
- The MCP server class has a constructor that accepts `AppDatabase db`.
- MCP tool handlers use `ref.read(...)` from Riverpod.
- The MCP server is instantiated in `main()` alongside the Flutter app.

**Phase to address:** AI Integration phase — process isolation architecture must be decided in the first plan of that phase.

---

### Pitfall 5: Language Evolution "Apply Sound Change" Mutates the Lexicon Directly

**What goes wrong:**
The sound change modeler applies a historical change (e.g., /p/ → /f/ in all words) and writes the results back to the lexicon. The original phoneme forms are lost. The user cannot see what the language looked like before the change, cannot undo it, and cannot model branching dialect evolution (two different change paths from one ancestor).

**Why it happens:**
"Apply to lexicon" is the obvious implementation — the user wants their lexicon updated. The idea of maintaining a history feels like overengineering for a personal tool.

**How to avoid:**
Language evolution must be non-destructive. Sound changes are stored as an ordered list of rules in a new `SoundChangeLayers` table. The lexicon stores root forms. The evolved forms are computed by applying the change stack to each root at query time (or pre-computed into a cache column). The user can add, remove, reorder, and branch change layers without touching root data. "Apply permanently" is a deliberate one-way migration action with an explicit warning — not the default behavior.

**Warning signs:**
- The "Apply Sound Change" button updates `lexemes.ipa` in place.
- No undo mechanism exists for sound change application.
- The sound change feature has no concept of "layers" or "history."

**Phase to address:** Language Evolution phase, in the data model plan. The non-destructive architecture must be locked in before any apply-logic is written.

---

### Pitfall 6: Writing System Tab Conflates Grapheme Mapping with Custom Font Rendering

**What goes wrong:**
The writing system feature tries to do two things at once: (1) define a grapheme-to-phoneme mapping (orthography rules), and (2) visually render text in a custom script using an uploaded font or SVG glyphs. These are independent concerns. Conflating them means you cannot have a Latin-alphabet orthography without going through the font system, and a conlanger defining a custom abjad cannot test their phoneme mappings until they have drawn glyphs. The feature blocks itself.

**Why it happens:**
"Writing system" sounds holistic. The UI shows a combined "Script Editor" with mapping table and font preview side by side. They feel like one feature.

**How to avoid:**
Phase the feature into two independent deliverables: (1) Grapheme mapping system — which phonemes does each written symbol represent? This is pure data and works immediately with any existing font. (2) Custom glyph rendering — upload a font or define SVG glyphs for custom scripts. Phase 2 of writing system. The scratchpad can use grapheme mappings from day one without waiting for custom font support.

Additionally, Flutter's text rendering uses HarfBuzz for complex script layout. Custom PUA (Private Use Area) Unicode fonts for invented scripts work correctly in Flutter if the font is loaded as an asset and the text widget uses the correct `fontFamily`. Rendering invented scripts via Canvas drawing is unnecessary complexity unless the script is non-linear (e.g., syllable blocks like Hangul-style).

**Warning signs:**
- The writing system data model has no table until font upload is implemented.
- "Custom Script" is listed as a prerequisite for phoneme-to-grapheme mapping.
- Grapheme mapping is designed around `int glyphId` foreign keys rather than Unicode codepoints or text strings.

**Phase to address:** Writing System phase — separate the two concerns in the very first plan.

---

### Pitfall 7: Automatic Etymology Overwrites User-Authored Etymology

**What goes wrong:**
The automatic etymology system detects compound words and derivation chains and populates the `etymology` field on lexeme records. When the user has already written a custom etymology note ("from Proto-Zothic *katar, related to the root for fire"), the auto-detection silently overwrites it.

**Why it happens:**
The auto-detect runs as a background job on lexicon changes and writes to the same `etymology` column used by manual entries. There is no distinction between "auto-generated" and "user-authored" content.

**How to avoid:**
Separate auto-detected etymology from user-authored etymology at the data model level. Add `autoEtymologyJson TEXT` (machine-generated, always overwritable) and keep the existing `etymology TEXT` as the user-authored field (never auto-overwritten). The UI shows auto-detected suggestions below the manual field, with a "Accept suggestion" action that copies auto content into the user field. User field always takes precedence in display.

**Warning signs:**
- The etymology auto-detection writes to the same column as manual entry.
- No `isAutoGenerated` flag or separate column for auto etymology.
- Auto-detection fires immediately on save without user confirmation.

**Phase to address:** Etymology / Lexicon Extras phase, in the first data model plan.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| JSON blobs for analytic grammar construction rules | Avoids schema design debate | Impossible to query; scratchpad cannot JOIN against them; migration is a data rewrite | Never — define typed columns from the start |
| Storing interlinear gloss output in the DB | Avoids re-computing on every load | Gloss becomes stale when rules or lexicon change; invalidation is complex | Only as a display cache with explicit `isCacheDirty` flag |
| Sharing `AppDatabase` between Flutter app and MCP server | Eliminates IPC complexity | Crash risk if MCP isolate holds a write lock during Flutter migration; Drift is not designed for multi-process sharing | Never — use read-only secondary connection or separate process |
| Hardcoding common phrase templates (SVO, SOV) | Quick typology support | Cannot express verb-second, polysynthetic head-marking, or topicalization patterns | Only for MVP if template list is clearly extensible |
| Re-using petitparser grammar directly for phrase parsing | Parser already exists for morphology | Morphology DSL and phrase structure grammar have different token sets and failure semantics; coupling will break both | Never — phrase parser is a separate `PhraseParser` class |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| MCP server + Drift | Passing `AppDatabase` to MCP server class; calling `db.select(...)` from MCP handler isolate | MCP server opens its own read-only SQLite connection via `NativeDatabase.createInBackground`; never shares Drift instance across isolate boundaries |
| Culture Wiki branch re-integration | Adding `CulturePages` Dart table class without checking v13 raw-SQL stub | Check `from < 13` migration for existing `culture_pages` table; use `CREATE TABLE IF NOT EXISTS` guard in v15+ migration if re-adding as typed table |
| petitparser phrase parser | Extending the existing `PhonotacticDsl` or `MorphologyDsl` grammar definitions with phrase-level rules | Create a new `PhraseDsl` / `PhraseParser` with its own `GrammarDefinition`; share only the tokenizer utility |
| Riverpod + MCP server | Watching Riverpod providers from inside MCP tool handlers | MCP server is a plain Dart process with no ProviderContainer; it reads from SQLite directly — it does not participate in the Flutter provider graph |
| GoRouter + new top-level tabs | Adding Scratchpad and Writing System as new `StatefulShellBranch` entries inline with minimal testing | Every new branch index shifts existing branches; `goBranch(index)` call sites in `AppShell._tabs` must be updated atomically with router definition; test routing before any feature work |
| Drift migration + feature flags | Gating new tables behind a feature flag at runtime | Drift schema is static at compile time; if a `Table` is declared it must exist at `schemaVersion N`; never conditionally create tables |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Scratchpad re-glosses on every keystroke | 100–300ms lag typing in scratchpad; UI stutters | Debounce gloss recomputation 300–500ms after last keystroke; gloss runs in an isolate via `Isolate.run()` | Any lexicon > ~200 words with >10 rules |
| Reverse morphology index not invalidated on rule change | Stale glosses after editing a morphological rule until app restart | Riverpod: `scratchpadGlossIndexProvider` depends on `morphologyRulesProvider` and `lexemeListProvider`; auto-invalidated on either change | First time user edits a rule and re-tests in scratchpad |
| Sound change layer stack applied per-render | Evolved form recalculated on every widget build | Pre-compute evolved forms into a cache column; rebuild cache in an isolate when sound change stack changes | Any sound change stack > 5 rules on lexicons > 300 words |
| Language Evolution page watches entire lexicon | Full lexicon stream triggers rebuild on any word edit | Use `select(lexemes).watch()` scoped to evolved-preview columns only; do not watch full lexeme rows for display-only evolution preview | Lexicon > ~500 words |
| MCP tool `search_lexicon` with no index | Full table scan on every semantic search call from AI | Add SQLite FTS5 virtual table for lexeme definitions and romanizations at v15+ schema; FTS5 `MATCH` query is O(log N) | Lexicon > ~200 words under AI-assisted querying |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| MCP tool exposes raw SQL execution (`run_query(sql)`) | AI agent can read/write any table including future sensitive config; no audit trail | All MCP tools are named, typed, read-only by default; write tools require explicit action names; no generic SQL tool |
| MCP write tools with no confirmation step | AI agent accidentally bulk-modifies lexicon on a misunderstood instruction | Write tools return a `DryRunResult` showing what would change; a separate `confirm_action(actionId)` tool commits; Flutter UI shows pending actions |
| MCP server process given write access to project DB | Compromise of MCP process (via malicious prompt injection) can corrupt project file | MCP server process opens DB in read-only mode; writes are proxied through a Flutter-side IPC channel that enforces the action confirmation flow |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Interlinear gloss displayed without error state distinction | User cannot tell if blank slot is "unknown word," "parse error," or "no gloss needed (particle)" | Color + icon per token state: green = glossed, amber = partial match, red = unknown root, grey = closed-class particle (no gloss expected) |
| Writing system tab requires custom font before showing phoneme mappings | User cannot start orthography design until they have drawn glyphs | Grapheme mapping table works immediately with system font; custom font is an optional enhancement column |
| Language evolution shows evolved forms replacing original forms | User loses sense of the original language; cannot compare before/after | Side-by-side view: original form + evolved form; original is always visible; evolved is clearly labeled as "after changes" |
| Analytic grammar particles mixed into full lexicon dictionary view | Dictionary becomes noisy; closed-class words crowd open-class vocabulary | Separate lexicon filter: "All / Open class / Closed class (grammar words)"; default filter excludes particles from main dictionary view |
| AI assistant response appears inline in scratchpad | User does not know if gloss annotation is AI-generated or rule-computed | Distinguish AI suggestions (amber, "AI suggestion" label) from rule-computed glosses (standard) |

---

## "Looks Done But Isn't" Checklist

- [ ] **Writing Scratchpad glosser:** Often "works" on the 3 test words but fails on all inflected forms — verify with a word that has been through 2+ morphological rules applied in sequence
- [ ] **Analytic grammar phrase rules:** Often shows correct word order for SVO but silently accepts SOV — verify that word order rules actually reject violations, not just describe preferred order
- [ ] **Sound change layer stack:** Often applies changes in the right order for simple cases but breaks on feeding (change A creates the environment for change B) — verify with a classical umlaut-style example
- [ ] **MCP tools read-only guarantee:** Often the read-only claim is implemented by convention, not enforcement — verify that the DB connection used by the MCP server has `PRAGMA query_only = ON` set
- [ ] **Culture Wiki re-integration:** The `culture_pages` table exists in v13+ databases via raw SQL but no Dart class — verify that a v13 project file opens without error after Culture Wiki phase
- [ ] **Etymology auto-detection non-destructive:** Often auto-detect writes to `etymology` column — verify that a word with a user-authored etymology note is unchanged after automatic etymology runs
- [ ] **GoRouter branch indices:** When new tabs are added, existing deep links may silently go to wrong tab — verify `/grammar/...` routes still land on Grammar tab after new tabs are inserted

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Drift table created over orphaned raw-SQL stub | HIGH | Write emergency migration `DROP TABLE IF EXISTS culture_pages; CREATE TABLE culture_pages (...)` inside a new `from < N` block; bump schema version; all existing projects get a clean table |
| Reverse morph index never built (forward-only scratchpad) | MEDIUM | Add `scratchpadGlossIndexProvider` as a derived provider; schedule index build as a `FutureProvider`; no data migration needed |
| MCP server on main isolate causing UI jank | MEDIUM | Extract to separate Dart entrypoint; update Claude Desktop / client MCP config to point to new process; no DB schema changes |
| Sound change applied destructively to lexicon | HIGH | Requires data recovery from backup; no automated recovery path — prevention is the only strategy; surface a mandatory backup dialog before any "Apply Permanently" action |
| Auto etymology overwrote user etymology | HIGH | Requires either version history in `project_settings` (new table) or manual re-entry; add `autoEtymologyJson` column and copy existing `etymology` to it; let user choose which to keep |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Drift orphan table (culture_pages) | Culture Wiki re-integration phase, Plan 1 | Open a v1.0 `.conlang` project file with v2.0 binary — no crash, no `table already exists` error |
| Scratchpad reverse lookup brute-force | Writing Scratchpad phase, Plan 1 (architecture) | Glossing a 10-word phrase with 500-lexeme, 20-rule project completes in < 100ms |
| Analytic grammar as parallel silo | Analytic Grammar phase, data model plan | Analytic particles appear in Anki export and in unified lexicon search |
| MCP server on main isolate | AI Integration phase, Plan 1 (process isolation) | MCP tool call during a slow DB operation does not cause any dropped frames in Flutter |
| Destructive sound change | Language Evolution phase, data model plan | "Apply change" does not modify `lexemes.ipa`; original form is always retrievable |
| Writing system scope conflation | Writing System phase, Plan 1 | Grapheme mapping table is usable with zero glyph/font work done |
| Auto etymology overwrite | Lexicon Extras / Etymology phase, data model plan | Word with user-authored etymology is unchanged after auto-detection runs |

---

## Sources

- Drift migration API documentation: https://drift.simonbinder.eu/migrations/api/ — confirmed `addColumn`, `TableMigration`, foreign key pragma patterns
- `mcp_server` pub.dev package: https://pub.dev/packages/mcp_server — stdio transport, tool registration patterns; MEDIUM confidence on multi-isolate behavior (ecosystem still maturing as of 2026)
- `dart_mcp` pub.dev package: https://pub.dev/packages/dart_mcp — alternative Dart MCP implementation
- Flutter MCP server docs: https://docs.flutter.dev/ai/mcp-server — official Flutter team guidance on MCP integration
- Zompist Sound Change Applier notes: https://www.zompist.com/sounds.htm — historical reference for sound change applier limitations (syllable-span changes, feeding order)
- App codebase: `/Users/neosapien/dev/conlang/lib/db/app_database.dart` — schema v14 migration history, v13 raw-SQL culture_pages stub, confirmed existing Drift table declarations
- App codebase: `/Users/neosapien/dev/conlang/lib/router/app_router.dart` — StatefulShellBranch index structure; confirmed branch order dependency
- App codebase: `/Users/neosapien/dev/conlang/lib/features/morphology/domain/morphology_engine.dart` — confirmed forward-only application architecture; no reverse lookup exists
- Drift GitHub issue #3174: https://github.com/simolus3/drift/issues/3174 — ALTER TABLE resolution failures in migration

---
*Pitfalls research for: Conlang Workbench v2.0 — adding analytic grammar, scratchpad, AI/MCP, language evolution, writing systems, etymology to existing Flutter app*
*Researched: 2026-04-13*
