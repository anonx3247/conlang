# Phase 6: Reference Glossary - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can look up unfamiliar linguistic terminology without leaving the application. The glossary is a built-in reference tool accessible from any tab, with contextual filtering by domain (phonology, morphology, syntax, etc.).

</domain>

<decisions>
## Implementation Decisions

### Glossary Content & Structure
- D-01: Glossary entries stored as a bundled JSON asset — fast lookup, offline-capable, no DB migration needed
- D-02: Initial dataset covers 150-200 core linguistics terms spanning phonology, morphology, syntax, semantics, and typology
- D-03: Entries include "See also" cross-references to related terms (e.g. "allophone" links to "phoneme")
- D-04: Static definitions only — no dynamic examples from user's conlang data

### Access & Navigation
- D-05: Glossary lives in a right-side drawer accessible from any tab via a `?` icon button in the app bar — always available regardless of current tab
- D-06: Each tab (Phonology, Grammar, Lexicon) has a contextual `?` button that opens the glossary pre-filtered to terms relevant to that domain
- D-07: Real-time filter-as-you-type search on both term names and definition text

### Visual Presentation
- D-08: 320px right-side drawer with search bar at top, scrollable term list below
- D-09: Terms displayed as expandable accordion tiles — term names visible in compact list, tap to expand and show full definition
- D-10: Terms tagged with colored category chips (Phonology, Morphology, Syntax, Semantics, Typology) enabling per-tab contextual filtering

### Claude's Discretion
- JSON asset file structure and loading strategy
- Accordion expand/collapse animation details
- Search debounce timing
- Category chip color assignments (within dark theme palette)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- AppShell in `lib/shared/widgets/app_shell.dart` — main scaffold, add ? icon to app bar actions
- Dark theme with Material 3 colorScheme tokens throughout
- Existing drawer/sidebar patterns in culture_shell.dart (240px sidebar)

### Established Patterns
- Riverpod providers for state management
- Feature directories under `lib/features/`
- ConsumerStatefulWidget pattern for stateful UI

### Integration Points
- App bar in AppShell — add glossary ? button
- Per-tab shells (phonology, grammar, lexicon) — add contextual ? buttons
- GoRouter for any navigation needs

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for the glossary implementation.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
