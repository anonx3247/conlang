# Phase 1: Foundation - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Flutter desktop app shell with project management, phoneme inventory, IPA reference tools, phonotactic rule editor with syllable structures, and a derivation-aware database schema. Sound change rules (assimilation, harmony, etc.) are deferred — not part of this phase.

</domain>

<decisions>
## Implementation Decisions

### App navigation & layout
- Top-level tabs for major sections (Phonology, Lexicon, Grammar, etc.) with a secondary sidebar for sub-navigation within each section
- Phase 1 shows only the Phonology tab; other tabs appear as their phases are completed
- Project management lives in the menu bar (File → New / Open / etc.), not a dedicated launcher screen
- Within Phonology, the sidebar has two items: **Inventory** (phonemes) and **Sound Rules** (phonotactics)
- IPA keyboard is not a sidebar section — it's a popup widget that appears in IPA text-input fields throughout the app
- IPA reference chart is a persistent side panel visible at all times as a reference, not a separate page

### Phonotactic rule notation
- Template notation for syllable structures: `(C)(C)V(C)` with natural-class references like `[stop]`, `[liquid]`, `[nasal]`
- Phonotactic constraint rules use the same notation style: `VN -> nasalised V`
- Text-based DSL, not visual builder — power and flexibility over hand-holding
- **Critical constraint:** The DSL must be flexible enough to handle ALL language types (tonal, click, polysynthetic, agglutinative, etc.), not just Indo-European patterns

### Rule testing & feedback
- Inline preview: as rules are edited, a live panel shows sample generated words updating in real-time
- Word generator is integrated into the rule editing flow, not a separate page

### Violation display
- Red underline + tooltip on words/segments that violate phonotactic constraints (spell-check style)
- Hover reveals which specific rule is violated

### Claude's Discretion
- Desktop window default size and resize behavior
- IPA chart layout specifics (standard IPA grid arrangement)
- IPA keyboard popup trigger and positioning
- Exact phonotactic DSL syntax design (within the flexibility constraint)
- Empty state designs for new projects
- Romanization mapping UI (mentioned in success criteria, not discussed)

</decisions>

<specifics>
## Specific Ideas

- Navigation feels like a professional desktop tool (tabs + sidebar), not a mobile app
- IPA chart as persistent side reference — always accessible without navigating away
- IPA keyboard as contextual popup — appears where you need it, doesn't take permanent screen space
- Phonotactic DSL should feel like writing linguistic notation, not programming

</specifics>

<deferred>
## Deferred Ideas

- Sound change rules (assimilation, vowel harmony, palatalization, etc.) — deferred from Phase 1, consider for Phase 2 or a dedicated phase
- Full phonological rule engine (ordered rule application, feeding/bleeding) — future phase

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-08*
