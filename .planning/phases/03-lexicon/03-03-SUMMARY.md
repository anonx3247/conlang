---
phase: 03-lexicon
plan: "03"
subsystem: lexicon
tags: [swadesh, thesaurus, semantic-coverage, vocabulary-guidance]
dependency_graph:
  requires: ["03-01"]
  provides: [swadesh-coverage-ui, thesaurus-browser, semantic-providers]
  affects: [lexicon-navigation]
tech_stack:
  added: []
  patterns:
    - FutureProvider for JSON asset loading (rootBundle)
    - Provider for derived coverage computation (watching StreamProvider + FutureProvider)
    - NotifierProvider replacing removed StateProvider (flutter_riverpod 3.x)
    - ConsumerStatefulWidget for mutable expand/collapse + search state
    - Recursive widget pattern for hierarchical tree rendering
key_files:
  created:
    - lib/features/lexicon/data/semantic_providers.dart
    - test/lexicon/swadesh_test.dart
    - test/lexicon/thesaurus_test.dart
  modified:
    - lib/features/lexicon/presentation/swadesh/swadesh_page.dart
    - lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart
    - lib/features/lexicon/data/lexeme_providers.dart
decisions:
  - StateProvider removed in flutter_riverpod 3.x; replaced with NotifierProvider + Notifier subclass in lexeme_providers.dart
  - Coverage matching uses case-insensitive exact match on Lexeme.meaning vs SwadeshItem.concept
  - Thesaurus auto-expands matching nodes during search (no manual expand needed)
  - Recursive _CategoryTile widget handles both container nodes (subcategories) and leaf groups (concepts)
  - swadeshCoverageProvider is a plain Provider (not FutureProvider) — derives from two async sources synchronously via .asData?.value
metrics:
  duration_minutes: 18
  completed_date: "2026-04-09"
  tasks_completed: 2
  files_changed: 6
requirements_satisfied: [LEX-04, LEX-05]
---

# Phase 3 Plan 03: Swadesh List and Thesaurus Browser Summary

Swadesh list checklist (207 items, coverage progress bar, grouped by category) and Conlanger's Thesaurus hierarchical browser (expand/collapse tree, search filtering, "Name this concept" navigation) backed by a shared semantic_providers.dart with JSON asset loading.

## What Was Built

### Task 1: Semantic providers and Swadesh page

**`lib/features/lexicon/data/semantic_providers.dart`** (118 lines)
- `SwadeshItem` model with `fromJson` factory
- `ThesaurusCategory` model with recursive `fromJson` (handles missing fields gracefully — threat T-03-08 mitigated)
- `swadeshListProvider` — FutureProvider loading `assets/swadesh_list.json`
- `swadeshCoverageProvider` — Provider deriving `Map<int, Lexeme?>` from swadesh list + all lexemes (case-insensitive meaning match)
- `thesaurusProvider` — FutureProvider loading `assets/conlangers_thesaurus.json`

**`lib/features/lexicon/presentation/swadesh/swadesh_page.dart`** (321 lines)
- `SwadeshPage extends ConsumerWidget`
- Coverage header: `LinearProgressIndicator` (8px, primary fill) + "N/207 — X%" caption (11px)
- Concept list: 207 items grouped by category, each showing covered (`Icons.check_circle`) or uncovered (`Icons.radio_button_unchecked`) state
- Covered: tappable linked word label in primary color
- Uncovered: "Add word" `TextButton` navigating to `/lexicon/dictionary?create=true&meaning=<concept>`
- Empty state: "No lexicon entries yet. Use this list to guide your first vocabulary choices."

**`test/lexicon/swadesh_test.dart`** (13 tests)
- SwadeshItem JSON parsing
- Asset loading (207 items, non-empty fields)
- Coverage computation logic (case-insensitive, empty lexicon, count)
- ThesaurusCategory parsing (leaf, nested, missing fields)
- Thesaurus asset loading

### Task 2: Thesaurus page

**`lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart`** (436 lines)
- `ThesaurusPage extends ConsumerStatefulWidget`
- State: `String _searchQuery`, `Set<String> _expandedNodes`
- Search bar: `TextField` 40px height with search prefix icon, triggers `setState`
- Tree view: `ListView.builder` rendering categories from `thesaurusProvider`
- `_CategoryTile`: recursive widget handling container nodes (`Icons.expand_more` / `Icons.chevron_right`) and leaf groups
- `_ConceptTile`: covered shows `Icons.check` + word form; uncovered shows `Icons.add_circle_outline` + "Name this concept" `TextButton`
- Search: `_matchesSearch` recursively checks name and concepts; non-matching nodes hidden entirely (not greyed out per UI-SPEC)
- Auto-expand during search; expand/collapse tracked by node path string (e.g. "The Physical World/Cosmology")
- Loading state: `CircularProgressIndicator`
- Error state: "Could not load lexicon. Check that the project database is accessible."
- Empty state: "No lexicon entries yet. Browse categories to find concepts to name."

**`test/lexicon/thesaurus_test.dart`** (15 tests)
- ThesaurusCategory parsing (leaf, container, empty, 3-level nesting)
- Asset loading (non-empty, names non-empty, has hierarchy)
- Search filtering logic (empty query, name match, subcategory match, concept match, no match, case-insensitive, partial, exclusion)

### Deviation: StateProvider fix (Rule 1 — Bug)

**Found during:** Task 1 (tests failed to compile)
**Issue:** `StateProvider` was removed in flutter_riverpod 3.x; `lexeme_providers.dart` used it for `lexemeSearchQueryProvider` and `lexemePosFilterProvider`, causing compile errors across all tests that transitively imported lexeme_providers.
**Fix:** Replaced both with `NotifierProvider<T, S>` backed by `Notifier` subclasses (`_LexemeSearchQuery`, `_LexemePosFilter`). Added convenience `set()` and `toggle()` methods.
**Files modified:** `lib/features/lexicon/data/lexeme_providers.dart`
**Commit:** a5844b7

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| swadesh_test.dart | 13 | PASS |
| thesaurus_test.dart | 15 | PASS |
| lexeme_filter_test.dart | 4 | PASS (pre-existing) |
| lexeme_dao_test.dart | 3 | PASS (pre-existing) |
| phonotactic_validation_test.dart | 6 | PASS (pre-existing) |
| phonotactic_dsl_smoke_test.dart | — | FAIL (pre-existing, unrelated assertion in smoke test) |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | a5844b7 | feat(03-03): Swadesh list page with coverage indicators and semantic providers |
| 2 | 7216fdb | feat(03-03): Thesaurus page with hierarchical tree browser and search |

## Known Stubs

None. All plan goals are fully wired:
- Swadesh: loads from real asset, computes coverage from real lexeme provider, navigates with real query params
- Thesaurus: loads from real asset, checks coverage against real lexeme provider, navigates with real query params

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. JSON assets are bundled read-only (T-03-07 accept). ThesaurusCategory.fromJson uses empty defaults for malformed data (T-03-08 mitigated).

## Self-Check: PASSED

All files found and commits verified:
- FOUND: lib/features/lexicon/data/semantic_providers.dart
- FOUND: lib/features/lexicon/presentation/swadesh/swadesh_page.dart
- FOUND: lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart
- FOUND: test/lexicon/swadesh_test.dart
- FOUND: test/lexicon/thesaurus_test.dart
- FOUND: .planning/phases/03-lexicon/03-03-SUMMARY.md
- FOUND: commit a5844b7
- FOUND: commit 7216fdb
