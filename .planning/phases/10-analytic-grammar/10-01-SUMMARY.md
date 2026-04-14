---
phase: 10-analytic-grammar
plan: "01"
subsystem: grammar/db
tags: [schema-migration, drift, construction-dao, grammar-navigation]
dependency_graph:
  requires: []
  provides: [schema-v15, ConstructionDao, PhraseConstructions, ConstructionSlots, ParticlesPage, ConstructionsPage]
  affects: [lexeme-dao, grammar-router, grammar-shell]
tech_stack:
  added: [ConstructionDao, PhraseConstructions, ConstructionSlots]
  patterns: [drift-dao, tdd-red-green, schema-migration-stub]
key_files:
  created:
    - lib/features/grammar/data/construction_dao.dart
    - lib/features/grammar/data/construction_dao.g.dart
    - lib/features/grammar/presentation/particles/particles_page.dart
    - lib/features/grammar/presentation/constructions/constructions_page.dart
    - test/integration/migration_v14_to_v15_test.dart
    - test/unit/grammar/construction_dao_test.dart
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/lexicon/data/lexeme_dao.dart
    - lib/features/grammar/presentation/grammar_shell.dart
    - lib/router/app_router.dart
    - test/widget/grammar/grammar_router_test.dart
decisions:
  - "PhraseConstructions and ConstructionSlots tables added at v15 with cascade-delete FK"
  - "isClosedClass defaults false; watchRoots excludes closed-class words per D-02"
  - "Grammar sidebar extended from 3 to 5 items: Particles at index 2, Constructions at index 3, Typology at index 4"
  - "ParticlesPage and ConstructionsPage are stateless placeholders — full implementation in plans 02/03"
metrics:
  duration: "25 min"
  completed: "2026-04-13"
  tasks: 2
  files: 12
---

# Phase 10 Plan 01: Schema v15 + Grammar Navigation Foundation Summary

Schema migration to v15 with closed-class columns and construction tables, ConstructionDao with full CRUD/reorder, watchRoots closed-class filter, Grammar sidebar extended to 5 items (D-13), and placeholder pages for Particles and Constructions sub-tabs.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Schema v15 migration + ConstructionDao + LexemeDao filter | 97399c7 | Done |
| 2 | Grammar sidebar 5 items + GoRouter branches + placeholder pages | 1f34b1e | Done |

## What Was Built

**Task 1 — Schema and Data Layer:**
- Added `isClosedClass` (bool, default false) and `glossTag` (text nullable) columns to `Lexemes` table
- Added `PhraseConstructions` table: id, name, ordering
- Added `ConstructionSlots` table: id, constructionId (FK cascade), slotType, slotValue, label, ordering
- Created `ConstructionDao` with `watchAll`, `insertConstruction`, `updateConstruction`, `deleteConstruction`, `watchSlotsFor`, `insertSlot`, `updateSlot`, `deleteSlot`, `reorderSlots` (batch)
- Updated `watchRoots()` in `LexemeDao` to exclude `isClosedClass = true` words
- Added `watchClosedClassWords()` to `LexemeDao`
- Bumped `schemaVersion` 14 → 15 with `onUpgrade` block
- Ran `dart run build_runner build` to regenerate Drift code

**Task 2 — UI Navigation Layer:**
- Created `ParticlesPage` stateless placeholder widget
- Created `ConstructionsPage` stateless placeholder widget
- Updated `GrammarShell._sidebarItems` from 3 to 5 entries per D-13:
  - Index 0: POS & Dimensions (unchanged)
  - Index 1: Inflections (unchanged)
  - Index 2: Particles (new, Phase 10)
  - Index 3: Constructions (new, Phase 10)
  - Index 4: Typology (moved from index 2)
- Updated `app_router.dart` Grammar `StatefulShellRoute` from 3 to 5 branches in matching index order
- Updated `grammar_router_test.dart`: 5-branch router + 2 new widget tests

## Test Results

| Test File | Tests | Status |
|-----------|-------|--------|
| test/integration/migration_v14_to_v15_test.dart | 4 | Pass |
| test/unit/grammar/construction_dao_test.dart | 4 | Pass |
| test/widget/grammar/grammar_router_test.dart | 10/12 pass* | Pass (new tests) |

*2 pre-existing failures: file-deletion assertions for `inflectional_rules_page.dart` and `paradigm_viewer_page.dart` that check for Phase 04-13 deletions — these files exist in the codebase at the base commit (`ccc8441`). Not caused by this plan.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `ParticlesPage` — placeholder with "No particles yet" text; wired in Plan 02
- `ConstructionsPage` — placeholder with "No constructions yet" text; wired in Plan 03

## Threat Flags

None. Drift parameterized queries used throughout ConstructionDao — all values bound as parameters (T-10-01 mitigated). Max-length validation deferred to Plans 02/03 per T-10-02 plan.

## Self-Check

- [x] `lib/features/grammar/data/construction_dao.dart` — exists
- [x] `lib/features/grammar/presentation/particles/particles_page.dart` — exists
- [x] `lib/features/grammar/presentation/constructions/constructions_page.dart` — exists
- [x] `lib/db/app_database.dart` contains `schemaVersion => 15`
- [x] Task 1 commit `97399c7` — exists
- [x] Task 2 commit `1f34b1e` — exists

## Self-Check: PASSED
