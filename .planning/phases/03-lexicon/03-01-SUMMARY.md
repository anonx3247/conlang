---
phase: 03-lexicon
plan: "01"
subsystem: lexicon-data-layer
tags: [drift, dao, riverpod, json-assets, routing, navigation]
dependency_graph:
  requires:
    - 02-10  # Morphology engine complete (MorphologicalRuleExceptions FK)
    - 01-02  # Project database provider (currentDatabaseProvider)
  provides:
    - LexemeDao with CRUD + stream methods
    - lexeme_providers.dart (Riverpod providers for lexeme data)
    - LexiconShell with 3 sub-nav items
    - /lexicon/dictionary, /lexicon/swadesh, /lexicon/thesaurus routes
    - assets/swadesh_list.json (207 items)
    - assets/conlangers_thesaurus.json (hierarchical semantic domain tree)
    - schema v7 (isPhonologicalException on Lexemes)
  affects:
    - lib/db/app_database.dart (schema bump, new DAO registration)
    - lib/router/app_router.dart (Branch 2 replaced)
    - lib/shared/widgets/app_shell.dart (Lexicon tab enabled)
tech_stack:
  added:
    - swadesh_list.json (207-item bundled JSON asset)
    - conlangers_thesaurus.json (20-category semantic domain tree, ~900 concepts)
  patterns:
    - Drift DAO with @DriftAccessor (mirrors MorphologyDao pattern)
    - Manual Riverpod Provider/StreamProvider (not codegen — established convention for Drift types)
    - StatefulShellRoute.indexedStack nested inside StatefulShellBranch (mirrors Phonology/Morphology routing)
    - TDD: RED (failing tests) → GREEN (implementation) → no refactor needed
key_files:
  created:
    - lib/features/lexicon/data/lexeme_dao.dart
    - lib/features/lexicon/data/lexeme_dao.g.dart
    - lib/features/lexicon/data/lexeme_providers.dart
    - lib/features/lexicon/presentation/lexicon_shell.dart
    - lib/features/lexicon/presentation/dictionary/dictionary_page.dart
    - lib/features/lexicon/presentation/swadesh/swadesh_page.dart
    - lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart
    - assets/swadesh_list.json
    - assets/conlangers_thesaurus.json
    - test/lexicon/lexeme_dao_test.dart
    - test/lexicon/lexeme_filter_test.dart
  modified:
    - lib/db/app_database.dart (schema v7, LexemeDao registration, isPhonologicalException column)
    - lib/db/app_database.g.dart (regenerated)
    - lib/router/app_router.dart (Branch 2 replaced with LexiconShell + 3 sub-routes)
    - lib/router/app_router.g.dart (regenerated)
    - lib/shared/widgets/app_shell.dart (Lexicon tab enabled)
    - pubspec.yaml (JSON assets registered)
decisions:
  - "Manual Riverpod providers used (not @riverpod codegen) for all Drift-type providers — consistent with established 01-05 project convention"
  - "isPhonologicalException column added to Lexemes in schema v7 (for phonotactic exception marking — core requirement from PROJECT.md)"
  - "derivedSearchMatchesProvider added for derived-form search bubbling (D-11) — provides foundation for Plan 02 detail panel highlighting"
  - "DictionaryPage/SwadeshPage/ThesaurusPage are intentional stubs — Plans 02/03/04 will replace them"
metrics:
  duration_minutes: ~30
  tasks_completed: 2
  files_created: 11
  files_modified: 6
  tests_added: 9
  tests_passing: 9
  completed_date: "2026-04-09"
---

# Phase 3 Plan 01: Lexicon Data Layer Summary

**One-liner:** Drift LexemeDao with schema v7 migration, Riverpod providers with derived-word search, bundled Swadesh (207) + Thesaurus JSON assets, and LexiconShell wired into GoRouter with Lexicon tab enabled.

## What Was Built

### Task 1: LexemeDao, schema migration, providers, JSON assets, tests

**LexemeDao** (`lib/features/lexicon/data/lexeme_dao.dart`):
- `@DriftAccessor(tables: [Lexemes, MorphologicalRuleExceptions])` following MorphologyDao pattern
- `watchRoots()` — streams root lexemes (rootId IS NULL) ordered by IPA
- `watchDerivedForms(String rootId)` — streams derived forms for a given root
- `watchAllLexemes()` — streams all lexemes for derived-word search (D-11)
- `insertLexeme`, `updateLexeme`, `deleteLexeme` — CRUD operations
- `watchExceptionsForLexeme`, `insertException`, `deleteException` — morphological rule exception management

**Schema v7** (`lib/db/app_database.dart`):
- `BoolColumn get isPhonologicalException` added to Lexemes table (default false)
- `onUpgrade` migration: `if (from < 7) { await m.addColumn(lexemes, lexemes.isPhonologicalException); }`
- `beforeOpen` safety-net: `ALTER TABLE lexemes ADD COLUMN "is_phonological_exception" INTEGER NOT NULL DEFAULT 0` wrapped in try/catch
- `LexemeDao get lexemeDao => LexemeDao(this)` getter

**Riverpod providers** (`lib/features/lexicon/data/lexeme_providers.dart`):
- `lexemeDaoProvider` — DAO derived from currentDatabaseProvider
- `rootLexemeListProvider` — reactive stream of root lexemes
- `allLexemeListProvider` — reactive stream of all lexemes (roots + derived)
- `lexemeSearchQueryProvider` — StateProvider<String> for search query
- `lexemePosFilterProvider` — StateProvider<Set<String>> for POS filter
- `filteredLexemeListProvider` — client-side filter (IPA, romanization, meaning, derived-form bubbling)
- `derivedSearchMatchesProvider` — Set<int> of derived form IDs matching current query

**JSON assets**:
- `assets/swadesh_list.json`: 207-item standard Swadesh list with id, concept, category fields
- `assets/conlangers_thesaurus.json`: 20 top-level categories, 75+ subcategories, ~900 leaf concepts in hierarchical structure

### Task 2: LexiconShell, router wiring, tab enablement

**LexiconShell** (`lib/features/lexicon/presentation/lexicon_shell.dart`):
- Exact mirror of MorphologyShell: 200px sidebar + VerticalDivider + Expanded content
- Header: `'LEXICON'` with letterSpacing 1.2
- Three sidebar items: Dictionary (menu_book), Swadesh List (checklist), Thesaurus (category)
- Uses `colorScheme.surfaceContainerLow` / `colorScheme.primaryContainer` for sidebar colors

**Router** (`lib/router/app_router.dart`):
- Branch 2 replaced: `/lexicon` redirects to `/lexicon/dictionary`
- `StatefulShellRoute.indexedStack` with 3 `StatefulShellBranch` children
- Routes: `/lexicon/dictionary`, `/lexicon/swadesh`, `/lexicon/thesaurus`
- `_ComingSoonPage(section: 'Lexicon')` removed

**AppShell** (`lib/shared/widgets/app_shell.dart`):
- Lexicon tab changed from `enabled: false, phase: 'Phase 3'` to `enabled: true, phase: null`

## Deviations from Plan

None — plan executed exactly as written. The `phonotactic_dsl_smoke_test.dart` failure noted in the full test run is a pre-existing issue predating this plan (confirmed by testing at the base commit `859fc22` before Task 2 changes).

## Known Stubs

The following stubs are intentional scaffolds for subsequent plans:

| File | Stub | Reason |
|------|------|--------|
| `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` | `Center(child: Text('Dictionary — coming soon'))` | Plan 03-02 will implement full word list + detail panel |
| `lib/features/lexicon/presentation/swadesh/swadesh_page.dart` | `Center(child: Text('Swadesh List — coming soon'))` | Plan 03-03 will implement interactive Swadesh browser |
| `lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart` | `Center(child: Text('Thesaurus — coming soon'))` | Plan 03-04 will implement semantic domain browser |

These stubs do NOT prevent this plan's goal (data layer + navigation skeleton) from being achieved. Each stub is the explicit insertion point for subsequent plans as documented in 03-01-PLAN.md.

## Threat Flags

No new security-relevant surface beyond what the plan's threat model covers. All DB operations use Drift parameterized queries (T-03-02 mitigated). JSON assets are read-only bundled data (T-03-01 accepted).

## Self-Check: PASSED

All key files verified present in git commits:
- `lib/features/lexicon/data/lexeme_dao.dart` — FOUND (commit 859fc22)
- `lib/features/lexicon/data/lexeme_dao.g.dart` — FOUND (commit 859fc22)
- `lib/features/lexicon/data/lexeme_providers.dart` — FOUND (commit 859fc22)
- `lib/features/lexicon/presentation/lexicon_shell.dart` — FOUND (commit b359d70)
- `lib/features/lexicon/presentation/dictionary/dictionary_page.dart` — FOUND (commit b359d70)
- `lib/features/lexicon/presentation/swadesh/swadesh_page.dart` — FOUND (commit b359d70)
- `lib/features/lexicon/presentation/thesaurus/thesaurus_page.dart` — FOUND (commit b359d70)
- `assets/swadesh_list.json` — FOUND (commit 859fc22)
- `assets/conlangers_thesaurus.json` — FOUND (commit 859fc22)
- `test/lexicon/lexeme_dao_test.dart` — FOUND (commit 859fc22)
- `test/lexicon/lexeme_filter_test.dart` — FOUND (commit 859fc22)

Commits verified:
- `859fc22` feat(03-01): LexemeDao, schema v7, providers, JSON assets, and tests — FOUND
- `b359d70` feat(03-01): LexiconShell, router wiring, tab enablement, placeholder pages — FOUND

Test results: 9/9 tests pass (`flutter test test/lexicon/`)
