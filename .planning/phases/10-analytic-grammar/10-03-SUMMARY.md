---
phase: 10-analytic-grammar
plan: "03"
subsystem: grammar-ui
tags: [flutter, riverpod, drift, constructions, analytic-grammar]
dependency_graph:
  requires: [10-01]
  provides: [constructions-page, construction-providers, slot-editor, construction-preview, leipzig-catalog, particle-providers]
  affects: [grammar-shell, app-router]
tech_stack:
  added: []
  patterns:
    - ConsumerStatefulWidget master-detail layout with inline name editing (FocusNode auto-save)
    - ReorderableListView for drag-and-drop slot reordering
    - SegmentedButton<String> slot type selector
    - Autocomplete<String> for Leipzig gloss tag suggestions
    - StreamProvider.family for per-construction slot streams
key_files:
  created:
    - lib/features/grammar/data/construction_providers.dart
    - lib/features/grammar/data/particle_providers.dart
    - lib/features/grammar/domain/leipzig_catalog.dart
    - lib/features/grammar/presentation/constructions/slot_editor.dart
    - lib/features/grammar/presentation/constructions/construction_preview.dart
    - test/unit/grammar/phrase_construction_dao_test.dart
  modified:
    - lib/features/grammar/presentation/constructions/constructions_page.dart
decisions:
  - Created particle_providers.dart in this plan (parallel wave with Plan 02) to unblock construction_preview.dart import — Plan 02 will merge cleanly since both create identical providers from watchClosedClassWords()
  - Created leipzig_catalog.dart here (Plan 02 also creates it in parallel wave) — both plans produce the same list; orchestrator merge will pick one
  - Used FocusNode listener pattern for auto-save on construction name unfocus, matching existing POS edit patterns
metrics:
  duration: "~30 minutes"
  completed_date: "2026-04-13"
  tasks_completed: 2
  files_created: 6
  files_modified: 1
---

# Phase 10 Plan 03: Constructions Page Implementation Summary

Full Constructions page with master-detail layout, visual slot editor with ReorderableListView drag-and-drop reordering, inline construction name editing with auto-save, and live preview substituting real lexicon words for each slot.

## What Was Built

**Task 1: Construction providers + Constructions page master-detail + Slot editor**

- `construction_providers.dart` — three Riverpod providers: `constructionDaoProvider`, `constructionListProvider`, `constructionSlotsProvider` (family by constructionId)
- `particle_providers.dart` — `closedClassLexemeListProvider` wrapping `LexemeDao.watchClosedClassWords()` (parallel-wave parallel to Plan 02)
- `leipzig_catalog.dart` — 85-item `List<String> leipzigGlossCatalog` covering common Leipzig glossing abbreviations
- `constructions_page.dart` — full replacement of placeholder; `ConsumerStatefulWidget` with:
  - Left panel (250px): construction list with auto-select first on load, `FilledButton.icon` add, `IconButton` delete with confirmation dialog
  - Right panel: `TextField` with `FocusNode` auto-save on unfocus, `SlotEditor`, `ConstructionPreview`
  - Empty state with heading "No constructions yet" and descriptive body text
- `slot_editor.dart` — `ConsumerStatefulWidget` with:
  - `ReorderableListView.builder` of `_SlotChip` widgets
  - Each chip: drag handle, label (slotValue), delete icon (immediate, no confirmation)
  - `onReorder` callback calls `dao.reorderSlots(reorderedList)`
  - Inline `_AddSlotForm` expansion: `SegmentedButton<String>` for type (gloss_tag/pos), `Autocomplete<String>` for gloss tags, `DropdownButtonFormField` for POS

**Task 2: Live preview + DAO tests**

- `construction_preview.dart` — `ConsumerWidget` watching `constructionSlotsProvider`, `closedClassLexemeListProvider`, `rootLexemeListProvider`, `posListProvider`; substitutes first matching word per slot, shows placeholder text "(no X particle defined)" / "(no X word in lexicon)" when no match
- `phrase_construction_dao_test.dart` — 5 tests: insert/watchAll, slot ordering, cascade delete, reorder, multi-construction ordering; all pass

## Deviations from Plan

### Auto-added Missing Files

**1. [Rule 2 - Missing] Created particle_providers.dart**
- **Found during:** Task 1 (construction_preview.dart needs `closedClassLexemeListProvider`)
- **Issue:** `construction_preview.dart` imports `particle_providers.dart` which Plan 02 creates in the same wave; the file didn't exist in this worktree
- **Fix:** Created `particle_providers.dart` with `closedClassLexemeListProvider` from `watchClosedClassWords()` — identical to what Plan 02 would produce
- **Files modified:** `lib/features/grammar/data/particle_providers.dart` (created)
- **Commit:** 36b8c17

**2. [Rule 2 - Missing] Created leipzig_catalog.dart**
- **Found during:** Task 1 (`slot_editor.dart` imports `../../domain/leipzig_catalog.dart`)
- **Issue:** `leipzig_catalog.dart` is created by Plan 02 in parallel wave; not present in this worktree
- **Fix:** Created `leipzig_catalog.dart` with `lepizigGlossCatalog` list (~85 Leipzig abbreviations)
- **Files modified:** `lib/features/grammar/domain/leipzig_catalog.dart` (created)
- **Commit:** 36b8c17

## Threat Model Compliance

Per the plan's threat model:
- **T-10-03 (Tampering):** Construction name field has `maxLength: 100` as required. Slot value field has `maxLength: 20` in the `Autocomplete` TextField for gloss tags. Drift parameterized queries used throughout (DAO layer, not raw SQL).

## Known Stubs

None — all data sources are wired to real providers. The `ConstructionPreview` widget shows placeholder text when lexicon data is absent, but this is intentional behavior documented in the UI-SPEC, not a stub.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary crossings introduced. All data flows through existing Drift DAO pattern.

## Self-Check: PASSED

All 7 files verified on disk. Both commits (36b8c17, 42dd183) verified in git log. 5 DAO tests pass. `flutter analyze` reports no errors on all created/modified files.
