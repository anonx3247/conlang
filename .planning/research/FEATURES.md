# Feature Research

**Domain:** Conlang construction desktop software — v2.0 new features
**Researched:** 2026-04-13
**Confidence:** MEDIUM-HIGH — web-verified against current tool feature pages (PolyGlot docs, FrathWiki, Leipzig Glossing Rules, Zompist SCA2, MCP spec). Training data cross-checked.

---

## Scope Note

v1.0 shipped with phonology, morphology, lexicon, grammar, reference, and platform features. This research covers only the NEW v2.0 feature domains:

1. Analytic grammar system (closed-class words, word order rules, phrase constructions)
2. Writing scratchpad (tokenization, interlinear glossing, error highlighting, IPA transcription)
3. AI integration (MCP-powered tutor + co-creator)
4. Language evolution (sound change modeling, allophone promotion)
5. Writing system tab (custom script/orthography)
6. Lexicon extras (automatic etymology suggestions)

Existing features are assumed built and working unless noted as a dependency.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in this problem domain. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Interlinear gloss output in Leipzig format | The standard output format for ALL linguistics text analysis. Every linguistics paper, every conlang showcase uses this. Users who know any linguistics will expect it immediately. | HIGH | Three-line format: original / morpheme gloss / free translation. Alignment must be pixel-perfect per Leipzig Glossing Rules (MPI Eva). Abbreviations must follow standard: 3SG, ACC, PST, PL, etc. |
| Tokenization by whitespace + morpheme boundaries | Prerequisite for any text analysis. Users expect the scratchpad to "understand" word boundaries at minimum. | MEDIUM | Space-delimited for analytic languages is straightforward. Morpheme-boundary detection (hyphen / affix splitting) requires morphology engine integration. |
| Unknown word flagging | Users expect gaps to be visible — a "?" or red highlight on unrecognized tokens means the parser is honest about what it doesn't know. | LOW | Already partially scoped; complement to phonotactic highlighting already built. |
| Free translation line | Every interlinear gloss has a third line: the free translation into the metalanguage (English). Users must be able to enter this manually. | LOW | Simple text input beneath the gloss. No automatic translation. |
| Orthography → IPA transcription | Given the phonology rules already defined, applying them to scratchpad text to produce a phonetic reading is an expected output. Users who designed sound rules expect to hear/see what text "sounds like." | MEDIUM | Builds directly on existing phonological rule engine. |
| Closed-class word inventory | Analytic grammar requires a dedicated place to store function words: articles, particles, prepositions, conjunctions, auxiliaries. Users expect these to be separate from the root/derivation lexicon. | MEDIUM | Different lifecycle from content words — these don't inflect, they're grammatical primitives. Needs its own list UI with gloss tags (DEF, NEG, PROG, etc.) |
| Word order rule documentation | Users expect a structured place to record SOV/SVO/VSO and phrase-level ordering (NP, VP, PP). At minimum, a structured form beats a free-text field because it enables downstream validation. | LOW-MEDIUM | PolyGlot only has free-text grammar guide. Structured word order (with head-final/head-initial toggle) is already differentiating in this market. |
| Orthography-to-pronunciation mapping | A writing system tab that maps graphemes → phoneme sequences is expected by anyone defining a custom script. PolyGlot has this; users who are aware of PolyGlot will expect parity. | MEDIUM | Needs regex-compatible rules for deep orthographies (e.g., "ch" → /tʃ/). Priority ordering matters for ambiguous rules. |
| Sound change rule application to lexicon | The ability to run a set of ordered sound changes over the full lexicon (producing a daughter language or diachronic variant) is the single most-requested "evolution" feature in conlang communities. Zompist's SCA2 is the de facto standard web tool for this. | HIGH | Ordered, context-sensitive rules. Must handle environments (#, V, C, user classes). Preview before bulk application. Irreversible bulk apply needs explicit confirmation. |
| Etymology chain display | Users who track word derivations (root → derived → compound) expect to see that lineage displayed somewhere. This is implicit in the existing lexicon structure but needs a visible UI. | LOW-MEDIUM | The derivation data likely already exists in SQLite; this is primarily a display/navigation feature. |

### Differentiators (Competitive Advantage)

Features that set this product apart from ConWorkShop, PolyGlot, Vulgar, and every other conlang tool.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Automatic interlinear glossing (parse-driven) | No existing free conlang tool does end-to-end parse → gloss. PolyGlot confirmed absent. ConWorkShop confirmed absent. This is the headline v2.0 feature. | HIGH | Requires reverse-application of morphology engine: given a surface form, identify root + affixes + grammatical values. Works well for agglutinative; harder for fusional. Fail gracefully with "?" for unknown morphemes. |
| MCP-powered AI with full project context | No conlang tool has built-in AI. The architecture (MCP exposing SQLite data as tools) means the AI can answer "what words have the -ara suffix?" or "suggest a word for 'grief' consistent with my phonology" — impossible without project context. | HIGH | MCP server runs locally alongside the app. Must expose: phoneme inventory, lexicon (roots + derivations), grammar rules, morphology patterns, culture wiki. AI acts in two modes: tutor (explain concepts) and co-creator (suggest, generate, check consistency). |
| Analytic grammar strategy layer | Existing v1.0 grammar tab handles inflectional morphology. The analytic layer adds: auxiliary selection rules, particle placement, construction rules (e.g. "negation = NEG particle + V"). No competitor models this as a structured system — everyone uses free-text grammar notes. | HIGH | Must integrate with morphology engine strategy flags already built (analytic vs morphological per category). The "construction" data model is novel: a named construction with slot sequence (e.g. [SUBJ] [AUX:PROG] [V] [OBJ]). |
| Sound change preview with per-word diff | SCA2 applies changes to a lexicon but shows only results, not a before/after diff. Showing which rule caused each change, with a toggle to accept/reject per word, is a significant UX improvement for diachronic conlanging. | HIGH | Most complex evolution feature. Rule-by-rule trace output is the key differentiator over SCA2. |
| Automatic compound word detection in etymology | When a new lexicon entry's form matches a known root1 + root2 concatenation (or a morphological compound template), surface it as a suggested etymology. No tool does this automatically. | MEDIUM | Heuristic pattern matching over the lexicon graph. False positives are acceptable if flagged as "suggestions." Useful for large lexicons (500+ words) where accidental homophony with compounds occurs. |
| Writing system preview rendering | Given a grapheme-phoneme mapping and a custom font loaded by the user, render any scratchpad text in the custom script in real time. PolyGlot supports custom fonts but not real-time preview tied to the scratchpad. | MEDIUM | Requires font embedding (already a Flutter capability) + orthography rule engine to map romanization → script characters. |
| Allophone-to-phoneme promotion | When a conlanger has defined an allophone via a rewrite rule and decides it should become a full phoneme (split), the tool should offer to promote it: add it to the inventory, update the rule, flag affected lexicon entries. No tool automates this workflow. | MEDIUM-HIGH | Touches phoneme inventory + sound rules + lexicon. Must be a guided wizard (preview changes before committing). This is the "language evolution" micro-feature most likely to be used by intermediate conlangers. |
| Interlinear gloss export (LaTeX / HTML) | Linguists expect to be able to paste their glossed examples into LaTeX (gb4e, expex packages) or embed them in web pages. PolyGlot exports to PDF but not structured gloss formats. | LOW-MEDIUM | LaTeX export: wrap in \gll / \trans macros. HTML export: use Leipzig.js-compatible data attributes. Low effort, high credibility signal. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic free translation (conlang → English) | "Translate this sentence for me" | Requires training data that doesn't exist for constructed languages; would require sending all project data to an external LLM with no reliability guarantees; sets false expectations | AI co-creator can assist with one-off translations conversationally; user enters free translation manually |
| Full NLP pipeline (dependency parsing, constituency trees) | Linguistically rigorous analysis | Complexity is enormous; conlangers need glossing, not full parse trees; syntax tree editor is a different product (RSyntaxTree exists for this) | Interlinear gloss covers 90% of use cases; AI can explain phrase structure in chat |
| Version control / branching for language evolution | "Show me the language at year 500 vs year 1000" | Git-like history is massively complex; SQLite transactions don't support arbitrary branching; most conlangers work on one variant at a time | Sound change "sessions" with named snapshots + before/after lexicon diff covers the practical need |
| Real-time collaborative editing | "Work on my conlang with my co-creator" | Conflict resolution, CRDTs, networking — transforms a desktop app into a distributed system; conlanging collaboration is rare and async | Export/import of project file; share the .conlang file directly |
| Generative AI lexicon creation (bulk) | "Generate 500 words for me" | Bypasses the creative act; produces words inconsistent with phonotactics unless carefully constrained; trains users to be passive | AI co-creator can suggest individual words with context; word generator (already built) handles bulk phonotactic-valid forms |
| Font / glyph editor inside the app | "Design my script glyphs here" | FontForge/Glyphr Studio are mature dedicated tools; building a glyph editor would be a 6-month project for marginal gain | Load custom font files (.ttf/.otf) created in dedicated tools; map them via the orthography rules |
| Full machine translation model training | "Train a model on my conlang" | Requires hundreds of thousands of parallel sentences; impossible at conlang lexicon scales | AI agent can do rule-based pattern translation for demonstration purposes |
| Morphological analyzer export (LEXC/XFST) | "Export my grammar as a finite-state transducer" | Niche professional need; complex mapping from the pattern DSL to FST formalism; used by computational linguists, not conlangers | Plain export (JSON, CSV) covers the practical sharing need; the pattern DSL is already a readable formalism |

---

## Feature Dependencies

```
[Writing Scratchpad]
    └──requires──> [Lexicon (root + derivations)] — lookup during tokenization
    └──requires──> [Morphology pattern engine] — morpheme boundary detection
    └──requires──> [Phonological rule engine] — IPA transcription line
    └──produces──> [Interlinear gloss output]
                       └──enhances──> [Interlinear gloss export (LaTeX/HTML)]

[Analytic grammar system]
    └──requires──> [Grammar tab POS definitions] — function word POS tags
    └──requires──> [Morphology strategy flags] — analytic vs morphological per category (already built v1)
    └──produces──> [Closed-class word inventory]
                       └──requires──> [Writing scratchpad] — particles/aux validated during gloss

[AI Integration (MCP)]
    └──requires──> [MCP server exposing project data]
                       └──requires──> [Phoneme inventory API]
                       └──requires──> [Lexicon API]
                       └──requires──> [Grammar rules API]
                       └──requires──> [Morphology patterns API]
    └──enhances──> [Writing scratchpad] — AI can analyze and comment
    └──enhances──> [Lexicon] — AI can suggest new words
    └──enhances──> [Analytic grammar] — AI can explain construction rules

[Language evolution: sound change]
    └──requires──> [Phoneme inventory] — defines the phoneme set being changed (built v1)
    └──requires──> [Lexicon] — applies changes to existing word forms (built v1)
    └──requires──> [Phonological rule engine] — reuses rule syntax (built v1)
    └──produces──> [Daughter language lexicon diff]

[Language evolution: allophone promotion]
    └──requires──> [Phoneme inventory] (built v1)
    └──requires──> [Sound rules / allophony] (built v1)
    └──requires──> [Lexicon] (built v1)
    └──conflicts──> [Sound change bulk apply] — should not run simultaneously; one at a time

[Writing system tab]
    └──requires──> [Phoneme inventory] — maps graphemes to defined phonemes (built v1)
    └──enhances──> [Writing scratchpad] — renders text in custom script
    └──enhances──> [Lexicon] — displays words in custom script

[Automatic etymology]
    └──requires──> [Lexicon with derivation chains] (built v1)
    └──enhances──> [Morphology pattern engine] — compound pattern matching
    └──independent of——> [Writing scratchpad] — purely a lexicon-layer feature
```

### Dependency Notes

- **Interlinear glossing requires morphology engine reverse-analysis:** The morphology pattern engine was designed forward (root + pattern → surface form). Reverse analysis (surface form → root + morphemes) is a new capability. For agglutinative patterns this is straightforward (strip known affixes). For Semitic patterns it requires template matching. For fusional, it may require lookup tables. This is the single highest-risk technical dependency in v2.0.
- **AI integration requires MCP server:** The MCP server is a separate process exposing the SQLite data via tool endpoints. It must be implemented before the AI chat panel has any project-aware capabilities. The MCP server can be developed independently of the UI.
- **Writing system tab enhances but does not block scratchpad:** Custom script rendering in the scratchpad is a polish feature. The scratchpad works with romanization alone. Build scratchpad first, add script rendering as an enhancement pass.
- **Sound change conflicts with allophone promotion:** Both modify phoneme inventory and word forms. Never offer both operations simultaneously in the same session. Build as separate entry points with clear "you are changing the language's history" framing.

---

## MVP Definition

This is a subsequent milestone (v2.0), not a greenfield MVP. "MVP" here means: minimum viable version of each new feature domain to deliver user value.

### Launch With (v2.0 core)

- [x] **Writing scratchpad with interlinear glossing** — The headline feature. Tokenize → morpheme split → Leipzig gloss → free translation. Unknown tokens shown as "?". This is the primary differentiator of v2.0.
- [x] **Closed-class word inventory** — Article/particle/auxiliary list with gloss tags. Prerequisite for analytic grammar parsing in the scratchpad.
- [x] **Orthography-to-phoneme mapping (writing system tab)** — Grapheme → phoneme rules with priority ordering and regex support. Enables custom script preview.
- [x] **Sound change applier** — Apply ordered, context-sensitive rules to the full lexicon. Preview diff before committing. This is the core of "language evolution."
- [x] **MCP server (project data exposure)** — Expose phoneme inventory, lexicon, grammar, morphology as MCP tools. Prerequisite for all AI features. Minimal AI chat panel attached.
- [x] **Automatic etymology suggestions** — Surface candidate compound etymologies when a form matches known roots. Displayed as suggestions in the lexicon entry editor.

### Add After Validation (v2.x)

- [ ] **Interlinear gloss export (LaTeX / HTML)** — Add after scratchpad is stable and users are actually producing glosses they want to share.
- [ ] **Sound change per-word diff with rule trace** — The basic applier ships first; rule tracing is the enhancement that makes it differentiating vs SCA2.
- [ ] **Custom script rendering in scratchpad** — Add after writing system tab is stable and has a loaded font.
- [ ] **Allophone-to-phoneme promotion wizard** — Add after sound change applier is stable; this is the more surgical evolution tool.
- [ ] **Analytic construction rules (phrase templates)** — Named constructions with slot sequences. Builds on closed-class inventory. Add when users are actively composing analytic-language sentences in the scratchpad.

### Future Consideration (v3+)

- [ ] **TTS synthesis** — Phoneme-to-audio pipeline for speaking conlang text. Already deferred from v1.0; remains high complexity.
- [ ] **AI-generated word suggestions with phonotactic filtering** — AI proposes candidate words; phonotactics engine validates. Requires stable AI integration first.
- [ ] **Culture wiki (relaunched)** — Was retired to branch; needs rework before re-introduction.
- [ ] **Multi-script preview** — Running text rendered simultaneously in romanization + custom script side-by-side.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Writing scratchpad + interlinear gloss | HIGH | HIGH | P1 |
| Closed-class word inventory | HIGH | MEDIUM | P1 |
| Writing system / orthography tab | HIGH | MEDIUM | P1 |
| Sound change applier | HIGH | HIGH | P1 |
| MCP server (data exposure) | HIGH | HIGH | P1 |
| Automatic etymology suggestions | MEDIUM | MEDIUM | P1 |
| AI chat panel (tutor + co-creator) | HIGH | MEDIUM (given MCP server) | P1 |
| Interlinear gloss export LaTeX/HTML | MEDIUM | LOW | P2 |
| Sound change rule trace / diff | HIGH | MEDIUM | P2 |
| Custom script rendering in scratchpad | MEDIUM | MEDIUM | P2 |
| Allophone promotion wizard | MEDIUM | HIGH | P2 |
| Analytic construction rules | MEDIUM | HIGH | P2 |
| TTS synthesis | HIGH | VERY HIGH | P3 |

**Priority key:**
- P1: Must have for v2.0 launch
- P2: Ship in v2.x iterations after core validated
- P3: Future milestone

---

## Competitor Feature Analysis

Verified against current docs (April 2026):

| Feature | PolyGlot (verified) | ConWorkShop (partial) | SCA2/Zompist | Conlang Workbench v2.0 |
|---------|--------------------|-----------------------|--------------|------------------------|
| Interlinear glossing | ABSENT | Unknown | ABSENT | Yes (parse-driven) |
| Writing scratchpad | ABSENT | Unknown | ABSENT | Yes |
| Sound change applier | ABSENT | Unknown | Yes (web-only, no diff) | Yes (with diff + trace) |
| Orthography mapping | Yes (regex) | Partial | No | Yes |
| Custom font support | Yes | No | No | Yes |
| Closed-class word inventory | Partial (in lexicon) | Yes | No | Yes (dedicated) |
| AI integration | ABSENT | ABSENT | ABSENT | Yes (MCP) |
| Automatic etymology | ABSENT | Unknown | ABSENT | Yes (compound detection) |
| Allophone promotion | ABSENT | ABSENT | ABSENT | Yes (wizard) |
| Export LaTeX gloss | ABSENT | ABSENT | ABSENT | Yes (v2.x) |

**Conclusion:** The combination of parse-driven interlinear glossing + MCP AI + sound change applier with diff in one offline desktop app has no competitor in 2026. PolyGlot is the closest general-purpose tool but is missing every v2.0 differentiator. SCA2 covers sound change but is web-only and standalone.

---

## Sources

- [PolyGlot documentation](https://draquet.github.io/PolyGlot/readme.html) — verified April 2026; confirmed absent: interlinear glossing, AI, writing scratchpad, sound change applier
- [Leipzig Glossing Rules (MPI Eva)](https://www.eva.mpg.de/lingua/resources/glossing-rules.php) — authoritative standard for interlinear gloss format; HIGH confidence
- [Interlinear gloss - Wikipedia](https://en.wikipedia.org/wiki/Interlinear_gloss) — three-line format, standard abbreviations
- [Zompist Sound Change Applier (SCA2)](https://www.zompist.com/sounds.htm) — de facto standard for sound change in conlang community; web-only, no lexicon diff
- [FrathWiki software tools list](https://www.frathwiki.com/Software_tools_for_conlanging) — ecosystem overview; confirmed no tool has AI or parse-driven glossing
- [Model Context Protocol spec](https://modelcontextprotocol.io/specification/2025-11-25) — authoritative MCP standard; HIGH confidence
- [ConWorkShop](https://conworkshop.com/) — web-based community platform; glossing capabilities unconfirmed from search
- [PolyGlot GitHub releases](https://github.com/DraqueT/PolyGlot/releases) — version 3.3 current as of research date

---

*Feature research for: Conlang Workbench v2.0*
*Researched: 2026-04-13*
