---
phase: 03-lexicon
plan: "02"
subsystem: lexicon-ui
tags: [flutter, riverpod, dictionary, morphology-engine, ui]
dependency_graph:
  requires: ["03-01"]
  provides: ["dictionary-ui", "word-creation-form", "derivation-tree", "exception-management"]
  affects: ["03-03", "03-04"]
tech_stack:
  added: []
  patterns:
    - "NotifierProvider for mutable state (Riverpod 3.x — StateProvider replacement)"
    - "Provider.family for per-lexeme on-the-fly derivation caching"
    - "MorphologyEngine.applyRule called from Provider for live derivation tree"
    - "Master-detail layout with Row + SizedBox(width:280) + Expanded"
key_files:
  created:
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart
    - lib/features/lexicon/presentation/dictionary/inspiration_panel.dart
  modified:
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/router/app_router.dart
decisions:
  - "Used NotifierProvider instead of deprecated StateProvider for lexemeSearchQueryProvider and lexemePosFilterProvider (Riverpod 3.x compatibility)"
  - "DerivationTreeWidget computes derived forms on-the-fly via computedDerivedFormsProvider (Provider.family over rootIpa), never reads stored derived-form rows — satisfies LEX-02"
  - "InspirationPanel adapts WordGeneratorPanel pattern with onWordSelected callback rather than embedding the existing panel (avoids coupling)"
metrics:
  duration: "~45 minutes"
  completed: "2026-04-09"
  tasks_completed: 2
  files_created: 5
  files_modified: 3
---

# Phase 3 Plan 02: Dictionary UI Summary

Full dictionary UI with master-detail layout, on-the-fly morphology derivation tree via MorphologyEngine, inline word creation/edit, exception management, and GoRouter query-param navigation support.

## What Was Built

### Task 1: DictionaryPage + WordListPanel + Router update

**DictionaryPage** (`dictionary_page.dart`):
- `ConsumerStatefulWidget` with 280px `WordListPanel` on left + Expanded right pane
- Right pane shows `WordDetailPanel`, `WordCreationForm`, or empty state ("No words yet")
- `createWithMeaning` constructor param for D-16 deep-link navigation from Swadesh/Thesaurus
- Query param `?create=true&meaning=X` opens creation form with meaning pre-filled

**WordListPanel** (`word_list_panel.dart`):
- "Add root" `FilledButton.icon` at top
- 40px search `TextField` filtering via `lexemeSearchQueryProvider`
- POS `FilterChip` chips from `posListProvider`, multi-select with "All" clear chip
- List/table view toggle with `tooltip: 'List view'` / `tooltip: 'Table view'` and Semantics labels
- List mode: `ListView.builder` from `filteredLexemeListProvider`, derived-match badges
- Table mode: sortable `DataTable` with IPA, romanization, POS, meaning columns
- Empty state "No words match..." per Copywriting Contract
- `colorScheme.surfaceContainer` background per UI-SPEC

**Router** (`app_router.dart`):
- `/lexicon/dictionary` route updated to pass `createWithMeaning` from `state.uri.queryParameters`

### Task 2: WordDetailPanel, WordCreationForm, DerivationTreeWidget, InspirationPanel + providers

**lexeme_providers.dart** additions:
- `lexemeByIdProvider` — `StreamProvider.family` watching single lexeme by ID
- `exceptionsForLexemeProvider` — `StreamProvider.family` for per-lexeme exceptions
- `computedDerivedFormsProvider` — `Provider.family<List<DerivedFormResult>, String>` applying all active morphological rules via `MorphologyEngine.applyRule()` on-the-fly
- `DerivedFormResult` value class (ruleName, ruleId, derivedIpa, ruleSource)
- `_StringNotifier` / `_StringSetNotifier` — `Notifier`-based replacements for deprecated `StateProvider`

**DerivationTreeWidget** (`derivation_tree_widget.dart`):
- Reads `computedDerivedFormsProvider(rootIpa)` — no stored derived forms ever read (LEX-02)
- Exception overrides shown in `Colors.amber` with "Exception" badge (D-05)
- Root node at level 0, derived forms at level 1 with connector lines
- "N derived form(s)" badge, "No derivations" empty state message

**WordDetailPanel** (`word_detail_panel.dart`):
- View mode: IPA heading (romanization-aware), meaning, POS chip, `DerivationTreeWidget`, exceptions list
- Edit mode: inline form with `IpaTextField`, romanization, meaning, POS dropdown, Save/Cancel
- Exception management: "Add exception" dialog (rule dropdown + `IpaTextField`), delete with confirmation
- Delete word: confirmation dialog with warning about derived forms

**WordCreationForm** (`word_creation_form.dart`):
- Row layout: form (flex 6) + `InspirationPanel` (flex 4)
- `IpaTextField` for IPA, romanization toggle via `romanizationEnabledProvider`
- `prefillMeaning` pre-fills meaning field on first build (D-16)
- `DropdownButtonFormField` for POS selection
- Inserts via `lexemeDaoProvider.insertLexeme()` with `LexemesCompanion`

**InspirationPanel** (`inspiration_panel.dart`):
- Adapts `WordGeneratorPanel` pattern: generates 12 IPA candidates from phonotactic templates
- `onWordSelected` callback fills creation form IPA field
- Syllable range slider (1–5), "Regenerate" button

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed StateProvider deprecated/undefined in Riverpod 3.x**
- **Found during:** Task 2 (flutter analyze revealed pre-existing error from Plan 01)
- **Issue:** `StateProvider<String>` and `StateProvider<Set<String>>` are legacy APIs not exported from `flutter_riverpod` 3.0.3 main export — they require `package:flutter_riverpod/legacy.dart`
- **Fix:** Replaced both with `NotifierProvider`-based providers using hand-written `_StringNotifier` and `_StringSetNotifier` classes. The public API (`.notifier.state = value`) remains identical so all consumers work without changes.
- **Files modified:** `lib/features/lexicon/data/lexeme_providers.dart`
- **Commit:** 05abebb

**2. [Rule 1 - Bug] Fixed `semanticsLabel` parameter on `IconButton`**
- **Found during:** Task 1 (dart analyze — `undefined_named_parameter`)
- **Issue:** `IconButton` has no `semanticsLabel` param; UI-SPEC requires semantics labels for screen readers
- **Fix:** Wrapped each `IconButton` in a `Semantics(label: ...)` widget. Tooltip still provided.
- **Files modified:** `lib/features/lexicon/presentation/dictionary/word_list_panel.dart`
- **Commit:** 30b5e97

## Known Stubs

None — all data paths are wired to live providers. The derivation tree computes on-the-fly from `MorphologyEngine` (no stub data). The inspiration panel generates real words from active phonotactic templates.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced.

All DB writes use Drift parameterized queries via `LexemesCompanion` and `MorphologicalRuleExceptionsCompanion` (T-03-04 mitigated). GoRouter query params are internal navigation only (T-03-14 accepted). `computedDerivedFormsProvider` is cached by Riverpod per rootIpa and recomputed only on rule/inventory change (T-03-05 mitigated).

## Self-Check

All task commits present:
- feat(03-02): Task 1 — commit 30b5e97
- feat(03-02): Task 2 — commit 05abebb

All key files verified:
- `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` — PRESENT
- `lib/features/lexicon/presentation/dictionary/word_list_panel.dart` — PRESENT
- `lib/features/lexicon/presentation/dictionary/word_detail_panel.dart` — PRESENT
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` — PRESENT
- `lib/features/lexicon/presentation/dictionary/derivation_tree_widget.dart` — PRESENT
- `lib/features/lexicon/presentation/dictionary/inspiration_panel.dart` — PRESENT
- `lib/features/lexicon/data/lexeme_providers.dart` — PRESENT (with additions)
- `lib/router/app_router.dart` — PRESENT (route updated)

`dart analyze lib/` — 0 errors, 21 info (all pre-existing or `deprecated_member_use` for `DropdownButtonFormField.value` which is also present in existing codebase files)

## Self-Check: PASSED
