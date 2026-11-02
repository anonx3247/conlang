# Handoff: particles and constructions rework

You're continuing the TypeScript web clone of Conlang Workbench in `web/`. The Flutter app in `lib/` is the original and is not being changed. Read `web/README.md` first, especially "How derivation works".

The design below is agreed with the user. Build it; don't reopen it unless you hit a real contradiction.

## Current state

- All of `web/` is uncommitted, plus a small change to the root `README.md`. Commit only if the user asks. Nothing is deployed.
- A dev server may still be running on port 5173. Start one with `cd web && npm run dev` if not.
- At handoff, all 76 unit tests and all 16 browser tests pass (Chrome, Firefox, WebKit).
- None of the work below has been started.

```bash
cd web
npx tsc --noEmit
npx vitest run
npm run build
E2E_PREVIEW=1 LEGACY_FILE=/path/to/copy.conlang npx playwright test
```

`LEGACY_FILE` enables the import test. Use a **copy** of a project from `~/Documents`, such as `Ashakin.conlang`, and never write to the originals. That test expects the `dairenor` word in Ashakin.

## Standing rules from the user

- **No DSL.** Everything is built with structured controls. Old rule text is read only by `src/core/legacy/`.
- **All data stays local.** One JSON file per language; nothing goes online.
- **One engine.** `src/core/engine.ts` decides every form. The UI and MCP tools ask it. `tests/architecture.test.ts` fails if a screen reads stored forms or runs rules itself.
- **Shared commands.** All changes go through `src/core/commands.ts`, used by both the UI and the MCP server.
- **Automatic derivations are generated, not stored.** They have negative session-only ids (`dynamicIdFor`). Anything that persists a reference to a word must first call `ensureWordRow`.

## Decisions

### Words and particles

- A particle is an ordinary lexicon word that has a gloss tag instead of a meaning. It always glosses as its tag, such as `mo` → `NEG`.
- Ordinary words never hold gloss tags. `have` means "to have" unless a construction says otherwise.
- There is no closed/open setting on parts of speech or words. The user rejected it because prepositions are closed but still gloss by meaning.
- Every word can have a part of speech, as today. A particle goes in whichever one fits, such as Article or Case Marker.

### UI

- **Remove the Particles tab.** The Grammar sidebar becomes: Parts of Speech, Inflections, Constructions, Typology.
- **Rename "POS & Dimensions" to "Parts of Speech".** The user's reasoning: dimensions are how it's done and don't belong in the title.
- **New Word and edit forms** get one switch:
  - **Meaning:** an ordinary word, as today.
  - **Gloss only:** a particle. The meaning field becomes a gloss tag field with Leipzig suggestions (`src/data/leipzig.json`; `GlossTagInput` in `src/ui/grammar/particles.tsx` can be moved).
  - It can be flipped later.
- **Dictionary:** particles are listed with everything else, showing their tag where the meaning goes, such as `mo (p.)  NEG`. Add a **Particles** chip beside the part-of-speech filters. Their word pages otherwise work like any word's.
- **The abbreviation is `p.`, not `part.`.** The auto-created "Particle" part of speech uses abbreviation `p`, which displays as `p.`.

### Construction slots

```ts
type ConstructionSlot =
  | { id: Id; type: 'word'; lexemeId: Id; glossTag?: string | null; features?: Record<string, Id> }
  | { id: Id; type: 'pos'; posId: Id; glossTag?: string | null; features?: Record<string, Id> }
  | { id: Id; type: 'phrase'; kind: 'phrase' | 'clause'; label?: string | null };
```

- **Word:** one specific word or particle, with an optional tag and form.
- **Part of speech:** any word of that part of speech, with an optional tag and form.
- **Phrase / Clause:** any run of words, with an optional label such as "subjunctive clause". The two match the same way; the difference is documentation and display.
- **Form picker:** optional. You pick only the dimensions that matter, so "Past" with person and number left open matches every past form. No selection means any form. Hide the picker when the word or part of speech has no dimensions.
- The same word can appear in separate constructions by form, each with its own tag.

Examples the user wants to work:

| Construction | Slots |
| --- | --- |
| Past | `have` [`PST`] + Phrase |
| Perfect | `have` [`PERF`] + Verb (Past Participle) |
| Present-only | `have` (Present) [`PERF`] + Phrase |
| Negation | `mo` + Verb |
| Coordination | Phrase + `and` [`CONJ`] + Phrase |
| Subjunctive | `that` [`SBJV`] + Clause |

### Validation

- Every construction needs at least one Word slot, because a fixed word is what makes it recognizable. Show a warning; a construction without one simply never matches.
- Warn if two particles share a tag. Warn only; don't block.
- Deleting a word used in a slot warns first and lists the constructions using it. If the user goes ahead, the slot is marked missing.

### Scratchpad

- Look for constructions in the typed phrase with a new engine method. Don't put this logic in the UI.
- **Inside a match:** a Word or Part of speech slot with a tag glosses as that tag. A slot with no tag glosses as normal.
- **Outside a match:** particles show their tag; everything else shows its meaning.
- Show the construction's name under the words it covers.
- **Overlaps:** longest match wins, then earliest in the construction list.
- A Phrase or Clause slot takes every word up to the next fixed word or the end of the phrase. Don't attempt real sentence parsing.
- **Form matching uses `engine.paradigm()`,** so overrides and irregular forms count. Consider reusing `surfaceIndex()`, whose `inflected` matches already carry `features`. A feature constraint matches when all its entries appear in the cell's features.

### Migration

Bump `FORMAT_VERSION` to 2. Migrate in `parseProject` (`src/core/types.ts`) because the user may already have version 1 files, and in the SQLite importer.

- Word with a tag and no meaning → particle.
- Word with a tag and a meaning → ordinary word; the tag moves to the Word slots of constructions using it.
- Tag on a meaning word that no construction uses → dropped, and **reported to the user**. `parseProject` currently returns only a document, so it needs a way to return warnings.
- Particle with no part of speech → moved to an auto-created "Particle" part of speech, abbreviation `p`.
- Old `gloss_tag` slot → Word slot pointing at the word with that tag. If none exists, keep it visibly flagged as missing.
- Old `pos` slot (`value` is the POS id as a string) → `{ type: 'pos', posId }`.

## Left for later

- A slot containing another construction, such as a reusable noun phrase.

## Where to change things

| File | Change |
| --- | --- |
| `src/core/types.ts` | `Lexeme.isClosedClass` and `glossTag` become one way to mark a particle; new slot type; format version and migration |
| `src/core/engine.ts` | `form`-independent gloss logic; replace `closedClassWords`; update `fillConstruction`, `constructionsForWord`, `surfaceIndex`, `analyzePhrase`; add construction matching |
| `src/core/commands.ts` | `addWord`/`updateWord` particle handling; slot commands; deletion warning data |
| `src/core/legacy/importSqlite.ts` | apply the migration to imported projects |
| `src/ui/lexicon/dictionary.tsx`, `wordDetail.tsx` | switch, tag display, Particles chip; construction list on word pages |
| `src/ui/grammar/particles.tsx` | delete; move `GlossTagInput` |
| `src/ui/grammar/constructions.tsx` | new slot editor with word search, form picker, tag, phrase and clause types |
| `src/ui/App.tsx` | remove the Particles route and link; rename the sidebar item |
| `src/ui/scratchpad.tsx` | show construction names and construction glosses |
| `mcp/server.ts` | `describeWord`, `get_grammar` and `add_word` use the new model; add a way to create constructions if simple |
| `README.md` | document particles and construction slots |

## Tests to update and add

- `tests/core.test.ts`: the "fills constructions" test and the legacy tests.
- `tests/mcp.test.ts`: anything using particles.
- `e2e/workbench.spec.ts`: the full workflow test creates a particle in the Particles tab, then expects the construction preview `mo kal` and the gloss `NEG`.
- New tests:
  - each example in the table above
  - `have` glossing as a tag only inside a match
  - form-restricted slots, including overrides
  - overlap resolution
  - both migration paths, including the dropped-tag report
  - a slot pointing at an automatic word

## How to report back

The user tests in the running app and cares about accuracy. Say plainly what wasn't verified. Two items were already open before this work:

- Side-by-side comparison with the Flutter app: the agent's session couldn't capture the screen.
- MCP sync through Chrome's real file picker, which can't be automated; a browser-managed file was used instead.
