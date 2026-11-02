# Conlang Workbench (web)

A TypeScript web version of the Flutter desktop app in this repo, with the same screens and abilities. Everything stays on your computer: there is no server and no account, and the deployed site's security policy blocks network requests to anywhere else.

```bash
cd web
npm install
npm run dev          # http://localhost:5173
npm test             # engine, architecture, file and MCP tests
npm run e2e          # drives the real app in Chrome
npm run build        # production build in dist/, including the MCP server
```

To deploy on Vercel, import the repo and set the project's Root Directory to `web`. `vercel.json` covers the rest.

## Where your data lives

Each language is one readable JSON file, `Name.conlang.json`.

- **Chrome and Edge:** you choose where the file lives, and the app saves to it as you work. A copy is also kept in the browser's local database.
- **Firefox and Safari:** browsers can't keep a live link to a file, so the project lives in the browser's local database. Use File → Download a Copy to back it up. Clearing site data for the app deletes these projects.

**Older projects:** File → Open accepts `.conlang` files from the desktop app and converts them. The original file is not changed. From the command line: `npm run import-legacy -- old.conlang new.conlang.json`.

## How derivation works

`src/core/engine.ts` is the only place that decides what form a word takes. Screens, Anki export and the MCP tools all ask it, and `tests/architecture.test.ts` fails if a screen reads a stored form or runs a rule itself.

A word's stored form is one of three kinds:

| Kind | Stored | Form comes from |
| --- | --- | --- |
| `root` | its phonemes | what you typed |
| `derived` | parent and rule, **no phonemes** | parent's form + rule, recomputed every time |
| `detached` | parent and its own phonemes | a hand edit; no longer follows the rule |

Because a derived word stores no phonemes, there is no stale copy to display. With `v → n (+a)` and `n → adj (+o)`, the root `kal` gives `kala`, then `kalao`. Change the root or a rule and every descendant follows.

Every form has three layers, kept separate:

| Layer | What it is | Used for |
| --- | --- | --- |
| phonemic | the result of the morphology | input to further derivation and inflection |
| phonetic | phonemic after the rewrite rules | `[bracket]` display and phonotactic checks |
| roman | romanization of the **phonemic** form | the main written form |

To get a form for a position, ask the engine:

| Position | Call |
| --- | --- |
| A word itself | `form(id)` |
| What a derivation rule would give | `derivationOptions(id)` |
| A paradigm cell | `paradigm(id)` |
| A token in a phrase | `analyzePhrase(text)` |
| A phrase with its glosses and constructions | `glossPhrase(text)` |

A cell resolves in this order: word override, then rules (most specific first), then an unmarked marker, then uncovered. Rules always start from the word's own form, including when the word is itself derived.

A derivational rule applies in one of two ways:

- **Case by case:** for patterns that only fit some words. A word is stored as `derived` only when you choose it.
- **Automatic:** for productive patterns like make → maker. Every matching word gets the form, generated from the rule and never stored, so changing the rule updates them all. These words appear on each word's page, in search and in phrase analysis, and in the main list only when you turn on "Show automatic words". A meaning or irregular form you add is saved on top: the irregular form as an exception on the rule, the rest in a small `derived` row that holds no phonemes.

**Elongation** is an operation for inflectional and derivational rules. It lengthens a vowel or geminates a consonant, chosen as the first, second or third of that kind of sound, counting from the beginning or the end.

- **Vowels** gain `ː`: `kata` → `kataː`. Add a romanization for the long vowel (`aː` → `ā`) to write it that way.
- **Consonants** double, which is what the gemination constraint checks: `kata` → `katta`. If the language has its own long phoneme such as `rː`, that is used instead.
- **Counting:** a long sound counts once, so the second consonant of `katta` is the `tt`. Elongating a sound that is already long changes nothing.
- **Too few sounds:** a word with no third vowel gets no form, and shows the reason. Use a branch condition to treat those words differently.

Two built-in classes cover long sounds, and appear in every class picker: **`[geminate]`** and **`[long vowel]`**. They hold any consonant or vowel in the language, however its length is written (`tt`, `tː`, or a phoneme such as `rː`), so you don't need to list them. Typical forbidden patterns: `V[long vowel]` and `[long vowel]V` (no vowel touching a long vowel), `[geminate][geminate]` (no two geminates touching), `C[geminate]` and `[geminate]C` (no consonant touching a geminate). A class of your own with the same name replaces the built-in one.

The length mark belongs to the sound before it. `C`, `V` and the built-in classes hold a long sound when they hold its short one, so `V` matches `aː`. A class of your own means exactly what it lists, so `[short]` holding `e` doesn't match `eː`. A doubled consonant is still two consonants to `C`, so `CC` matches `tt`.

When a live derivation can't be computed, the word shows the reason rather than a wrong form. If its parent or rule is deleted, it keeps its current form as a standalone word.

## Particles and constructions

A **particle** is an ordinary word with a gloss tag instead of a meaning, such as `mo` → `NEG`. Choose **Gloss only** on the New Word or edit form; you can flip it later. Particles are listed in the Dictionary with everything else and have a **Particles** filter. One with no part of speech goes in an automatic "Particle" part of speech (`p.`). Ordinary words never hold tags, so `have` means "to have" unless a construction says otherwise.

A **construction** is a sequence of slots:

| Slot | Matches | Options |
| --- | --- | --- |
| Word | one specific word or particle | tag, form |
| Part of Speech | any word of that part of speech | tag, form |
| Phrase / Clause | any run of one or more words | label |

- **Form:** optional, and you pick only the dimensions that matter, so "Past" with person and number left open matches every past form. Matching reads the paradigm, so overrides and irregular forms count. A form whose cell is uncovered has no form to match: to make a bare word count as Present, add an unmarked marker for Present.
- **Word slot required:** a fixed word is what makes a construction recognizable. Without one it shows a warning and never matches.
- **Missing words:** deleting a word used in a slot warns first and lists the constructions using it. The slot stays, marked missing, until you edit it to pick a replacement.

| Construction | Slots |
| --- | --- |
| Past | `have` [`PST`] + Phrase |
| Perfect | `have` [`PERF`] + Verb (Past Participle) |
| Present-only | `have` (Present) [`PERF`] + Phrase |
| Negation | `mo` + Verb |
| Coordination | Phrase + `and` [`CONJ`] + Phrase |
| Subjunctive | `that` [`SBJV`] + Clause |

In the Scratchpad, a Word or Part of Speech slot with a tag glosses as that tag, and everything else glosses as normal: particles show their tag, other words their meaning. The construction's name appears under the words it covers.

- **Phrase slots** take every word up to the next fixed word, or to the end of the phrase. There is no real sentence parsing, and a phrase slot can't contain another construction.
- **Overlaps:** the longest match wins, then the earliest in the construction list. So with both Past and Perfect above, `have eaten apples` reads as Past, because its phrase slot covers all three words.

Project files in the older format are upgraded when opened, and anything that changed is reported: a tag on a word with a meaning moves to the Word slots using it, or is dropped if none do, and a slot whose tag no word has is kept and marked missing.

## AI tools (MCP)

`mcp/server.ts` runs on your computer and works on the project file directly, using the same engine and commands as the app. It re-reads the file on every call, and the app picks up its changes within about two seconds. That's how a hosted page and a local tool share data without anything going online.

```json
{
  "mcpServers": {
    "conlang-workbench": {
      "command": "node",
      "args": ["/path/to/conlang-mcp.mjs", "--project", "/path/to/MyLanguage.conlang.json"]
    }
  }
}
```

`conlang-mcp.mjs` is a single file you can get from View → AI Tools in the deployed app, or from `public/` after a build.

- **Read tools:** project overview, phoneme inventory, phonotactics, lexicon search, word details, paradigm tables, grammar, morphology rules, phrase analysis, word checks, word generation, Swadesh coverage, glossary.
- **Write tools:** add, update and delete words; derive words; add inflectional and derivational rules; add constructions, phonemes and phrases.

The live link needs a browser that can keep a file link (Chrome or Edge).

## Layout

| Path | Contents |
| --- | --- |
| `src/core/` | engine, rules, phonology, commands; no UI code |
| `src/core/legacy/` | desktop-project importer, the only code that reads the old rule text |
| `src/storage/` | app state, local persistence, file sync |
| `src/ui/` | screens |
| `mcp/` | MCP server |
