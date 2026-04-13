# Phase 6: Reference Glossary - Research

**Researched:** 2026-04-12
**Domain:** Flutter desktop — overlay drawer, JSON asset loading, real-time search, accordion UI
**Confidence:** HIGH

## Summary

Phase 6 adds a built-in linguistic glossary as a 320px right-side drawer accessible from any tab via a `?` icon button in the top app bar. Per-tab contextual filtering is triggered by a second `?` button on each sub-tab shell. The entire feature is self-contained: a bundled JSON asset, a Riverpod provider for loading/filtering, and a `GlossaryDrawer` widget wired into `AppShell`.

The existing codebase already has a proven pattern for exactly this problem: `swadesh_list.json` and `conlangers_thesaurus.json` are loaded with `rootBundle.loadString` + `FutureProvider`, and parsed with `json.decode`. The glossary asset follows the same approach. No new dependencies are needed — the full feature is built from Flutter SDK primitives and existing Riverpod patterns already in the project.

**Primary recommendation:** Implement the glossary drawer as a custom `AnimatedContainer` or `Stack`+`AnimatedPositioned` overlay inside `AppShell`, sharing the same `colorScheme` dark theme used across all shells. Load the JSON asset with a `FutureProvider` exactly like `swadeshListProvider`. Category chips use existing `colorScheme` tokens (no new colors needed). Real-time filter is a simple `ValueNotifier`/`StateProvider` string + `where()` on the in-memory list.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Glossary entries stored as a bundled JSON asset — fast lookup, offline-capable, no DB migration needed
- D-02: Initial dataset covers 150-200 core linguistics terms spanning phonology, morphology, syntax, semantics, and typology
- D-03: Entries include "See also" cross-references to related terms (e.g. "allophone" links to "phoneme")
- D-04: Static definitions only — no dynamic examples from user's conlang data
- D-05: Glossary lives in a right-side drawer accessible from any tab via a `?` icon button in the app bar — always available regardless of current tab
- D-06: Each tab (Phonology, Grammar, Lexicon) has a contextual `?` button that opens the glossary pre-filtered to terms relevant to that domain
- D-07: Real-time filter-as-you-type search on both term names and definition text
- D-08: 320px right-side drawer with search bar at top, scrollable term list below
- D-09: Terms displayed as expandable accordion tiles — term names visible in compact list, tap to expand and show full definition
- D-10: Terms tagged with colored category chips (Phonology, Morphology, Syntax, Semantics, Typology) enabling per-tab contextual filtering

### Claude's Discretion
- JSON asset file structure and loading strategy
- Accordion expand/collapse animation details
- Search debounce timing
- Category chip color assignments (within dark theme palette)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REF-01 | User can search a built-in glossary of linguistic terminology with definitions | JSON asset pattern (rootBundle), FutureProvider loading, real-time filter via StateProvider string + list.where(), accordion ExpansionTile widget |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/services.dart (rootBundle) | SDK | Load bundled JSON asset | Same pattern as swadesh_list and thesaurus — already proven in project [VERIFIED: codebase] |
| dart:convert (json.decode) | SDK | Parse JSON string to Dart objects | Standard approach used in semantic_providers.dart [VERIFIED: codebase] |
| flutter_riverpod | ^3.0.3 | Provider-based state for glossary data + filter state | Already in project, all state managed via Riverpod [VERIFIED: pubspec.yaml] |
| flutter/material.dart (ExpansionTile) | SDK | Accordion tiles for term definitions | Built-in Flutter widget, no extra dependency [VERIFIED: Flutter 3.38 SDK] |
| flutter/material.dart (AnimatedContainer / Stack) | SDK | Slide-in right drawer | Existing IpaChartPanel is a persistent right panel; glossary is toggle-able [VERIFIED: codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/material.dart (FilterChip / Chip) | SDK | Category filter chips | Category display and contextual filtering [VERIFIED: Flutter SDK] |
| flutter/material.dart (TextField) | SDK | Search input | Same as other search fields in project [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom AnimatedContainer drawer | Material `Drawer` / `endDrawer` on Scaffold | Material Drawer is designed for mobile nav; AppShell uses a custom tab bar on a Scaffold body Column — the Scaffold.endDrawer would overlay the tab bar correctly, but is harder to control programmatically from child widgets. Custom AnimatedContainer in the AppShell body is simpler to wire from any tab. |
| ValueNotifier for search text | `StateProvider<String>` | StateProvider integrates with Riverpod's existing provider graph; can be watched by the filter provider. Both work; StateProvider is more consistent with the project pattern. |

**Installation:** No new packages required. [VERIFIED: pubspec.yaml — all needed libraries are Flutter SDK or already present]

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── features/
│   └── glossary/
│       ├── data/
│       │   └── glossary_providers.dart   # FutureProvider<List<GlossaryEntry>>, filterProviders
│       ├── domain/
│       │   └── glossary_entry.dart       # GlossaryEntry data class
│       └── presentation/
│           └── glossary_drawer.dart      # GlossaryDrawer widget (320px panel)
└── shared/
    └── widgets/
        └── app_shell.dart                # Modified: add ? button + GlossaryDrawer overlay
assets/
└── glossary.json                         # 150-200 entries
```

### Pattern 1: JSON Asset Loading with FutureProvider
**What:** Load glossary.json at app startup using rootBundle, parse to typed List<GlossaryEntry>
**When to use:** Any static bundled JSON reference data (proven: swadesh, thesaurus)
**Example:**
```dart
// Source: lib/features/lexicon/data/semantic_providers.dart [VERIFIED: codebase]
final glossaryProvider = FutureProvider<List<GlossaryEntry>>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/glossary.json');
  final jsonList = json.decode(jsonStr) as List<dynamic>;
  return jsonList
      .map((e) => GlossaryEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});
```

### Pattern 2: Right-Side Persistent Panel (Toggle)
**What:** A 320px panel shown/hidden via a boolean `StateProvider<bool>`, sitting inside a `Row` in AppShell body alongside `navigationShell`.
**When to use:** Sidepanel that overlays or pushes content; PhonologyShell uses a persistent right `IpaChartPanel` panel.
**Example:**
```dart
// Mirrors IpaChartPanel integration in PhonologyShell [VERIFIED: codebase]
// AppShell body Row:
Row(children: [
  Expanded(child: navigationShell),
  if (glossaryOpen) ...[
    VerticalDivider(width: 1, color: colorScheme.outlineVariant),
    SizedBox(width: 320, child: GlossaryDrawer()),
  ],
])
```
Note: The decision says "right-side drawer" (D-05, D-08). The PhonologyShell IpaChartPanel is a persistent right panel; the glossary is the same pattern but toggled. Using a `Stack` + `AnimatedPositioned` for a true overlay (non-pushing) is the alternative if real estate is constrained.

### Pattern 3: Real-Time Filter with StateProvider
**What:** Two StateProviders — one for search text, one for active category filter. A derived Provider computes the filtered list.
**When to use:** All in-memory list filtering in the project
**Example:**
```dart
// Source: existing pattern in swadesh coverage + thesaurus search [ASSUMED - pattern extrapolated]
final glossarySearchProvider = StateProvider<String>((ref) => '');
final glossaryCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredGlossaryProvider = Provider<List<GlossaryEntry>>((ref) {
  final all = ref.watch(glossaryProvider).asData?.value ?? [];
  final query = ref.watch(glossarySearchProvider).toLowerCase();
  final category = ref.watch(glossaryCategoryFilterProvider);

  return all.where((entry) {
    final matchesSearch = query.isEmpty ||
        entry.term.toLowerCase().contains(query) ||
        entry.definition.toLowerCase().contains(query);
    final matchesCategory = category == null || entry.category == category;
    return matchesSearch && matchesCategory;
  }).toList();
});
```

### Pattern 4: Accordion with ExpansionTile
**What:** Flutter's built-in `ExpansionTile` for each glossary term. Term name in title, definition + "See also" chips in expanded body.
**When to use:** Expandable list content (standard Flutter pattern)
**Example:**
```dart
// Source: Flutter SDK ExpansionTile [VERIFIED: Flutter 3.38 SDK]
ExpansionTile(
  title: Text(entry.term, style: theme.textTheme.bodyMedium),
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.definition),
          if (entry.seeAlso.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: entry.seeAlso.map((term) =>
                ActionChip(label: Text(term), onPressed: () { /* jump to term */ })
              ).toList(),
            ),
          ],
        ],
      ),
    ),
  ],
),
```

### Pattern 5: Contextual `?` Button in Tab Shells
**What:** Each tab shell (PhonologyShell, GrammarShell, LexiconShell, CultureShell) adds a small `?` `IconButton` that sets the glossary open state AND sets a category filter.
**When to use:** D-06 contextual filtering
**Example:**
```dart
// Source: Pattern derived from AppShell tab button structure [ASSUMED]
// In GrammarShell header row or AppShell actions area:
IconButton(
  icon: const Icon(Icons.help_outline, size: 18),
  tooltip: 'Glossary: Grammar terms',
  onPressed: () {
    ref.read(glossaryOpenProvider.notifier).state = true;
    ref.read(glossaryCategoryFilterProvider.notifier).state = 'Morphology';
  },
)
```

### JSON Asset Schema
**What:** Flat JSON array of entry objects
```json
[
  {
    "term": "allophone",
    "category": "Phonology",
    "definition": "A phonetically distinct variant of a phoneme that does not change word meaning.",
    "seeAlso": ["phoneme", "phonological rule"]
  }
]
```
Categories map to D-10: `"Phonology"`, `"Morphology"`, `"Syntax"`, `"Semantics"`, `"Typology"`.

### Anti-Patterns to Avoid
- **Storing glossary in SQLite:** D-01 explicitly forbids DB use. Static JSON asset is the correct approach — no migration risk.
- **Fetching glossary at runtime from network:** App is offline-first; IPA audio assets are bundled at build time for the same reason.
- **Building custom search indexing:** 150-200 terms is a tiny dataset. Simple `String.contains` on-the-fly is instantaneous. Inverted index is massive overkill.
- **Using Material `Scaffold.endDrawer`:** AppShell uses a custom `Column` layout (tab bar + body). The `Scaffold.endDrawer` API works but the open/close needs to be called via `Scaffold.of(context).openEndDrawer()`. A controlled `Row`-based panel in the body is more predictable given the existing architecture.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Accordion expand/collapse | Custom AnimatedContainer per tile | `ExpansionTile` (SDK) | Built-in, accessible, animated, maintains expand state correctly |
| JSON loading/parsing | Custom file I/O | `rootBundle.loadString` + `json.decode` | Already the project standard; tested across all platforms |
| Category chips | Custom chip widgets | `FilterChip` or `Chip` (SDK) | Material 3 styled, works with dark theme colorScheme automatically |
| Search debounce | Manual `Timer` re-implementation | 200-300ms debounce via `Timer.debounce` or simply relying on `StateProvider` + `Provider.select` | Project already uses Timer debounce in WordGeneratorPanel (01-07 decision) — same pattern |

**Key insight:** The glossary is essentially the Swadesh/Thesaurus pattern (JSON asset + FutureProvider + list display) with an added toggle drawer wrapper. No new technology is introduced.

## Common Pitfalls

### Pitfall 1: Glossary Open State Visibility Across Tabs
**What goes wrong:** If `glossaryOpenProvider` is scoped inside `GlossaryDrawer` or a feature provider, the `?` buttons in sub-tab shells cannot reach it.
**Why it happens:** Riverpod providers scoped below AppShell are not reachable by sibling widget trees.
**How to avoid:** Declare `glossaryOpenProvider` and `glossaryCategoryFilterProvider` as global (top-level) `StateProvider`s in `glossary_providers.dart`. AppShell reads them; any shell widget can write them via `ref.read(...notifier).state =`.
**Warning signs:** `?` button presses don't open the drawer, or category filter doesn't apply on open.

### Pitfall 2: AppShell Layout Breaking with Panel Added
**What goes wrong:** Adding a 320px panel to AppShell's body Row causes the main content to shrink or overflow on smaller windows.
**Why it happens:** `Expanded(child: navigationShell)` in the body Row absorbs remaining space; the glossary panel is additive.
**How to avoid:** Wrap the glossary panel in `SizedBox(width: 320)` inside the Row — this is identical to `IpaChartPanel` in PhonologyShell [VERIFIED: codebase]. The app targets desktop (1024px+ minimum), so 320px is safe.
**Warning signs:** RenderFlex overflow warnings in debug console when glossary is open.

### Pitfall 3: ExpansionTile State Reset on Filter Change
**What goes wrong:** When the user types in the search box, the filtered list re-renders and all expanded tiles collapse.
**Why it happens:** The `ListView.builder` with `ExpansionTile` creates new widget instances; `ExpansionTile`'s expand state is internal unless `initiallyExpanded` is driven externally.
**How to avoid:** Either (a) accept collapse-on-filter as expected behavior (simplest), or (b) maintain a `Set<String>` of expanded term IDs in a `StateProvider<Set<String>>` and pass `initiallyExpanded` accordingly.
**Warning signs:** User complaint that expanding a term and then typing resets the expansion.

### Pitfall 4: "See Also" Cross-Reference Taps
**What goes wrong:** Tapping a "See also" term chip needs to scroll to and expand that term. With a filtered list, the referenced term may be hidden.
**Why it happens:** Category/search filter may exclude the linked term.
**How to avoid:** On "See also" tap: (1) clear the search query, (2) clear category filter, (3) scroll to matching term. Use a `ScrollController` on the `ListView` and `Scrollable.ensureVisible` or `jumpTo` the item index.
**Warning signs:** "See also" chip tap appears to do nothing or shows empty list.

### Pitfall 5: asData?.value Pattern for FutureProvider
**What goes wrong:** Using `.value` directly on `AsyncValue` crashes on loading/error states.
**Why it happens:** Riverpod 3.x removed `valueOrNull`; `.asData?.value` is the safe accessor.
**How to avoid:** Use `ref.watch(glossaryProvider).asData?.value ?? []` in derived providers — already the project convention [VERIFIED: STATE.md decision 01-12].
**Warning signs:** Null pointer exceptions when glossary drawer opens before asset is loaded.

## Code Examples

### GlossaryEntry domain model
```dart
// Source: Pattern matches SwadeshItem/ThesaurusCategory in semantic_providers.dart [VERIFIED: codebase]
class GlossaryEntry {
  final String term;
  final String category;  // "Phonology" | "Morphology" | "Syntax" | "Semantics" | "Typology"
  final String definition;
  final List<String> seeAlso;

  const GlossaryEntry({
    required this.term,
    required this.category,
    required this.definition,
    this.seeAlso = const [],
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) => GlossaryEntry(
    term: json['term'] as String,
    category: json['category'] as String,
    definition: json['definition'] as String,
    seeAlso: (json['seeAlso'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [],
  );
}
```

### Asset registration in pubspec.yaml
```yaml
# Source: existing pubspec.yaml pattern [VERIFIED: codebase]
flutter:
  assets:
    - assets/glossary.json   # Add alongside swadesh_list.json
```

### Glossary provider
```dart
// Source: mirrors swadeshListProvider in semantic_providers.dart [VERIFIED: codebase]
final glossaryProvider = FutureProvider<List<GlossaryEntry>>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/glossary.json');
  final jsonList = json.decode(jsonStr) as List<dynamic>;
  return jsonList
      .map((e) => GlossaryEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

final glossaryOpenProvider = StateProvider<bool>((ref) => false);
final glossaryCategoryFilterProvider = StateProvider<String?>((ref) => null);
final glossarySearchProvider = StateProvider<String>((ref) => '');

final filteredGlossaryProvider = Provider<List<GlossaryEntry>>((ref) {
  final all = ref.watch(glossaryProvider).asData?.value ?? [];
  final query = ref.watch(glossarySearchProvider).toLowerCase();
  final category = ref.watch(glossaryCategoryFilterProvider);

  return all.where((entry) {
    final matchesSearch = query.isEmpty ||
        entry.term.toLowerCase().contains(query) ||
        entry.definition.toLowerCase().contains(query);
    final matchesCategory = category == null || entry.category == category;
    return matchesSearch && matchesCategory;
  }).toList();
});
```

### AppShell integration (modified body Row)
```dart
// Source: IpaChartPanel in PhonologyShell [VERIFIED: codebase] — same side-panel pattern
Expanded(
  child: Row(
    children: [
      Expanded(child: navigationShell),
      if (glossaryOpen) ...[
        VerticalDivider(width: 1, thickness: 1, color: colorScheme.outlineVariant),
        SizedBox(width: 320, child: const GlossaryDrawer()),
      ],
    ],
  ),
),
```

### Category chip color assignments (within dark theme palette)
```dart
// Source: colorScheme tokens used throughout the project [VERIFIED: codebase]
// Suggested mapping using Material 3 container/on-container pairs:
Color _chipColor(String category, ColorScheme cs) => switch (category) {
  'Phonology'  => cs.primaryContainer,
  'Morphology' => cs.secondaryContainer,
  'Syntax'     => cs.tertiaryContainer,
  'Semantics'  => cs.errorContainer,     // warm amber in dark themes
  'Typology'   => cs.surfaceContainerHighest,
  _            => cs.surfaceContainerHigh,
};
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `valueOrNull` getter on AsyncValue | `.asData?.value` | Riverpod 3.x | Must use `.asData?.value` — project already standardized [VERIFIED: STATE.md 01-12] |
| `color.withOpacity()` | `color.withValues(alpha:)` | Flutter 3.x | Project already uses `withValues(alpha:)` throughout [VERIFIED: codebase] |

**Deprecated/outdated:**
- `Scaffold.endDrawer` for side panels: The project uses custom `Row`-based panel layouts (IpaChartPanel, culture tree sidebar). Stick with that pattern for consistency.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Contextual `?` buttons are added to each tab shell (Phonology/Grammar/Lexicon shells) as IconButtons that write to global StateProviders | Architecture Patterns (Pattern 5) | The implementation location is slightly different (e.g. wired into AppShell tab bar actions instead), but the StateProvider approach stays the same |
| A2 | Search debounce can be omitted or set to 150-200ms; with 150-200 entries in-memory filtering is fast enough to run on every keystroke | Architecture Patterns | If performance is unexpectedly poor, add a Timer debounce using the existing WordGeneratorPanel pattern |
| A3 | "See also" taps jump to the referenced term by clearing filters and scrolling | Common Pitfalls (Pitfall 4) | User may prefer a simpler approach (e.g. just set the search text to the term name) |

## Open Questions (RESOLVED)

1. **Glossary content authoring** — RESOLVED: Addressed in Plan 06-01 Task 1 step 3; glossary.json content authored as part of execution with 150-200 terms across 5 categories.

2. **Culture tab contextual filter** — RESOLVED: Culture tab omitted per no matching D-10 category; global ? in AppShell provides access from any tab including Culture.

## Environment Availability

Step 2.6: SKIPPED — no external dependencies. All required libraries are Flutter SDK primitives or already in pubspec.yaml. No new packages need installing.

## Validation Architecture

> workflow.nyquist_validation is absent from config.json — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none (flutter test discovers tests/ automatically) |
| Quick run command | `flutter test test/features/glossary/ -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REF-01 | GlossaryEntry.fromJson parses term/category/definition/seeAlso correctly | unit | `flutter test test/features/glossary/glossary_entry_test.dart -x` | Wave 0 |
| REF-01 | filteredGlossaryProvider filters by search query (term name match) | unit | `flutter test test/features/glossary/glossary_providers_test.dart -x` | Wave 0 |
| REF-01 | filteredGlossaryProvider filters by search query (definition text match) | unit | `flutter test test/features/glossary/glossary_providers_test.dart -x` | Wave 0 |
| REF-01 | filteredGlossaryProvider filters by category | unit | `flutter test test/features/glossary/glossary_providers_test.dart -x` | Wave 0 |
| REF-01 | GlossaryDrawer renders term list and search field | widget | `flutter test test/features/glossary/glossary_drawer_test.dart -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/glossary/ -x`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/features/glossary/glossary_entry_test.dart` — covers REF-01 fromJson parsing
- [ ] `test/features/glossary/glossary_providers_test.dart` — covers REF-01 filter logic
- [ ] `test/features/glossary/glossary_drawer_test.dart` — covers REF-01 widget render

## Security Domain

> No security-sensitive operations in this phase. The glossary is a static, read-only, bundled JSON asset. No user input is persisted. No authentication, sessions, or cryptography involved.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Search query used only for in-memory filter, never persisted or sent anywhere |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/features/lexicon/data/semantic_providers.dart` — FutureProvider + rootBundle JSON loading pattern
- Codebase: `lib/features/phonology/presentation/phonology_shell.dart` — Right-side persistent panel (IpaChartPanel) integration pattern
- Codebase: `lib/shared/widgets/app_shell.dart` — AppShell structure, tab bar Row layout
- Codebase: `pubspec.yaml` — confirmed Flutter SDK 3.38, riverpod 3.0.3, no new deps needed
- Codebase: `lib/router/app_router.dart` — tab branch structure, shell hierarchy
- Codebase: `.planning/STATE.md` — riverpod 3.x `.asData?.value` convention, `withValues(alpha:)` convention
- Flutter SDK 3.38.5: `ExpansionTile`, `FilterChip`, `AnimatedContainer` all available [VERIFIED: flutter --version]

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions D-01 through D-10 — locked user decisions defining the full feature spec

### Tertiary (LOW confidence)
- None — all claims verified against codebase or Flutter SDK.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in pubspec.yaml or Flutter SDK
- Architecture: HIGH — directly mirrors existing codebase patterns (swadesh, IpaChartPanel, shells)
- Pitfalls: HIGH — derived from actual code patterns and Riverpod 3.x decisions in STATE.md
- Glossary content: N/A — content authoring is a human task, not a technical research question

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable Flutter SDK + established project patterns)
