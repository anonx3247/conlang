---
title: "Phase 10.1 UAT gap fixes"
status: pending
priority: P1
source: "explore session 2026-04-14 + UAT feedback"
created: 2026-04-14
theme: grammar
---

## Goal

Close all UAT gaps identified during the Phase 10.1 explore session before proceeding to Phase 10.2.

## Context

The explore session on 2026-04-14 produced architectural decisions that supersede some of Phase 10.1's planned implementation (specifically: construction-realized paradigm cells in the grid). These gaps need to be closed as part of 10.1.

## Acceptance Criteria

- [ ] **Unified rule editor dialog** — clicking a paradigm cell shows a 3-way selector: `Unmarked` / `Inflection` / `Construction`, instead of jumping straight to the inflection edit dialog. Choosing "Construction" opens the construction rule editor.
- [ ] **Transformations tab** — rename "Inflections" tab to "Transformations". Remove the standalone "Constructions" tab. Construction rules are accessible via word detail view only.
- [ ] **Constructions in word detail panel** — constructions panel appears in the word detail view alongside the derivations section. The paradigm grid does NOT show construction-filled cells (no ParadigmConstructionFilled in grid).
- [ ] **Lexicon parent selector** — the "parent word" dropdown in the new/edit word dialog is replaced with a searchable dropdown with pill display (instead of listing all words in a flat list).
- [ ] **Description field** — both InflectionRule and ConstructionRule have a `description: String?` free-text field. Surfaced in the rule editor dialog. Shown as a tooltip/detail when clicking a paradigm cell.

## Notes

- The `ParadigmConstructionFilled` cell type from the 10.1 executor output may need to be removed or repurposed if it was wired into the grid. Constructions do NOT appear in grid cells.
- The construction-in-word-detail panel is a new UI surface that needs design + implementation.
