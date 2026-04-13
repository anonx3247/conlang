---
phase: 04-grammar-morphology-revised
plan: 20-03
subsystem: grammar-ui
tags: [pos, delete, migration, dimension-templates, derivation-rules, ux]
dependency_graph:
  requires: []
  provides: [pos-delete-lifecycle, custom-template-name-prompt, derivational-rule-pos-labels]
  affects: [pos_dimensions_page, dimension_template_picker, rules_page]
tech_stack:
  added: []
  patterns: [confirmation-dialog-with-migration, name-prompt-dialog, posById-lookup]
key_files:
  modified:
    - lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart
    - lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart
    - lib/features/morphology/presentation/rules/rules_page.dart
decisions:
  - "POS deletion nulls out morphological_rules inputPosId/outputPosId instead of deleting rules — avoids silent data loss for derivation rules that referenced the deleted POS"
  - "Single top-level Custom entry replaces per-group Custom appending — simpler UX, one clear entry point instead of one per group"
  - "posById map built inline from already-watched posListProvider — no additional provider needed"
metrics:
  duration: 18min
  completed: 2026-04-12T19:05:59Z
  tasks: 3
  files_modified: 3
---

# Phase 4 Plan 20-03: POS Delete + Custom Template + Derivation Labels Summary

Complete POS lifecycle (delete with word migration), improved dimension template picker UX (custom at top with name prompt), and informative derivation rule list (input→output POS abbreviation labels).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | POS delete with confirmation and word migration | d05a032 | pos_dimensions_page.dart |
| 2 | Custom template at top with name prompt | b06eee7 | dimension_template_picker.dart |
| 3 | Show input→output POS labels on derivational rules | 4333c9e | rules_page.dart |

## What Was Built

**Task 1 — POS Delete (New Gap 2):**
- `IconButton(Icons.delete_outline)` added to each POS tile in the left panel
- `_deletePos()` method: queries lexeme count using that POS, shows `_PosDeleteDialog`
- `_PosDeleteDialog`: word migration `DropdownButton` shown when wordCount > 0; simple confirmation dialog when no words use the POS
- On confirmed delete: migrates `lexemes.part_of_speech` text, nulls `morphological_rules.input_pos_id`/`output_pos_id`, calls `morphologyDao.deletePos()` (cascade handles dimensions/markers/inflectional_rule_pos rows)
- Selection reset when deleted POS was the currently selected one

**Task 2 — Custom Template at Top (New Gap 3):**
- Removed per-group Custom blank appending logic
- Single `_customCard` renders at top of ListView (before grouped templates)
- Tapping Custom shows `AlertDialog` with `TextField` for dimension name (hint: "e.g. Evidentiality, Politeness, Animacy")
- Returned `DimensionTemplate` uses user-entered name, not "Custom (start blank)"

**Task 3 — Derivation Rule POS Labels (New Gap 4):**
- `posById` map built from `posListProvider` watch (already watched for filter bar)
- Rule card expanded widget changed to `Column` + `Builder`
- Derivational rules show `'abbr. → abbr.'` secondary text at 11px, 50% opacity
- Inflectional rules unaffected; label hidden when no POS IDs are set

## Decisions Made

1. **POS deletion nulls morphological rules FKs** — `morphological_rules.input_pos_id` and `output_pos_id` are nulled (not deleted) so derivation rules that referenced the deleted POS aren't silently removed. Users can reassign them later.
2. **Single top-level Custom replaces per-group Custom** — cleaner UX; previously each group had a "Custom" entry at the bottom, making it hard to find. Now one prominent entry at top.
3. **`posById` built inline** — the `posListProvider` is already watched on line 85 for the POS filter bar; building `posById` from it adds no overhead and requires no extra provider.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

Files exist:
- `lib/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart` — FOUND
- `lib/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart` — FOUND
- `lib/features/morphology/presentation/rules/rules_page.dart` — FOUND

Commits exist:
- d05a032 — FOUND
- b06eee7 — FOUND
- 4333c9e — FOUND

`flutter analyze` on all three files: no issues.

## Self-Check: PASSED
