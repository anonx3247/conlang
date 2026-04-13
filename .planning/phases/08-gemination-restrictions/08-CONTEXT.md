# Phase 8: Gemination Restrictions - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can define gemination restrictions as phonotactic constraints. Prevent geminate consonants globally or positionally (coda, onset, word-initial, word-final). Word generator and phonotactic violation highlighting both respect these constraints.

</domain>

<decisions>
## Implementation Decisions

### UI
- D-01: Gemination constraint lives in the phonotactic constraints list (same tab as syllable structure templates)
- D-02: "Add constraint" dropdown includes "No gemination" as a constraint type alongside syllable templates
- D-03: Position picker uses multi-select chips: Everywhere, Coda, Onset, Word-initial, Word-final. "Everywhere" deselects others and vice versa.

### Storage & DSL
- D-04: New `type` column on PhonotacticConstraints table — distinguishes 'template' (existing) from 'gemination' constraints. Schema migration needed.
- D-05: DSL notation: `!GG` (no geminate globally) with optional position suffix: `!GG/coda`, `!GG/onset`, `!GG/initial`, `!GG/final`
- D-06: Gemination detection: two identical adjacent consonant phonemes (comparing IPA symbols)

### Engine & Validation
- D-07: Word generator rejects candidates with geminates in restricted positions
- D-08: Phonotactic violation highlighting flags geminate violations with same red styling — tooltip says "gemination violation ({position})"

### Claude's Discretion
- Schema migration version number
- Exact position detection algorithm (syllable boundary parsing for coda/onset)
- Constraint ordering relative to template constraints

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/phonology/domain/phonotactic_dsl.dart` — existing phonotactic DSL parser
- `lib/features/phonology/domain/word_generator.dart` — word generation with constraint checking
- `lib/shared/widgets/violation_text.dart` — red violation highlighting widget

### Established Patterns
- PhonotacticConstraints table + PhonotacticDao in app_database.dart
- DSL parsing with petitparser
- Violation checking in word_generator.dart

### Integration Points
- Phonotactic constraints page UI (add constraint flow)
- Word generator constraint checking
- Violation text display throughout lexicon

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
