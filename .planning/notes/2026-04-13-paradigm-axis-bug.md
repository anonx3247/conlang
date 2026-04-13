---
captured: 2026-04-13T01:15:00
scope: project
tags: [bug, paradigm, grammar, critical]
---

## Paradigm Axis Assignment Bug

**Symptoms:** With 3 dimensions (Animacy intrinsic, Number sg/pl, Case nom/gen), the paradigm viewer shows:
- Number (sg/pl) on BOTH row and column axes
- Case (nom/gen) as separate stacked tables

**Expected:** 
- One table per intrinsic level (Animate, Inanimate, Abstract)
- Each table: Number as rows × Case as columns (the two non-intrinsic dimensions)

**Root cause:** The paradigm axis provider or slice builder is incorrectly assigning dimensions to axes. The intrinsic dimension should control stacking, and the remaining non-intrinsic dimensions should be assigned to row/column axes. Instead it appears to be duplicating one dimension on both axes.

**Files to investigate:**
- `lib/features/grammar/domain/paradigm_engine.dart` — axis assignment logic
- `lib/features/grammar/data/typology_providers.dart` — paradigm axes provider
- `lib/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart` — stacked slice rendering

**Priority:** HIGH — this is a core grammar feature that produces incorrect paradigm tables.
