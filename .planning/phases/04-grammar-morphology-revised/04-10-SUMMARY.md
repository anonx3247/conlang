---
phase: 04-grammar-morphology-revised
plan: 10
subsystem: grammar-markers
tags: [markers, D-43, D-44, D-45, D-46, D-47, G-03, GRAM-02, GRAM-03, unmarked-cells]
requirements: [G-03, GRAM-02, GRAM-03]
dependency_graph:
  requires:
    - 04-08 (v9 schema with Markers table)
  provides:
    - MarkerDao + markersForPosProvider (Markers data layer)
    - MarkerDecl domain value type (parallel to InflectionalRule)
    - ParadigmUnmarked sealed variant on ParadigmCell
    - D-45 resolution step 3 in computeParadigmCell (rule → marker → uncovered)
    - D-47 render branch in paradigm_table_widget (bare root + ∅ badge)
  affects:
    - plan 04-13 will wire cell-click-to-marker-editor per D-51/D-52
tech_stack:
  added: []
  patterns:
    - "Domain class renamed to avoid Drift-generated row-class collision (`MarkerDecl` instead of `Marker`)"
    - "Extracted local closure `markerOrUncovered` inside engine function to dedupe fall-through sites"
    - "Sealed-class pattern match extension (new ParadigmUnmarked arm)"
key_files:
  created:
    - lib/features/grammar/domain/marker.dart
    - lib/features/grammar/data/marker_dao.dart
    - lib/features/grammar/data/marker_dao.g.dart
    - test/unit/grammar/marker_dao_test.dart
    - test/unit/grammar/marker_resolution_test.dart
    - test/widget/grammar/unmarked_cell_render_test.dart
  modified:
    - lib/db/app_database.dart
    - lib/db/app_database.g.dart
    - lib/features/grammar/data/grammar_providers.dart
    - lib/features/grammar/data/typology_providers.dart
    - lib/features/grammar/domain/paradigm_cell.dart
    - lib/features/grammar/domain/paradigm_engine.dart
    - lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart
decisions:
  - "Domain class named MarkerDecl to avoid Drift-generated Marker row-class collision — keeps plan 04-08's committed schema untouched"
  - "Markers consulted ONLY when rule chain is empty (chain.isEmpty) — makes D-46 rule-wins-on-tie automatic, no explicit tie-break needed"
  - "Marker resolution wrapped in local closure markerOrUncovered so both fall-through sites (candidates empty + all candidates failed DSL) route through the same code path"
  - "Marker ties sorted by specificity desc, first wins on equal specificity — NOT surfaced as ParadigmAmbiguous (asserting absence is non-contradictory, unlike rule ambiguity D-12)"
  - "Unmarked cell click handler intentionally reuses existing openDialog (CellOverrideDialog) — plan 04-13 replaces the entire click flow per D-51/D-52"
  - "_UnmarkedCell mirrors _FilledCell's showRom/ViolationText/exception logic but at onSurface alpha 0.45 with trailing ∅ top-right badge"
metrics:
  duration: 25 min
  completed: 2026-04-11
  tasks: 4
  files_created: 6
  files_modified: 7
  tests_added: 18
  tests_passing: 178
---

# Phase 04 Plan 10: Unmarked Cells (G-03) — MarkerDao + Engine + Render Summary

Implement G-03 (unmarked cells) end-to-end: MarkerDao data layer, D-45 resolution order in computeParadigmCell, D-46 rule-wins-on-tie tiebreaker, and D-47 bare-root-plus-∅-badge render branch — wiring Phase 4's v9 Markers table into the paradigm computation path without regressing the existing uncovered-em-dash behavior.

## Objective

Satisfy D-43 (binding-set cascade semantics — not per-cell), D-44 (Markers table storage, already in v9), D-45 (resolution order override → rule → marker → uncovered), D-46 (specificity uses D-10 algorithm; rules win on exact ties), and D-47 (bare root + ∅ badge render distinct from uncovered em-dash and normal derived cells). The plan consumed Phase 4 requirements G-03, GRAM-02, GRAM-03.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Marker domain + MarkerDao + providers (data layer) | `a30a938` | marker.dart, marker_dao.dart, grammar_providers.dart, app_database.dart, marker_dao_test.dart |
| 2 | Regenerate Drift code for MarkerDao | `8c028d8` | marker_dao.g.dart, app_database.g.dart |
| 3 | Wire markers into paradigm engine (D-45 + D-46) with TDD | `572f083` | paradigm_cell.dart, paradigm_engine.dart, typology_providers.dart, marker_resolution_test.dart |
| 4 | Render ParadigmUnmarked cells per D-47 | `826a923` | paradigm_table_widget.dart, unmarked_cell_render_test.dart |

## Implementation Highlights

### Data layer (Task 1 + 2)

- **`MarkerDecl` domain value type** (`lib/features/grammar/domain/marker.dart`) mirrors `InflectionalRule` shape minus `source`/`name`/`kind`: a marker is just `(id, posId, bindings)`. Exposes `specificity` getter and a `matches(target)` predicate that consults `bindings.dims` only (empty dims → never fires, matching D-13's rule that unbound rules don't participate in inflection).
- **`MarkerDao`** (`lib/features/grammar/data/marker_dao.dart`) is a `DatabaseAccessor<AppDatabase>` over the v9 `Markers` table with four methods: `watchMarkersForPos`, `insertMarker`, `updateMarker`, `deleteMarker`. Returns `List<MarkerDecl>` (not Drift `Marker` rows) so the paradigm engine stays decoupled from SQL types.
- **Provider wiring**: `markerDaoProvider` (scoped to current project database) and `markersForPosProvider(posId)` — the latter feeds `computedInflectedParadigmProvider` downstream.
- **Drift registration**: `MarkerDao` added to the `@DriftDatabase(daos: [...])` annotation in `app_database.dart`. `build_runner` regenerated `marker_dao.g.dart` and refreshed `app_database.g.dart` with the `markerDao` accessor.
- **Naming collision avoidance (key decision)**: the Drift-generated row class for the `Markers` table is `Marker` (default singularisation). The domain class is named `MarkerDecl` so both types can coexist without a type alias dance or touching plan 04-08's committed schema.

### Engine integration (Task 3)

- **`ParadigmUnmarked` sealed variant** added to `paradigm_cell.dart` carrying `(root, source)` — `root` is the bare (uninflected) form to display; `source` is the winning `MarkerDecl` kept for the forthcoming plan 04-13 click-to-edit wiring.
- **`computeParadigmCell` gains `markers` parameter** (defaults to `const []`). The D-45 step 3 logic is factored into a local closure `markerOrUncovered(reason)` so BOTH fall-through sites route through identical code:
  1. `candidates.isEmpty` with `chain.isEmpty` (no rule ever matched remaining dims)
  2. All top-group candidates failed their DSL with `chain.isEmpty` (rules bound to the cell but none fired)

  The closure filters `markers.where((m) => m.matches(target))`, sorts by specificity desc, and returns `ParadigmUnmarked(root, source)` with the winner — or falls through to `ParadigmUncovered(reason)` when no markers match.
- **D-46 tie-break is automatic**: markers are only consulted when `chain.isEmpty`. If a rule fires and produces ANY chain, the engine returns `ParadigmFilled` without consulting markers — so rules always win on exact ties by construction, no explicit comparison needed.
- **Marker ties (two markers with identical bindings) are NOT ambiguous**: the engine returns the first marker after stable sort. Rationale: unlike rules (D-12), asserting absence is non-contradictory — two markers both saying "no form change here" are consistent.
- **`generateParadigm` gains `markers` parameter** and forwards it to `computeParadigmCell` for every cell in the Cartesian product.
- **`computedInflectedParadigmProvider` watches `markersForPosProvider(pos.id)`** and passes the resolved list into `generateParadigm`. Empty markers preserve the existing uncovered-em-dash behavior (no regression).

### Render layer (Task 4)

- **`_UnmarkedCell` widget** added to `paradigm_table_widget.dart`. Mirrors `_FilledCell`'s romanization (`showRom`), phonotactic validation (`phonotacticValidatorProvider`), and `isPhonologicalException` exception logic — but wraps everything in muted gray (`onSurface alpha 0.45` primary, `alpha 0.35` IPA second line).
- **D-47 trailing ∅ badge**: `Positioned(top: 2, right: 2)` `Text('∅')` in `labelSmall` at `alpha 0.55` with `FontWeight.w600`. Subtle enough to read as an annotation rather than a warning (which is the visual role reserved for the amber override cell).
- **Switch branch** in `_ParadigmCellWidget.build` adds the `ParadigmUnmarked(:final root) => _UnmarkedCell(root: root, lexemeId: lexemeId)` arm next to the existing `ParadigmFilled` / `ParadigmUncovered` / `ParadigmAmbiguous` arms. A code comment notes that the click handler intentionally reuses `openDialog()` — plan 04-13 replaces the entire click flow per D-51/D-52.

## Tests

### Unit tests

- **`marker_dao_test.dart`** — 4 tests: `insertMarker` writes a row, `watchMarkersForPos` filters by POS (cross-POS isolation), `deleteMarker` removes and streams empty, `updateMarker` replaces bindings in place.
- **`marker_resolution_test.dart`** — 9 tests locking D-45 resolution order and D-46 tie-break:
  1. Marker fills an otherwise-uncovered cell (resolution step 3)
  2. Rule beats marker on identical bindings (D-46 tie-break)
  3. Higher-specificity marker wins when the rule's DSL fails so no chain is produced
  4. Mixed rule+marker with DIFFERENT bindings → ParadigmFilled (rule fires, marker NOT consulted)
  5. Two markers with identical bindings → ParadigmUnmarked (first wins, not ambiguous)
  6. No rule and no marker → ParadigmUncovered
  7. Engine resolution does NOT handle overrides (those stay at widget layer)
  8. Empty markers list preserves existing paradigm engine behavior (regression)
  9. **D-43 binding-set cascade** — marker `{gender:M}` cascades across BOTH (M,SG) and (M,PL) cells, while (F,SG) and (F,PL) stay uncovered

### Widget tests

- **`unmarked_cell_render_test.dart`** — 5 tests:
  1. Bare root text and ∅ badge both render
  2. Unmarked cell does NOT show em-dash (3 uncovered cells = 3 em-dashes, unmarked cell = 0)
  3. Visually distinct from `ParadigmFilled` (4-cell mixed fixture: 1 unmarked + 3 filled with distinct IPA forms)
  4. `ViolationText` is mounted for phonotactic highlighting
  5. No regression when markers are absent — uncovered em-dashes all survive

### Regression

- `paradigm_engine_test.dart` (12 tests), `paradigm_generation_test.dart` (13 tests), `paradigm_engine_rewrite_test.dart` — all still green
- `paradigm_table_widget_test.dart` (8 tests) — all still green
- Full Phase 4 grammar suites: **178 tests passing**, 0 failing

## Deviations from Plan

**None** — plan executed exactly as written. One minor ordering note:

- During Task 4 the first widget test ("renders bare root and ∅ badge") initially failed with `!timersPending` because the test body did not call `teardownWidget(tester)` before returning. The other 4 tests already had the teardown call. Fix: added the missing `await teardownWidget(tester);` — consistent with the rest of the suite. Classified as in-scope polish, not a deviation.

## Known Stubs

None. All UI paths, engine paths, and providers are wired end-to-end. Unmarked cells render from real `markersForPosProvider` data via `computedInflectedParadigmProvider`, not a mock or placeholder.

## Next Plan Handoff

Plan 04-10 closes G-03 at the data + engine + render layers. It does NOT provide a Markers editor UI — creating/editing markers requires either hand-inserting DB rows or the Markers editor that plan 04-13 will deliver as part of the Inflections sub-tab restructure (D-51/D-52 cell-click flow). An empty `Markers` table preserves the existing uncovered-em-dash behavior, so the app continues to work without marker data.

## Self-Check: PASSED

Verified:
- [x] `lib/features/grammar/domain/marker.dart` exists, contains `class MarkerDecl`
- [x] `lib/features/grammar/data/marker_dao.dart` exists, contains `class MarkerDao extends DatabaseAccessor`
- [x] `lib/features/grammar/data/marker_dao.g.dart` exists, contains `_$MarkerDaoMixin`
- [x] `lib/db/app_database.g.dart` exposes `late final MarkerDao markerDao`
- [x] `lib/features/grammar/data/grammar_providers.dart` exposes `markerDaoProvider` and `markersForPosProvider`
- [x] `lib/features/grammar/domain/paradigm_cell.dart` contains `class ParadigmUnmarked`
- [x] `lib/features/grammar/domain/paradigm_engine.dart` accepts `markers` parameter and returns `ParadigmUnmarked`
- [x] `lib/features/grammar/data/typology_providers.dart` forwards `markers` from `markersForPosProvider` through `generateParadigm`
- [x] `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` renders `ParadigmUnmarked` via `_UnmarkedCell` with bare root + `∅` badge
- [x] Four atomic commits present: `a30a938`, `8c028d8`, `572f083`, `826a923`
- [x] 18 new tests all pass; 178 total grammar tests pass; no regressions
