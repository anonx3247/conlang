# Domain Pitfalls: Conlang Workbench

**Domain:** Desktop conlang construction tool (Flutter + SQLite + MCP + TTS)
**Researched:** 2026-04-08
**Confidence:** MEDIUM — no live web access; based on training knowledge of Flutter desktop, linguistics tooling, SQLite design patterns, TTS limitations, and MCP SDK behavior. All claims are grounded in well-established patterns across these domains.

---

## Critical Pitfalls

Mistakes that cause rewrites or make the tool fundamentally unusable.

---

### Pitfall 1: Morphology Engine Designed for Concatenative-Only

**What goes wrong:** The pattern mini-language is prototyped with affixes (prefix, suffix, infix) as the mental model and every other morphology type gets bolted on as special cases. Semitic root-and-pattern morphology (triconsonantal) and fusional morphology (where a single morpheme carries multiple features simultaneously) then become impossible to express without ugly workarounds.

**Why it happens:** Agglutinative morphology is the easiest to implement (string concatenation), so early demos work great. The builder assumes other types are just variations. They are not — triconsonantal roots require a separate slot for the consonant skeleton and a separate pattern template (`C1aC2aC3` → root `k-t-b` yields `katab`). Fusional morphology requires that a single form can encode tense + aspect + person + number with no decomposable boundary.

**Consequences:** Users building Semitic-inspired or Classical-inspired conlangs hit a wall. The workaround is embedding root slots as named captures in a regex-like syntax, which is not obvious and breaks the "readable" goal. If the core pattern type system does not include at minimum: (1) linear templates with named slots, (2) vowel-pattern overlays, and (3) feature-bundle → form tables, the engine cannot cover the stated scope without a full rewrite.

**Prevention:**
- Design the pattern type system around a taxonomy of morphological strategies before writing any parsing code: concatenative (affixation), templatic (root-and-pattern), ablaut/vowel change, suppletive (lookup table), analytic (separate word, no morpheme manipulation).
- Each type needs its own representation in the data model and its own evaluation path. Do not attempt to unify them into one regex-like syntax — instead let the mini-language have named pattern kinds: `AFFIX`, `TEMPLATE`, `ABLAUT`, `LOOKUP`.
- Prototype a triconsonantal root test case in week 1 of morphology engine design. If it cannot be expressed cleanly, the abstraction is wrong.

**Detection (warning signs):**
- You find yourself adding a "root slot" concept as an afterthought to an affix-based pattern type.
- A Semitic-style derivation requires more than 2 levels of nesting to express.
- The pattern string for a triconsonantal root looks like a regex hack (`${C1}a${C2}a${C3}`) rather than a declared template type.

**Phase:** Address in Phase 1 (morphology engine core). Do not defer.

---

### Pitfall 2: Pattern Mini-Language Scope Creep into a Full DSL

**What goes wrong:** The "like regex but clearer" pattern language keeps gaining features — conditionals, variable binding, function calls, loops — until it is a Turing-complete language. Parsing it requires a real compiler pipeline, error messages become cryptic, and users who are linguists (not programmers) cannot write or debug patterns.

**Why it happens:** Each new language type reveals a new need. Agglutinative needs ordered affix slots. Templatic needs named captures. Phonological conditioning needs if-then rules. Tone sandhi needs lookahead. Each addition seems small. The sum is a programming language.

**Consequences:** The mini-language becomes harder to parse than natural language. Users copy-paste patterns they don't understand. Debugging a derivation failure requires stepping through DSL execution. This is the opposite of the stated goal ("readable, language-based").

**Prevention:**
- Define the ceiling in advance: the mini-language handles form transformation only (string → string with named morpheme slots). It does not handle conditionality beyond phonological environment matching (`/ _V` suffix-before-vowel style notation). More complex conditioning goes in the "phonological rules" system, not the morphology pattern.
- Phonological conditioning rules (vowel harmony, assimilation) belong in a separate phonology rule engine that post-processes morphology output. Keep the two systems separate.
- Write a one-page spec for the mini-language syntax before implementing it. If the spec exceeds one page, cut features.

**Detection:**
- The pattern parser has more than 500 lines of code.
- You add an "escape hatch" to embed Dart/regex directly inside a pattern.
- A linguist beta tester cannot write a simple suffix from looking at existing examples.

**Phase:** Address in Phase 1. Write the spec first, implement second.

---

### Pitfall 3: Interlinear Glosser Fails Silently on Unknown Words

**What goes wrong:** The writing scratchpad parser tokenizes input and attempts morphological analysis. When it encounters an unknown root or an unapplied rule, it returns an empty gloss slot rather than an explicit gap marker. The user sees a blank and cannot tell whether the tool found no analysis or produced no output due to a bug.

**Why it happens:** The glosser is built optimistically — it tries to match, returns results if found, returns nothing if not found. "Graceful degradation" is interpreted as "show nothing for unknowns." But conlang writers are working with incomplete lexicons by definition; unknowns are the normal case, not an edge case.

**Consequences:** Users cannot trust gloss output. A blank could mean "word not in lexicon," "morphological rule failed," "tokenization error," or "parser bug." The scratchpad becomes untrustworthy. Users stop using it.

**Prevention:**
- Define an explicit result type for each token slot: `GLOSSED`, `UNKNOWN_ROOT`, `PARTIAL_MATCH`, `RULE_FAILED`, `TOKENIZATION_ERROR`. Each renders differently in the UI (color, icon, tooltip).
- "Unknown" is a first-class result, not an absence of result. Design this into the data model from day one.
- The glosser must always return a result object, never null or empty, for every token.

**Detection:**
- The gloss function returns `String?` or `List<Gloss>?` (nullable).
- Empty slots in the interlinear display have no tooltip.
- You cannot distinguish "not in lexicon" from "parser threw exception" from the UI.

**Phase:** Address in Phase 2 (writing scratchpad). Required before any user testing.

---

### Pitfall 4: SQLite Schema Treats Words as Flat Records

**What goes wrong:** The lexicon table has columns like `word TEXT, definition TEXT, part_of_speech TEXT, etymology TEXT`. Derived words store their full form, not their derivation path. When a morphological rule changes, every derived word must be manually updated.

**Why it happens:** It's the obvious first schema. It works for simple word lists (Anki-style). It does not work for a morphology engine where derived forms must be recomputable from roots + rules.

**Consequences:** Schema is correct for an Anki deck, wrong for a morphology workbench. Changing a suffix rule means re-deriving hundreds of words manually. Phonological rule changes cascade incorrectly. The "derived word" and "root word" become structurally identical in the database, losing the derivation relationship.

**Prevention:**
- Separate the schema into at minimum three tables: `roots` (the lexical root with its underlying form), `morphological_rules` (the pattern definitions), and `derived_forms` (root_id + rule_ids + computed_form). Derived forms are computed, not stored as authoritative strings.
- Store derivation as a tree or DAG: `derived_from_root_id`, `applied_rules` (ordered list of rule IDs), `computed_form TEXT` (cacheable but regenerable).
- The "form" column on a derived word is a cache, not the source of truth. The source of truth is the root + rule chain.

**Detection:**
- The `words` table has no foreign key to a `roots` table.
- Changing a suffix rule requires a migration script that touches word records.
- "Etymology" is stored as a free-text string rather than as a structured derivation chain.

**Phase:** Address in Phase 1 (schema design). Schema mistakes compound over time and are expensive to fix.

---

### Pitfall 5: Flutter Desktop Text Input Breaks for IPA and Custom Scripts

**What goes wrong:** Flutter's text input system works well for Latin keyboard input. Custom IPA characters entered via the built-in IPA keyboard widget go through a text composition pipeline that does not handle combining diacritics (e.g., `a` + combining tilde `̃` = `ã`) correctly. Characters appear out of order, compose incorrectly, or cursor positioning breaks.

**Why it happens:** Flutter's `TextEditingController` works with UTF-16 code units, not grapheme clusters. IPA includes many characters that are base + combining diacritic pairs (NFD decomposition). If the IPA keyboard inserts characters as separate code points rather than precomposed NFC forms, the controller mishandles cursor position, selection, and deletion.

**Consequences:** Users typing IPA phoneme entries or conlang text find that backspace deletes only the diacritic, not the full character. Selection highlights half a character. Copy-paste produces incorrect Unicode. The IPA keyboard becomes unreliable.

**Prevention:**
- Always insert IPA characters as NFC-normalized, precomposed strings. Never insert base + combining diacritic as separate insertions.
- Use the `characters` package (Flutter team's grapheme cluster library) for all cursor position and selection calculations in custom text fields.
- Test the IPA keyboard with at minimum: tonal diacritics (ˈ, ˌ), nasalization (◌̃), length marks (ː), and retroflex characters (ṭ, ḍ) before considering it complete.

**Detection:**
- Backspace in the IPA keyboard deletes one code unit, not one character.
- The `characters` package is not in pubspec.yaml.
- IPA input is tested only with simple, precomposed characters (e, i, a) not with combining forms.

**Phase:** Address in Phase 2 (IPA keyboard widget implementation).

---

## Moderate Pitfalls

---

### Pitfall 6: TTS for Conlangs Treated as a Solvable Audio Problem

**What goes wrong:** The plan assumes that some TTS service (cloud or local) can synthesize conlang speech by feeding it phoneme sequences or IPA strings. No existing TTS model handles arbitrary phoneme inventories. Every production TTS system — including neural TTS (Coqui TTS, ElevenLabs, Google Cloud TTS, Azure TTS) — is trained on specific languages. They will mispronounce, skip, or hallucinate phonemes not in their training inventory.

**Why it happens:** The IPA string is treated as a universal phonetic address. In theory, if you tell a TTS engine "say /katab/", it should be able to produce those sounds. In practice, TTS models are not phoneme synthesizers — they are acoustic models conditioned on language-specific priors.

**Consequences:** TTS output sounds like the closest natural language phoneme mapping (typically English), not the conlang. Retroflex consonants are approximated. Unusual vowels are wrong. The feature becomes misleading — users think their conlang sounds like what's played, but it's an English-distorted approximation.

**Prevention:**
- Scope TTS as "best-effort approximation using closest natural language model" and communicate this explicitly in the UI ("sounds may not accurately reflect your phoneme definitions").
- Consider a concatenative synthesis fallback: record reference audio for each phoneme the user defines (or pull from IPA chart recordings), then concatenate phoneme audio clips with simple cross-fading. This produces correct phonemes at the cost of naturalness.
- Prioritize phoneme-by-phoneme audio playback (from the IPA reference chart recordings) as a validated alternative to TTS. Users can "play" each phoneme in sequence if full TTS is unsatisfactory.
- Neural TTS as a stretch goal, not a core feature.

**Detection:**
- The spec says "TTS synthesis" without specifying which engine and what its phoneme coverage is.
- No phoneme-by-phoneme fallback is planned.
- TTS is listed as Phase 1 rather than a later phase.

**Phase:** Defer TTS to Phase 3+. Implement phoneme audio playback (from Wikipedia IPA recordings) in Phase 1 as the reliable foundation.

---

### Pitfall 7: MCP Server Exposes Raw Database Tables

**What goes wrong:** The MCP server implementation creates tools that directly expose SQL queries: `query_lexicon(sql: str)`, `get_word(id: int)`. The AI agent then writes its own SQL to interrogate the database. This creates: (1) a security surface where the AI can read/write any table, (2) no semantic understanding of what the data means, (3) fragility when schema changes.

**Why it happens:** It's the fastest way to make "all project data" available. Writing one MCP tool that executes arbitrary SQL is easier than writing 20 semantically meaningful tools.

**Consequences:** The AI agent operates on raw IDs and table names rather than linguistic concepts. Prompt quality degrades because the AI must understand the schema to use the tool. Schema changes break all AI interactions. The AI can accidentally modify data via a poorly framed tool call.

**Prevention:**
- Design MCP tools around linguistic operations, not database operations: `get_phoneme_inventory()`, `search_lexicon(query, pos_filter)`, `get_morphological_rules_for(word)`, `analyze_phrase(text)`, `suggest_root_for_meaning(concept)`.
- Read-only tools by default. Write tools require explicit action names (`add_word`, `update_rule`) and return confirmation before committing.
- The MCP server is a semantic API over the database, not a database proxy.

**Detection:**
- MCP tools have parameters named `table`, `sql`, or `id`.
- The AI agent's system prompt includes database schema instructions.
- No distinction between read tools and write tools in the tool manifest.

**Phase:** Address in Phase 3 (MCP integration). Design tool signatures before implementation.

---

### Pitfall 8: Phonotactics Checker as Regex on Surface Forms

**What goes wrong:** Phonotactics rules are implemented as regex patterns on the orthographic/transcription string. `CV` structure checking runs on the written word, not on the phonological representation. Allophonic variation, syllable boundary ambiguity, and cluster spanning syllable boundaries all produce false positives.

**Why it happens:** Writing a phonotactics regex on the surface form is fast and visible. The phoneme inventory is already defined; checking "does this word match CV(C)(C)V?" against the transcription string seems reasonable.

**Consequences:** Words with complex onset clusters that are phonotactically valid get flagged. Loanwords with exceptional phonotactics that the user explicitly allowed still get flagged because the exception system wasn't built. Users start ignoring all red highlighting because it's too noisy.

**Prevention:**
- Phonotactics operates on the phoneme sequence (the underlying phonological representation), not the orthographic string. The mapping from written form to phoneme sequence uses the Latin transcription mappings defined in the phonology tab.
- Syllabification is a separate step: parse phoneme sequence → apply syllabification algorithm (sonority sequencing principle as default, user-overridable) → check each syllable against phonotactics constraints.
- Per-word exception flagging must be in the data model from the start, not added later.

**Detection:**
- Phonotactics rules are stored as regex strings.
- The phonotactics checker takes a `String word` parameter rather than a `List<Phoneme>` parameter.
- No syllabification step exists in the code.

**Phase:** Address in Phase 1 (phonology system). The phoneme representation layer must underlie everything.

---

### Pitfall 9: Flutter Desktop Window Management and State Loss

**What goes wrong:** Flutter desktop apps on macOS lose focus state when the user switches away and returns. If the app does not persist UI state (scroll position, open tabs, cursor position in the scratchpad, unsaved draft text), users working in "pop-in sessions" (casual, interrupted workflows) repeatedly lose context.

**Why it happens:** Mobile apps assume foreground/background lifecycle. Desktop apps are expected to persist state across focus changes, minimize/restore cycles, and even OS restarts. Flutter's desktop lifecycle support is less documented than mobile, and state restoration is not automatic.

**Consequences:** A casual user who pops into the app to add a word, switches to a browser to check something, returns to the app, and finds the scratchpad text gone will stop trusting the tool. "Pop-in session" workflow is explicitly described as the target use case — this directly breaks the UX promise.

**Prevention:**
- Implement continuous auto-save for all text fields (debounced, ~500ms after last keystroke). Never rely on explicit save actions for scratchpad content.
- Use `shared_preferences` or direct SQLite writes to persist UI state: active tab, scroll offsets, open project, scratchpad content. Restore on app launch.
- Test the "interrupt and return" scenario explicitly: open app, type in scratchpad, switch to another app for 30 seconds, return, verify everything is exactly as left.

**Detection:**
- Scratchpad content is stored only in a `TextEditingController` with no persistence.
- There is no auto-save mechanism in the app.
- State restoration is not listed in the feature set.

**Phase:** Address in Phase 1 (app shell and project management). Auto-save is infrastructure, not a feature.

---

### Pitfall 10: IPA Audio Sourced from Wikipedia at Runtime

**What goes wrong:** The IPA reference chart plays audio by fetching Wikipedia's audio files at runtime (e.g., `https://upload.wikimedia.org/wikipedia/commons/...`). These URLs are not stable — Wikipedia media URLs change when files are re-uploaded, renamed, or reorganized. The app goes offline and all IPA audio stops working.

**Why it happens:** The Wikipedia IPA chart links are well-known and easily discovered. Building a runtime fetcher seems simpler than bundling audio files.

**Consequences:** The IPA reference chart becomes non-functional without internet and breaks whenever Wikipedia reorganizes its files. Users in the field (offline) cannot use IPA reference audio. The feature that should "just work" becomes unreliable.

**Prevention:**
- Bundle IPA audio files as app assets. The full set of IPA sounds (roughly 100-120 WAV/OGG files) is small enough (~5-10 MB) to ship with the app.
- Download the Wikipedia IPA audio files once during development, verify license (Creative Commons), bundle as assets. Reference by phoneme ID, not URL.
- Provide an offline-first experience: the IPA chart must work without internet. Wikipedia is the source during development, not at runtime.

**Detection:**
- The IPA audio player makes HTTP requests at runtime.
- IPA audio files are not in the assets/ directory.
- The IPA chart feature is marked "requires internet."

**Phase:** Address in Phase 1 (phonology tab). Bundle before shipping any version.

---

### Pitfall 11: Conlanger UX Anti-Pattern — Forcing Completeness Before Use

**What goes wrong:** The tool requires users to fully define the phoneme inventory before they can add words, fully define word classes before they can write grammar rules, and fully define grammar before they can use the writing scratchpad. The tool enforces a "correct" linguistics workflow that doesn't match how conlangers actually work.

**Why it happens:** The tool is built as a pipeline (phonology → lexicon → grammar → text) and the UI reflects this. It seems logically correct that you define sounds before words.

**Consequences:** Conlangers work iteratively and non-linearly. They might start with three words and a vibe, then discover their phonology from the words. Forcing completeness before use blocks the "pop-in session" workflow. Users cannot explore the tool incrementally — they must commit to a full language plan before seeing any output.

**Prevention:**
- Every feature works with zero prior setup. The phonotactics checker works with an empty phoneme inventory (it checks nothing and shows no violations). The morphology engine works with no rules defined (it shows identity transforms). The writing scratchpad works before any lexicon entries exist (shows all tokens as UNKNOWN_ROOT).
- Default states are "permissive, not restrictive." Add validation as opt-in configuration, not a prerequisite gate.
- Onboarding flow: create a project → go directly to any tab → the tool helps where it can, shows gaps where it can't.

**Detection:**
- Any screen has a "you must complete step X first" guard that prevents navigation.
- Empty states show error messages rather than empty-but-functional states.
- A new project cannot reach the writing scratchpad without data entry.

**Phase:** Address in Phase 1 (app shell). Empty state design is architecture.

---

## Minor Pitfalls

---

### Pitfall 12: Declension/Conjugation Charts Hardcoded to Familiar Categories

**What goes wrong:** The grammar tab's paradigm chart generator assumes a fixed set of grammatical categories: person (1/2/3), number (sg/pl), gender (m/f/n), tense (past/present/future). Conlangs with evidentiality, clusivity, quadrivalent voice, or aspect-first systems cannot be represented.

**Prevention:** Grammar categories are user-defined. The paradigm chart generator takes a list of user-defined feature dimensions and generates a chart of the appropriate shape. Don't hardcode grammatical categories — they are data, not code.

**Phase:** Address in Phase 2 (grammar system design).

---

### Pitfall 13: Anki Export Loses Morphological Structure

**What goes wrong:** Anki export generates flat cards: front = conlang word, back = definition. Derived words are exported without their etymology or morphological breakdown. Users studying their own conlang lose the very thing the workbench was tracking.

**Prevention:** Export templates should include etymology/derivation chain, morphological gloss, and example sentence from the scratchpad. Make the template configurable. The Anki note type should have fields for: word, pronunciation, definition, derivation, example, gloss.

**Phase:** Address in Phase 2 (lexicon export). Minor in scope, but correctness matters.

---

### Pitfall 14: Swadesh List Integration as a One-Time Import

**What goes wrong:** The Swadesh list is imported once and becomes a static table. As the user's conlang develops, they cannot easily see "which Swadesh concepts are still uncovered" because the coverage check is manual.

**Prevention:** The Swadesh list (and Conlanger's Thesaurus concepts) should have a live coverage view: which concepts have a word defined, which are empty, which have multiple competing words. This is a query over the lexicon, not a static import.

**Phase:** Address in Phase 2 (lexicon tab). Low complexity, high value.

---

### Pitfall 15: MCP Tool Latency Blocks the UI Thread

**What goes wrong:** The AI agent's MCP tools run synchronously and the Dart MCP server implementation blocks on database queries. If a `search_lexicon` call takes 200ms, the UI freezes for 200ms during AI interactions.

**Prevention:** All MCP tool handlers must be async and run database queries on an isolate or background thread. The Flutter app's database access layer should already be async (using `sqflite`'s async API). Never call MCP tool handlers synchronously from the main isolate.

**Phase:** Address in Phase 3 (MCP integration). Standard async hygiene, not a complex fix.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Morphology engine (Phase 1) | Concatenative-only design (Pitfall 1) | Prototype triconsonantal root on day 1 |
| Pattern mini-language (Phase 1) | DSL scope creep (Pitfall 2) | Write the spec ceiling before any code |
| SQLite schema (Phase 1) | Flat word records (Pitfall 4) | Design derivation tree schema upfront |
| App shell / state (Phase 1) | State loss on focus change (Pitfall 9) | Auto-save infrastructure from day 1 |
| IPA audio (Phase 1) | Runtime Wikipedia fetches (Pitfall 10) | Bundle assets during development |
| Phonotactics (Phase 1) | Regex on surface form (Pitfall 8) | Build phoneme representation layer first |
| Empty states (Phase 1) | Completeness-forcing UX (Pitfall 11) | Design empty states before populating |
| IPA keyboard (Phase 2) | Combining diacritics / cursor (Pitfall 5) | Use `characters` package, NFC normalization |
| Writing scratchpad (Phase 2) | Silent failure on unknowns (Pitfall 3) | Explicit result type enum from the start |
| Grammar system (Phase 2) | Hardcoded categories (Pitfall 12) | User-defined feature dimensions |
| Anki export (Phase 2) | Flat cards (Pitfall 13) | Configurable export template |
| MCP integration (Phase 3) | Raw DB exposure (Pitfall 7) | Semantic API, read/write separation |
| MCP async (Phase 3) | UI thread blocking (Pitfall 15) | Async tool handlers on isolate |
| TTS (Phase 3+) | No model handles arbitrary phonemes (Pitfall 6) | Scope as best-effort, phoneme concat fallback |

---

## Sources

**Confidence notes:**
- Flutter desktop text handling (Pitfall 5): HIGH confidence — `characters` package behavior is well-documented by the Flutter team; combining diacritic issues in `TextEditingController` are a known class of bugs.
- Morphology engine design (Pitfalls 1, 2): HIGH confidence — Semitic morphology's incompatibility with concatenative-only systems is a fundamental linguistics principle (McCarthy 1979 on Arabic root-and-pattern morphology). Well-established in the field.
- SQLite schema for linguistic data (Pitfall 4): HIGH confidence — derivation tree vs flat record is a standard database normalization issue.
- Interlinear glosser failure modes (Pitfall 3): HIGH confidence — this is a known pattern in NLP tooling; "unknown" as a first-class state is standard practice.
- TTS for arbitrary phoneme inventories (Pitfall 6): HIGH confidence — neural TTS models are language-specific, not phoneme-synthesizers. This is a well-understood limitation.
- MCP server design (Pitfalls 7, 15): MEDIUM confidence — based on MCP SDK patterns and standard API design principles. MCP is relatively new (2024); specific implementation gotchas may have evolved.
- Flutter desktop lifecycle / state (Pitfall 9): MEDIUM confidence — Flutter desktop lifecycle documentation was less mature as of training cutoff; the behavioral pattern described is well-established but API specifics may have changed.
- Wikipedia IPA audio URLs (Pitfall 10): MEDIUM confidence — URL instability is a documented concern with Wikipedia media; the recommendation to bundle assets is standard practice.
- Conlanger UX patterns (Pitfall 11): MEDIUM confidence — based on the described user workflow and general UX principles for creative/iterative tools.
- Grammar category hardcoding (Pitfall 12): HIGH confidence — this is a fundamental issue in any tool that assumes a specific grammar typology.
