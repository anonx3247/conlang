# Phase 12: Writing Scratchpad - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

A new top-level "Scratchpad" tab where users compose phrases in their conlang and receive automatic interlinear glossing (Leipzig format), IPA transcription, and error highlighting. Phrases are saved as persistent records with optional free translations. This phase delivers the full writing loop: type → parse → gloss → annotate → save.

</domain>

<decisions>
## Implementation Decisions

### Navigation & Layout
- New top-level "Scratchpad" tab added as the 4th tab after Lexicon — it's a primary writing area with its own complexity and doesn't belong as a sub-tab of Grammar or Lexicon
- Two-panel layout: left sidebar with saved phrase list, right panel with current phrase editor + interlinear display
- "New phrase" button in toolbar; clicking it auto-focuses cursor in the input field
- Free translation is the **third interlinear tier directly in the block**, editable inline — shown as a dim "Add free translation..." prompt when empty

### Tokenization & Parsing
- Input is whitespace-split into word tokens; each token is resolved via a multi-step lookup:
  1. **Exact lexeme match** — check root forms in the lexicon (including closed-class particles from Phase 10 with their gloss tags)
  2. **Inflected form match** — check against known inflected paradigm forms for all lexemes (via the paradigm engine); recognize e.g. "running" as run + PROG
  3. **Derived form match** — check derived forms computed by the morphology engine for derivational chains
  4. **Unknown** — if none of the above match, mark as "?"
- Gloss line for matched words: direct lexeme match → show word's primary gloss; derived/inflected form → show decomposition chain (e.g. "walk.PAST.3SG")
- IPA transcription line is **on-demand via toggle button** — applies phonological rewrite rules to each token's phonemic form (same pipeline as the lexicon's IPA preview)
- Re-parsing happens **live with ~300ms debounce** on each keystroke

### Error Highlighting
- Unknown words: "?" in gloss cell + **amber/yellow highlight** on the word in the original text line
- Phonotactic violations: **red underline** on the offending token in the original line (consistent with phonotactic highlighting throughout the app)
- Scope in Phase 12: **phonotactic violations and unknown words only** — construction-rule validation deferred to later phases
- Error display is **inline only** — color coding on each token, no separate error panel

### Persistence
- **Auto-save with 1-second debounce** — consistent with typology/settings pages (no explicit save button)
- Stored per phrase: original text + free translation + createdAt + updatedAt timestamps — gloss data is always **recomputed live** from current lexicon/grammar state (never cached)
- Phrase list ordered **reverse chronologically** (newest first); no manual reordering in Phase 12
- New **`ScratchpadPhrases`** Drift table in app_database.dart: `id` (autoincrement), `projectId` (FK), `originalText` (text), `freeTranslation` (text, nullable), `createdAt` (datetime), `updatedAt` (datetime)

### Claude's Discretion
- Exact visual styling for the interlinear block (font sizes, tier spacing, token cell borders)
- Icon choice for the Scratchpad tab
- Whether IPA toggle is per-phrase or global (per session)
- Exact sidebar phrase list item layout (preview snippet, timestamp display)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- **AppShell `_tabs` list** (`lib/shared/widgets/app_shell.dart:34`) — extend with 4th `_TabItem(label: 'Scratchpad', ...)` entry
- **GoRouter `StatefulShellRoute.indexedStack`** (`lib/router/app_router.dart:76`) — add 4th branch for the Scratchpad feature; follows same pattern as Phonology/Grammar/Lexicon shells
- **PhonemeDao / phoneme providers** — phonotactic DSL already flags violations; reuse violation checking logic for scratchpad tokens
- **MorphologyEngine** — `lib/features/morphology/domain/morphology_engine.dart` — can apply rules forward/reverse for morpheme decomposition
- **ParadigmEngine** — `lib/features/grammar/domain/paradigm_engine.dart` — computes inflected forms; can be used to pre-index known inflected forms for reverse lookup
- **LexemeDao** (`lib/features/lexicon/data/lexeme_dao.dart`) — existing CRUD; closed-class particles already stored in Lexemes table (Phase 10)
- **Phonological rewrite pipeline** — `lib/features/phonology/presentation/sound_rules/` — IPA generation from phonemic form; same pipeline used in lexicon IPA preview

### Established Patterns
- Feature structure: `data/` + `presentation/` + `domain/` in `lib/features/scratchpad/`
- **Auto-save via debounce**: see typology page (`lib/features/grammar/presentation/typology/typology_page.dart`) — `_debounceTimer` + `writeTypologyKey` pattern
- **Riverpod StreamProvider** for reactive data (all existing DAOs follow this)
- **Drift DAOs**: `@DriftAccessor` annotation, typed tables, watch streams
- **ConsumerWidget** for all display widgets reading providers

### Integration Points
- **AppShell** (`lib/shared/widgets/app_shell.dart`) — add `_TabItem` for Scratchpad (4th position)
- **GoRouter** (`lib/router/app_router.dart`) — add new `StatefulShellBranch` for `/scratchpad` route
- **app_database.dart** — add `ScratchpadPhrases` table + migration
- **LexemesTable** — already stores open-class and closed-class words; scratchpad lookup reads from here
- **ParadigmEngine** — used to enumerate inflected forms for all lexemes (for reverse lookup index)

</code_context>

<specifics>
## Specific Ideas

- Inflected form recognition is important: if a user types an inflected form (e.g. a word with a past-tense suffix), the gloss engine should recognize it as base + FEAT tags, not just mark it as unknown
- The lookup pipeline should be multi-pass: exact match → inflected form → derived form → unknown
- IPA toggle button placement: per-phrase button in the interlinear block header (not a global app setting)

</specifics>

<deferred>
## Deferred Ideas

- Construction-rule validation (word order checking) — Phase 12 scope is phonotactic + unknown-word errors only
- Drag-to-reorder phrase list — deferred to later phase
- Manual "Parse" button (always live re-parsing in Phase 12)

</deferred>

---

*Phase: 12-writing-scratchpad*
*Context gathered: 2026-04-15*
