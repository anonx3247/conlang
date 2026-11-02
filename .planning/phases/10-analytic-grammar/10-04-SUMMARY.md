---
phase: 10-analytic-grammar
plan: "04"
subsystem: grammar/typology
tags: [typology, word-order, dropdown, auto-save, flutter, riverpod]
dependency_graph:
  requires: [10-01]
  provides: [AGRAM-03, word-order-settings]
  affects: [phase-12-scratchpad]
tech_stack:
  added: []
  patterns: [auto-save via writeTypologyKey, StreamProvider mapping, DropdownButtonFormField with initialValue]
key_files:
  created: []
  modified:
    - lib/features/grammar/data/typology_providers.dart
    - lib/features/grammar/presentation/typology/typology_page.dart
    - test/unit/grammar/typology_providers_test.dart
decisions:
  - "Used existing _section() helper for all 4 new dropdowns — avoids code duplication and ensures UI consistency"
  - "Word Order section placed after Modality with Divider separator matching 10-UI-SPEC layout contract"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-13T08:17:09Z"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 3
---

# Phase 10 Plan 04: Word Order Typology Settings Summary

## One-liner

Four auto-saving word order dropdowns (head directionality, adposition type, adjective placement, genitive placement) added to Typology page backed by extended TypologySettings model with 7 persisted project_settings keys.

## What Was Built

Extended the Grammar > Typology page with a new "Word Order" section below the Modality dropdown. The section contains four labeled dropdowns, each with an info tooltip, that auto-save on selection via `writeTypologyKey`.

### Model changes (`typology_providers.dart`)

- `TypologySettings` extended with 4 nullable fields: `headDirection`, `adpositionType`, `adjPlacement`, `genPlacement`
- 4 new key constants: `_kHeadDirectionKey`, `_kAdpositionTypeKey`, `_kAdjPlacementKey`, `_kGenPlacementKey`
- `readTypologySettings` reads all 7 keys from `project_settings`
- `typologySettingsProvider` stream maps all 7 keys
- `copyWith`, `==`, `hashCode`, `toString` all updated to include new fields

### UI changes (`typology_page.dart`)

- 4 new option lists: `_headDirectionOptions`, `_adpositionTypeOptions`, `_adjPlacementOptions`, `_genPlacementOptions`
- 4 new tooltip strings
- Word Order section with visual separator (SizedBox + Divider + SizedBox), section header text, and subtitle
- 4 `_section()` calls for Head Directionality, Adposition Type, Adjective Placement, Genitive Placement

### Test changes (`typology_providers_test.dart`)

Added group `'Phase 10 word order settings'` with 6 tests:
1. `head_direction` round-trip
2. `adposition_type` round-trip
3. `adj_placement` round-trip
4. `gen_placement` round-trip
5. All four new fields null when no keys stored
6. Equality comparison includes new fields

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1    | 63a8c83 | feat(10-04): extend Typology page with Word Order section |

## Test Results

```
00:03 +19: All tests passed!
```

All 19 tests pass (13 pre-existing + 6 new Phase 10 word order tests).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all four dropdowns are fully wired to `writeTypologyKey` and read from `typologySettingsProvider`. No placeholder data.

## Threat Flags

None — all new values come from fixed dropdown option lists. No freeform text input introduced. T-10-05 disposition (accept) confirmed: Drift parameterized queries used via `writeTypologyKey`.

## Self-Check: PASSED

- [x] `lib/features/grammar/data/typology_providers.dart` — contains `headDirection`, `adpositionType`, `adjPlacement`, `genPlacement`, all 4 key constants, updated `readTypologySettings` and `typologySettingsProvider`
- [x] `lib/features/grammar/presentation/typology/typology_page.dart` — contains `Word Order`, `Phrase-level ordering settings`, `Head Directionality`, `Adposition Type`, `Adjective Placement`, `Genitive Placement`, `typology.head_direction`, `Circumposition`
- [x] `test/unit/grammar/typology_providers_test.dart` — contains `head_direction`, `adposition_type`, exits 0
- [x] Commit `63a8c83` exists
