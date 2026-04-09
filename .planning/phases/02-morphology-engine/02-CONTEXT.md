# Phase 2: Morphology Engine - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can express any word transformation rule — concatenative, templatic, ablaut, or suppletive — in a readable pattern mini-language, and the engine applies those rules consistently. Includes the pattern DSL, plugin architecture, rule editor UI, and per-word exception overrides. Lexicon integration (Phase 3) and grammar paradigms (Phase 4) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Pattern mini-language syntax
- **Symbolic operator style** — compact, regex-like expressions (not keyword-based)
- **Numbered consonant slots** for templatic patterns: plain digits represent consonant positions (e.g. `1a23aa` not `C1aC2C3aa`)
- **Vowels are literal** in templates — `a`, `aa` etc. are fixed pattern material, not variable slots; only consonant positions are variable
- **Rules contain multiple Operations** — a Rule is a container; each Operation inside it is one transformation (suffix, ablaut, template, etc.); operations chain together in order
- **Environment-sensitive conditions** — operations support conditional application based on the phonological environment of the word (e.g. "if word ends in -o, replace -o then add -in")
- **Both string and class matching** for conditions — literal string matching (`ends in "o"`) AND natural class matching (`[stop]`, `[nasal]`) using user-defined classes from Phase 1

### Rule editor experience
- **Hybrid authoring** — structured form fields for building operations (dropdown for type, fields for parameters) with the mini-language expression shown live so users learn the syntax
- **Dropdown menu** for selecting operation type (Prefix, Suffix, Infix, Template, Ablaut, Reduplication, Suppletive)
- **Conditions/branching approach** — each operation needs a way to express environment-sensitive behavior (e.g. different suffix behavior for words ending in vowels vs consonants)

### Live preview behavior
- **Auto-generated sample words** from phonotactic rules as preview input — shows the rule applied across varied word shapes
- **Live debounced updates** (~300ms after typing stops) — immediate feedback, consistent with word generator in Phase 1
- **Inline error messages** — when a sample word has no matching branch or the rule is invalid, show the error where the output would be with a hint about what's wrong
- **Real lexicon words when available** — once the lexicon exists (Phase 3+), show actual roots that match; fall back to generated samples if lexicon is empty

### Exception & override handling
- **Exceptions entered from the word** — on a word's detail page, user overrides the output of any specific rule (exceptions live with the word, not the rule)
- **Color differentiation** for irregular forms — overridden derived forms shown in a distinct color (e.g. amber/orange) to distinguish from regular forms
- **Exceptions persist on rule change** — when a rule is modified, existing exceptions are kept but the user gets a warning to review them
- Per-rule vs blanket exemption scope: Claude's discretion

### Claude's Discretion
- Conditions vs branching structure for environment-sensitive operations (lean toward branching for readability)
- Per-rule-only overrides vs per-rule + blanket "fully irregular" exemption
- Exact structured form field layout for each operation type
- Error message wording and formatting
- Mini-language expression display format in the editor

</decisions>

<specifics>
## Specific Ideas

- User's example of environment-sensitive suffix: `-in` suffix where `kam -> kamin` (consonant ending), `kama -> kamain` (keeps -a), but `kamo -> kamin` (-o absorbs into -i). This is the core complexity the condition system must handle.
- Preview should look like a table of sample roots with arrows to derived forms, showing rule application across varied inputs
- The mini-language expression shown alongside the structured form serves as documentation/learning — users see what the DSL looks like without having to write it directly

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-morphology-engine*
*Context gathered: 2026-04-09*
