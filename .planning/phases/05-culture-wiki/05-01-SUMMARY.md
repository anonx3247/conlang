---
phase: 05-culture-wiki
plan: "01"
subsystem: culture-data-layer
tags: [drift, dao, schema-migration, riverpod, domain-logic, tdd]
dependency_graph:
  requires: []
  provides:
    - CulturePages table (schema v13)
    - CultureDao (CRUD + tree queries)
    - culture_providers (reactive streams)
    - PageHistory (back/forward navigation)
    - block_splitter (Markdown heading splitting)
  affects:
    - lib/db/app_database.dart (schema v13)
    - All plans in phase 05 (depend on this data layer)
tech_stack:
  added:
    - CulturePages Drift table with self-referential FK (onDelete: setNull)
  patterns:
    - DatabaseAccessor<AppDatabase> DAO pattern (matches grammar_dao.dart)
    - Manual StreamProvider/Provider (no @riverpod codegen — Drift type constraint)
    - TDD red-green cycle for all new code
key_files:
  created:
    - lib/features/culture/data/culture_dao.dart
    - lib/features/culture/data/culture_dao.g.dart
    - lib/features/culture/data/culture_providers.dart
    - lib/features/culture/domain/page_history.dart
    - lib/features/culture/domain/block_splitter.dart
    - test/unit/culture/culture_dao_test.dart
    - test/unit/culture/page_history_test.dart
    - test/unit/culture/block_splitter_test.dart
  modified:
    - lib/db/app_database.dart (schema v12 -> v13, CulturePages table, CultureDao DAO)
    - lib/db/app_database.g.dart (regenerated)
decisions:
  - "Used currentDatabaseProvider (not projectDatabaseProvider family) in culture_providers.dart — matches the actual pattern from grammar_providers.dart; plan's snippet was illustrative"
  - "updatedAt timestamp test uses 1100ms delay — SQLite stores DateTime at second precision, so a 10ms delay is insufficient for isAfter comparison"
  - "Test files placed in test/unit/culture/ subdirectory — matches existing pattern (grammar/, lexicon/, etc.)"
  - "drift hide isNull, isNotNull in test imports — resolves ambiguity with matcher package"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-12"
  tasks_completed: 2
  files_created: 8
  files_modified: 2
---

# Phase 5 Plan 01: Culture Wiki Data Layer Summary

**One-liner:** Drift schema v13 with CulturePages self-referential tree table, full CRUD DAO, Riverpod stream providers, PageHistory browser-nav stack, and heading-based Markdown block splitter.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | CulturePages table, v13 migration, CultureDao, providers | 15d6507 | app_database.dart, culture_dao.dart, culture_providers.dart, culture_dao_test.dart |
| 2 | PageHistory and block splitter domain utilities with tests | ab4811f | page_history.dart, block_splitter.dart, page_history_test.dart, block_splitter_test.dart |

## What Was Built

### Schema v13 — CulturePages table

Added to `lib/db/app_database.dart`:
- `CulturePages` table with `id`, `parentId` (self-ref FK with `onDelete: setNull`), `title`, `content`, `icon`, `ordering`, `createdAt`, `updatedAt`
- `schemaVersion` bumped from 12 to 13
- v13 migration block: `m.createTable(culturePages)`

### CultureDao

Full CRUD + tree operations:
- `watchRootPages()` — root pages ordered by ordering
- `watchChildren(parentId)` — children of a node ordered by ordering
- `watchAllPages()` — all pages ordered by title (for wiki-link index)
- `getPageById(id)` / `watchPageById(id)` — single-page access
- `createPage(...)` — insert with auto-timestamps
- `updatePage(id, ...)` — partial update, always bumps `updatedAt`
- `deletePage(id)` — cascade sets children's parentId to null via FK
- `reparentPage(pageId, newParentId, newOrdering)` — atomic transaction
- `swapOrdering(idA, orderingA, idB, orderingB)` — atomic ordering swap
- `maxSiblingOrdering(parentId?)` — for appending new pages at end

### Culture Providers

6 providers in `culture_providers.dart`:
- `culturePageListProvider` — all pages stream (title index source)
- `pageTitleIndexProvider` — derived `Map<String, int>` for wiki-link resolution
- `cultureRootPagesProvider` — root-level pages stream
- `cultureChildPagesProvider` — family by parentId
- `selectedCulturePageIdProvider` — ephemeral UI state (StateProvider)
- `culturePageProvider` — single page by id, family

### PageHistory

Browser-style back/forward navigation stack (`ChangeNotifier`):
- `push(pageId)` — navigate to page, clears forward history
- `goBack()` — moves cursor back, returns previous id or null
- `goForward()` — moves cursor forward, returns next id or null
- `canGoBack` / `canGoForward` / `currentPageId` — state getters

### Block Splitter

Heading-based Markdown section splitting:
- `splitIntoBlocks(markdown)` — splits at `#`–`######` headings, respects code fences
- `joinBlocks(blocks)` — lossless inverse, round-trip guaranteed

## Test Results

| Test File | Tests | Result |
|-----------|-------|--------|
| culture_dao_test.dart | 8 | PASS |
| page_history_test.dart | 6 | PASS |
| block_splitter_test.dart | 10 | PASS |
| **Total** | **24** | **ALL PASS** |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `isNull`/`isNotNull` import ambiguity in test**
- **Found during:** Task 1 test run
- **Issue:** `drift` exports `isNull` and `isNotNull` which clash with `matcher` package used by flutter_test
- **Fix:** Added `hide isNull, isNotNull` to drift import in culture_dao_test.dart
- **Files modified:** test/unit/culture/culture_dao_test.dart

**2. [Rule 1 - Bug] Adjusted provider pattern in culture_providers.dart**
- **Found during:** Task 1 implementation
- **Issue:** Plan snippet used `ref.watch(projectDatabaseProvider)!` but `projectDatabaseProvider` is a family provider requiring a projectId argument; the correct pattern (from grammar_providers.dart) uses `currentDatabaseProvider`
- **Fix:** Used `ref.watch(currentDatabaseProvider)` with null guard (`if (db == null) return Stream.value(const [])`)
- **Files modified:** lib/features/culture/data/culture_providers.dart

**3. [Rule 1 - Bug] Increased updatedAt timestamp delay from 10ms to 1100ms in test**
- **Found during:** Task 1 test run
- **Issue:** SQLite stores DateTime at second precision; 10ms delay insufficient for `isAfter` comparison
- **Fix:** Changed delay to 1100ms
- **Files modified:** test/unit/culture/culture_dao_test.dart

**4. [Rule 3 - Blocking] Ran build_runner from worktree directory**
- **Found during:** Task 1 verification
- **Issue:** Plan's verify command ran `dart run build_runner` from main project path; generated files needed in worktree
- **Fix:** Ran build_runner from worktree working directory

## Known Stubs

None — all data flows are wired to the real SQLite database.

## Threat Flags

None — CulturePages table is local SQLite, single-user; trust boundary analysis matches plan's threat model (T-05-01, T-05-02, T-05-03: all `accept`).

## Self-Check: PASSED

Files exist:
- FOUND: lib/features/culture/data/culture_dao.dart
- FOUND: lib/features/culture/data/culture_providers.dart
- FOUND: lib/features/culture/domain/page_history.dart
- FOUND: lib/features/culture/domain/block_splitter.dart
- FOUND: test/unit/culture/culture_dao_test.dart
- FOUND: test/unit/culture/page_history_test.dart
- FOUND: test/unit/culture/block_splitter_test.dart

Commits exist:
- FOUND: 15d6507 (Task 1)
- FOUND: ab4811f (Task 2)

Schema version 13 in app_database.dart: VERIFIED
All 24 tests passing: VERIFIED
