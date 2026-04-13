---
phase: 07-polish-refactor
plan: "01"
subsystem: phonology-ui
tags: [phonology, ui, refactor, navigation]
dependency_graph:
  requires: []
  provides: [natural-classes-page, phonology-3-tabs, inline-romanization, rom-primary-chips]
  affects: [phonology_shell, app_router, inventory_page]
tech_stack:
  added: []
  patterns: [StatefulShellBranch, ConsumerWidget, GoRoute]
key_files:
  created:
    - lib/features/phonology/presentation/inventory/natural_classes_page.dart
  modified:
    - lib/features/phonology/presentation/inventory/inventory_page.dart
    - lib/features/phonology/presentation/phonology_shell.dart
    - lib/router/app_router.dart
decisions:
  - Merged Task 1 and Task 2 into a single inventory_page.dart rewrite — both changes target the same file and removing isAltHeld while restructuring content is cleaner in one pass than two sequential edits
  - InventoryPage converted from ConsumerStatefulWidget to ConsumerWidget — state (isAltHeld) no longer needed after alt-key removal
  - RomanizationSection placed below a new "Romanization" titleLarge heading to match the section header style of Consonants/Vowels
metrics:
  duration_minutes: 15
  completed_date: "2026-04-12"
  tasks_completed: 2
  files_changed: 4
---

# Phase 7 Plan 01: Phonology Tab Restructure Summary

Restructured Phonology tab: extracted natural classes to a dedicated page, moved romanization inline below the vowel chart, added a 3-entry sidebar, and replaced the alt-key phoneme display with always-visible romanization-primary chips showing muted /IPA/ when rom differs from IPA.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extract natural classes to own page + restructure tabs | 0b96b8a | natural_classes_page.dart (new), inventory_page.dart, phonology_shell.dart, app_router.dart |
| 2 | Replace alt-key toggle with inline rom+IPA display | 0b96b8a | inventory_page.dart (merged with Task 1) |

## What Was Built

**NaturalClassesPage** (`natural_classes_page.dart`): New dedicated page hosting system class chips (C, V), predefined natural class chips with aliases (stop/S, nasal/N, etc.), and user-defined class CRUD with NaturalClassEditor dialog. Full port of the `_NaturalClassesSection` widget from inventory_page.dart.

**Phonology sidebar** now has 3 entries: Inventory, Natural Classes (Icons.category), Sound Rules. Branch order in app_router.dart matches sidebar index order.

**InventoryPage** restructured: consonant grid → vowel chart → "Romanization" section header → RomanizationSection inline. No natural classes section. Converted from ConsumerStatefulWidget to ConsumerWidget (no state needed).

**_PhonemeChip** updated: always shows romanization as primary text. Shows `/ipa/` in muted style (opacity 0.5, bodySmall) to the right only when `romanized != ipaSymbol`. Uses a Row with MainAxisSize.min.

## Deviations from Plan

### Merged Tasks

**Tasks 1 and 2 merged into a single commit** — both tasks modify `inventory_page.dart`. The alt-key removal (Task 2) and structural reorganization (Task 1) were applied together in a complete file rewrite, which is cleaner than two sequential edits. All acceptance criteria for both tasks verified independently.

### ConsumerStatefulWidget → ConsumerWidget

`InventoryPage` was a `ConsumerStatefulWidget` solely to hold `_isAltHeld` state and the `HardwareKeyboard` handler. After removing all alt-key logic, there is no remaining mutable state, so the class was simplified to `ConsumerWidget`. This is a minor correctness improvement, not a deviation from intent.

## Verification

- `flutter analyze --no-pub lib/` passes with no errors (25 info/warnings, all pre-existing)
- All Task 1 acceptance criteria: PASS
- All Task 2 acceptance criteria: PASS
- No `_isAltHeld`, `HardwareKeyboard`, or `isAltHeld` references remain in inventory_page.dart
- No `import 'package:flutter/services.dart'` remains in inventory_page.dart
- `_NaturalClassesSection` fully removed from inventory_page.dart
- `RomanizationSection` renders inline on inventory page below vowel chart
- Phonology sidebar has exactly 3 items: Inventory, Natural Classes, Sound Rules
- `/phonology/natural-classes` route wired to `NaturalClassesPage`

## Known Stubs

None.

## Threat Flags

None — no new trust boundaries or network endpoints introduced.

## Self-Check: PASSED

- `lib/features/phonology/presentation/inventory/natural_classes_page.dart` — FOUND
- `lib/features/phonology/presentation/inventory/inventory_page.dart` — FOUND
- `lib/features/phonology/presentation/phonology_shell.dart` — FOUND
- `lib/router/app_router.dart` — FOUND
- Commit `0b96b8a` — FOUND
