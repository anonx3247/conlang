# Feature Landscape

**Domain:** Conlang construction desktop software
**Researched:** 2026-04-08
**Confidence:** MEDIUM — based on training knowledge of existing tools (ConWorkShop, Vulgar, PolyGlot, Lexique Pro, Zompist tools, LangMaker, Awkwords, Linguifex community). Web verification was unavailable during this research session; critical competitive claims should be verified against current tool feature pages before finalizing roadmap.

---

## Table Stakes

Features users expect from any serious conlang tool. Missing = product feels incomplete or half-baked. Users will leave or not adopt.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Phoneme inventory definition | Every conlang starts with sound system; ConWorkShop, Vulgar, PolyGlot all have this | Low-Med | Consonant + vowel tables organized by articulation; suprasegmentals (tone, stress) add complexity |
| IPA input / keyboard | Conlangers think in IPA; typing special characters is otherwise painful | Med | Unicode IPA is standard; a floating IPA picker widget is the baseline; full keyboard is differentiating |
| Lexicon / dictionary management | Core persistent artifact of any conlang | Med | At minimum: word, part of speech, definition, notes. ConWorkShop has extensive lexicon management |
| Word-level search and filter | Lexicons grow to thousands of entries; findability is critical | Low | Search by form, gloss, POS, tags |
| Part-of-speech tagging | Required for grammar and morphology | Low | Predefined POS set + user-defined extensions |
| Declension / conjugation tables | Users expect to see paradigm tables for nouns/verbs; PolyGlot has this | Med-High | "Show me all forms of word X" is the single most-requested feature in conlang communities |
| Text export / plain-text copy | Users share their work in forums, Discord, Google Docs | Low | Copy as plain text, export word lists as CSV/TSV |
| Grammar documentation section | Users need to write grammar rules alongside their data | Low-Med | Even a free-text notes field satisfies this minimally; wiki-style is differentiating |
| Multi-project management | Serious conlangers work on 3-10 languages simultaneously | Low | Project list, open/close, per-project data isolation |
| Persistent local storage | Offline-first is expected; cloud is optional | Low | File-based or database per project; no forced account |

---

## Differentiators

Features that set a product apart. Not universally expected, but create strong loyalty and word-of-mouth among conlangers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Morphology pattern mini-language | Existing tools handle only concatenative morphology (suffixes/prefixes). A pattern language covering Semitic root-and-pattern, vowel mutation, infixation, reduplication, and analytic constructions is unprecedented in free tools. | High | Core architectural investment; must get the DSL right early; powers declension tables, word derivation, and parsing |
| Automatic interlinear glossing | Writing scratchpad that parses input and displays Leipzig-style interlinear gloss (word \| morpheme \| gloss) is rare — no free desktop tool does this end-to-end | High | Depends on morphology engine being able to reverse-analyze tokens; parsing is the hard part |
| AI tutor + co-creator (MCP) | No existing conlang tool has a built-in AI with full project context. The dual role (explain linguistics + actively suggest words/rules) is novel. | High | Requires MCP server exposing project data; network dependency; prompt design is key |
| TTS for conlang speech | Hearing your conlang spoken removes a huge friction point for immersion. No existing free tool synthesizes conlang speech. | High | Requires phoneme-to-audio pipeline; options: rule-based with IPA phoneme inventory, or LLM TTS with phoneme injection |
| Phonotactic violation highlighting | Real-time feedback on whether a word follows defined phonotactics, inline throughout the tool | Med | ConWorkShop has a phonotactics section but does not apply it as a live linter across all input fields |
| Swadesh list + Conlanger's Thesaurus integration | Guided semantic coverage — "what words should I build next?" — is a common conlanger need with no good automated solution | Med | Swadesh list is public domain; Conlanger's Thesaurus (fiatlingua.org) requires PDF parsing or pre-indexed data |
| Anki export from lexicon | Language learners (including the conlanger themselves learning their own language) use Anki; direct export is a high-value workflow shortcut | Low | Well-understood Anki deck format (`.apkg`); low implementation complexity for high user value |
| Phonological rule engine (sound changes) | Diachronic conlangers model sound changes (e.g. a + nasal → ã); this is separate from synchronic allophony and powers historical derivation | Med-High | Ordered rule application; context-sensitive rules; used by Zompist's SCA2 (web-only) but not integrated into a full conlang workbench |
| Etymological tracking + automatic compound detection | Knowing where a word came from (root + derivation chain) is valuable for consistency; automatic detection of compoundable roots is novel | Med | Requires lexicon graph model; etymology chain display is the UX challenge |
| Clickable IPA reference chart with real audio | Real recordings (Wikipedia IPA source) rather than synthesized; conlangers use this constantly when designing phoneme inventories | Med | Audio file bundling or streaming; Wikipedia audio files are freely licensed |
| Linguistic terminology glossary | Built-in searchable glossary removes the constant tab-switching to Wikipedia for terms like "ergative", "antipassive", "applicative" | Low-Med | Can be curated static data; differentiates from tools that assume expert users |
| Language typology choice system | Structured decisions: ergative vs accusative, head-final vs head-initial, fusional vs agglutinative — with implications propagated to grammar templates | Med | Guides novice conlangers; advanced users appreciate systematic consistency checks |
| Culture / world-building wiki | Markdown wiki with internal links connects language to the world it lives in; rare in dedicated conlang tools | Med | PolyGlot has a rudimentary notes section; full wiki with internal linking is differentiating |
| Modality expression strategy selection | Choosing morphological vs analytic (auxiliary/particle) realization per grammatical category is a real typological decision; no tool models this explicitly | Med | Complex UX; must model the "grammar strategy" layer above morpheme patterns |

---

## Anti-Features

Features to deliberately NOT build, at least in v1. These either dilute focus, add disproportionate complexity, or are addressed by the existing ecosystem.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full machine translation (conlang ↔ natural language) | Requires massive training data that doesn't exist for constructed languages; sets false expectations; is a different product category | AI agent can assist with one-off translations as a co-creator task, not a system feature |
| Collaborative / multi-user editing | Conflict resolution, user accounts, sync infrastructure; massive complexity; conlanging is almost always a solo creative activity | Single-user local-first; export/import for sharing snapshots |
| Cloud sync / hosting | Adds auth, backend, ops; out of scope per project constraints; creates privacy questions about creative work | Local SQLite per project; users can use their own cloud storage (Dropbox, iCloud) for the project folder |
| Mobile app | Different interaction model for a data-dense tool; Flutter enables it later but premature now | Desktop-first; defer until core desktop experience is validated |
| Conlang community / social features | Forum, sharing, commenting — a different product (ConWorkShop already does this) | Export for sharing; no in-app social layer |
| Phoneme audio recording (user voice) | Recording user's own voice for phoneme samples; adds microphone permissions, audio storage, playback UI for little gain | Use real IPA recordings from Wikipedia; TTS for synthesis |
| Automatic natural language analysis / NLP | Analyzing English text to extract semantic fields, etc.; complex and not core to conlang creation | AI agent can do this conversationally |
| Version control / branching for language history | Git-like history of language changes; interesting but massively complex; etymology tracking covers the creative need | Etymology chains capture derivation history; simple undo/redo for session-level changes |
| Syntax tree editor / visual phrase structure diagrams | Linguistically interesting but rarely needed in practice by conlangers; complex to implement correctly | Grammar tab documents word order rules textually; AI can explain phrase structure |

---

## Feature Dependencies

```
Phoneme inventory definition
  → IPA keyboard / input (uses defined phonemes for validation)
  → Word generator (phonotactics require phoneme classes)
  → Phonotactic violation highlighting (requires phoneme + phonotactics definition)
  → TTS synthesis (maps defined phonemes to audio primitives)
  → Phonological rule engine (transforms phoneme sequences)

Morphology pattern mini-language
  → Declension / conjugation table generation (patterns define the forms)
  → Interlinear glossing / writing scratchpad parsing (reverse-applies patterns to tokenize)
  → Etymological tracking (derivation is a morphological operation)
  → Automatic compound detection (compound rules are morphological patterns)

Lexicon (root + derived word dictionary)
  → Declension tables (need a word to inflect)
  → Interlinear glossing (parser needs lexicon to look up roots)
  → Anki export (exports from lexicon entries)
  → Swadesh / Thesaurus integration (fills gaps identified against semantic checklists)
  → AI co-creator (AI needs lexicon context to suggest vocabulary)

Grammar tab (POS, word order, typology)
  → Morphology pattern mini-language (patterns are attached to grammar categories)
  → Declension / conjugation tables (table structure defined by grammar categories)
  → Modality expression strategy (grammar-level decision propagates to patterns)

Writing scratchpad
  → Interlinear glossing (core scratchpad output)
  → Phonotactic violation highlighting (applies phonotactics to scratchpad text)
  → Phonetic reading generation (applies phonology rules to scratchpad text)
  → Error highlighting (unknown words, rule violations)
  → AI co-creator (AI can analyze and comment on scratchpad text)

AI agent (MCP)
  → All project data (reads phonology, lexicon, grammar, culture, scratchpad)
  → Linguistic terminology glossary (can answer terminology questions)
```

---

## MVP Recommendation

Prioritize this minimal viable set that proves the core value proposition (morphology engine breadth + integrated workflow):

1. **Phoneme inventory + IPA reference chart with audio** — Entry point for every new language; immediate wow factor from real audio
2. **Lexicon management (root + derived words)** — Core persistent artifact; must exist before anything else is useful
3. **Morphology pattern mini-language** — The centerpiece differentiator; proves the product can handle non-concatenative morphology
4. **Declension / conjugation table generation** — Immediate payoff from the morphology engine; highly visible and shareable
5. **Basic grammar tab (POS definitions, word order)** — Structural scaffold for morphology patterns
6. **Word generator based on phonotactics** — Quick win; fun and immediately useful during early language design
7. **Writing scratchpad with interlinear glossing** — Proves the end-to-end pipeline (write → parse → gloss); second major differentiator
8. **Export: CSV/TSV lexicon, plain text** — Minimum for users to share their work

Defer (post-MVP):
- AI agent: high complexity, network dependency; validate core tool first
- TTS: significant engineering; validate phonology + lexicon UX first
- Phonological sound change engine: useful but not on the critical path for v1
- Culture/wiki tab: low risk to defer; free-text notes in grammar tab can substitute
- Anki export: low complexity but not day-1 need; add after lexicon is stable
- Swadesh / Conlanger's Thesaurus integration: data pipeline work; defer until lexicon UX is settled

---

## Competitor Feature Matrix

Based on training knowledge (MEDIUM confidence — web verification recommended):

| Feature | ConWorkShop | Vulgar | PolyGlot | Lexique Pro | Conlang Workbench (planned) |
|---------|------------|--------|----------|-------------|------------------------------|
| Phoneme inventory | Yes | Yes | Yes | No | Yes |
| IPA input | Partial | Partial | Yes | Yes | Yes (full keyboard + chart) |
| Word generator | No | Yes | No | No | Yes |
| Lexicon management | Yes | Partial | Yes | Yes (primary function) | Yes |
| Morphology (concatenative) | Partial | Partial | Yes | No | Yes |
| Non-concatenative morphology | No | No | No | No | Yes (pattern mini-language) |
| Declension/conjugation tables | No | No | Yes | No | Yes |
| Interlinear glossing | No | No | No | No | Yes |
| Grammar documentation | Partial | No | Partial | No | Yes (structured + wiki) |
| Writing scratchpad | No | No | No | No | Yes |
| Phonotactic violation linting | No | No | No | No | Yes |
| TTS / audio output | No | No | No | No | Yes (planned) |
| AI integration | No | No | No | No | Yes (MCP) |
| Anki export | No | No | No | No | Yes (planned) |
| Web-based | Yes | Yes | No | No | No (desktop) |
| Offline | No | Partial | Yes | Yes | Yes |
| Free | Yes (community) | Freemium | Yes (open source) | Free | Yes (planned) |

**Key gap in the market:** No existing tool combines non-concatenative morphology, integrated writing analysis with interlinear glossing, and an AI co-creator in one offline desktop application.

---

## Sources

**Confidence: MEDIUM** — All findings are from training data (knowledge cutoff August 2025). Web and tool access was unavailable during this research session.

Primary knowledge sources:
- ConWorkShop (conworkshop.com) — community-sourced conlang platform; extensive phonology and lexicon tools
- Vulgar Language Generator (vulgarlang.com) — generates naturalistic conlangs from phoneme input; strong word generator
- PolyGlot (GitHub: DThauvin/PolyGlot) — open-source Java desktop app; strongest declension/conjugation table system among free tools
- Lexique Pro (SIL International) — primarily for minority language documentation; not conlang-focused
- Zompist SCA2 — web-only sound change applier; no lexicon or grammar integration
- Awkwords — web-only word generator; no broader tool integration
- r/conlangs and Linguifex community feature request discussions (training corpus)

**Verification recommended for:**
- Current ConWorkShop morphology capabilities (may have added features post-training-cutoff)
- PolyGlot current version feature set (active development)
- Any new tools that emerged 2025-2026 in the conlang tool space
