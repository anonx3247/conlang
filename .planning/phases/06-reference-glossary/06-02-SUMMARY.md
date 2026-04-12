---
phase: 06-reference-glossary
plan: 02
subsystem: glossary-ui
tags: [flutter, ui, riverpod, glossary, drawer]
dependency_graph:
  requires: [06-01]
  provides: [glossary-drawer-widget, appshell-glossary-integration, per-tab-glossary-buttons]
  affects: [app_shell, phonology_shell, grammar_shell, lexicon_shell]
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget for stateful Riverpod consumer
    - ConsumerWidget conversion for existing StatelessWidget shells
    - NotifierProvider public mutator methods (open/close/toggle, set/clear) instead of .state= (Riverpod 3.x protected)
    - ExpansionTile accordion for term definitions
    - Row + optional SizedBox drawer pattern (same as IpaChartPanel)
key_files:
  created:
    - lib/features/glossary/presentation/glossary_drawer.dart
  modified:
    - lib/features/glossary/data/glossary_providers.dart
    - lib/shared/widgets/app_shell.dart
    - lib/features/phonology/presentation/phonology_shell.dart
    - lib/features/grammar/presentation/grammar_shell.dart
    - lib/features/lexicon/presentation/lexicon_shell.dart
decisions:
  - id: D-06-02-01
    summary: "NotifierProvider notifiers need public mutator methods (open/close/set/clear) — .state= is protected in Riverpod 3.x, triggers invalid_use_of_protected_member warnings"
  - id: D-06-02-02
    summary: "GlossaryDrawer is SizedBox(width:320) not a Flutter Drawer widget — sits in a Row alongside content, consistent with IpaChartPanel pattern in PhonologyShell"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-12"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 6
---

# Phase 6 Plan 02: Glossary UI Drawer Summary

**One-liner:** 320px right-side GlossaryDrawer with search, accordion terms, color-coded category chips, and See Also cross-reference navigation, wired into AppShell + 3 tab shells via contextual ? buttons.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | GlossaryDrawer widget | c3d8e65 | glossary_drawer.dart, glossary_providers.dart |
| 2 | Wire into AppShell + contextual ? buttons | f9c5883 | app_shell.dart, phonology_shell.dart, grammar_shell.dart, lexicon_shell.dart |
| 3 | Human verification | — | Checkpoint (pending) |

## What Was Built

### GlossaryDrawer widget (`lib/features/glossary/presentation/glossary_drawer.dart`)

- `GlossaryDrawer` ConsumerStatefulWidget, 320px wide
- Header row: "GLOSSARY" label (caps, 0.5 alpha) + close X button
- Search TextField with search prefix icon, wired to `glossarySearchProvider`
- Active category FilterChip — shows current domain filter with X to clear
- `ListView.builder` over `filteredGlossaryProvider`
- Each entry: `ExpansionTile` with term name + colored `Chip` subtitle per category:
  - Phonology → primaryContainer
  - Morphology → secondaryContainer
  - Syntax → tertiaryContainer
  - Semantics → errorContainer
  - Typology/other → surfaceContainerHighest
- Expanded content: definition text + See Also `ActionChip` row (tapping navigates by setting search)
- Empty state: centered "No matching terms" text

### AppShell modifications (`lib/shared/widgets/app_shell.dart`)

- Imports `glossary_providers.dart` and `glossary_drawer.dart`
- `help_outline` IconButton added to top bar (right of tabs, before project name)
- Toggle behavior: closes if open, clears category filter then opens if closed
- Main `Expanded` body changed from bare `navigationShell` to `Row` with optional `GlossaryDrawer` on right, separated by `VerticalDivider`

### Tab shell contextual ? buttons

| Shell | Category | Tooltip |
|-------|----------|---------|
| PhonologyShell | Phonology | "Glossary: Phonology terms" |
| GrammarShell | Morphology | "Glossary: Grammar terms" |
| LexiconShell | Semantics | "Glossary: Lexicon terms" |

All three shells converted from `StatelessWidget` to `ConsumerWidget`, sidebar header `Padding` → `Row` with label + `Spacer` + `IconButton`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Riverpod 3.x `.state =` setter is protected on NotifierProvider notifiers**
- **Found during:** Task 1 — `flutter analyze` reported `invalid_use_of_protected_member` and `invalid_use_of_visible_for_testing_member` on all `.notifier).state =` assignments
- **Issue:** Plan's interface comment documented `.state =` as the mutation API, but this is only valid inside Notifier subclass methods in Riverpod 3.x
- **Fix:** Added public mutator methods to all 3 notifier classes in `glossary_providers.dart`:
  - `GlossaryOpenNotifier`: `open()`, `close()`, `toggle()`
  - `GlossarySearchNotifier`: `set(String)`, `clear()`
  - `GlossaryCategoryFilterNotifier`: `set(String?)`, `clear()`
- **Files modified:** `lib/features/glossary/data/glossary_providers.dart`
- **Commit:** c3d8e65

## Known Stubs

None — all data is wired from `filteredGlossaryProvider` which reads the bundled `glossary.json` asset loaded in plan 06-01.

## Threat Flags

None — read-only static UI, no new network endpoints or auth paths introduced.

## Self-Check

### Created files exist

- `lib/features/glossary/presentation/glossary_drawer.dart` — FOUND
- `.planning/phases/06-reference-glossary/06-02-SUMMARY.md` — this file

### Commits exist

- c3d8e65 (Task 1: GlossaryDrawer + providers update)
- f9c5883 (Task 2: AppShell + 3 tab shells)

## Self-Check: PASSED
