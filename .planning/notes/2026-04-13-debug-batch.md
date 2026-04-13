---
captured: 2026-04-13T01:30:00
scope: project
tags: [bug, debug, critical]
---

## Debug Batch — Pre-existing Bugs Found During v1.0 UAT

### Bug 1: Paradigm axis assignment (CRITICAL)
- 3 dimensions: Animacy (intrinsic), Number (sg/pl), Case (nom/gen)
- Expected: stacked by intrinsic (Animate/Inanimate/Abstract tables), each with Number rows × Case columns
- Actual: Number on BOTH row/column axes, Case as separate stacked tables
- Files: paradigm_engine.dart, typology_providers.dart, paradigm_table_widget.dart

### Bug 2: Missing romanization in some paradigm cells
- Some cells show only [phonetics] with no romanization line above
- Example: [vala] showing without "vala" rom line
- Likely: showRom check returns false when rom == phonemic (expected behavior when no rom mapping differs)
- OR: the inflected form generation isn't producing a phonemic value for romanization

### Bug 3: Sound rules not applying to some words
- Rule "ei → ej" exists and is active
- Word "theidin" displays as θeidin (not θejdin)
- The rewrite rule isn't being applied to this word's phonetic form
- Could be: rule ordering, rule parsing issue, or the word's IPA not matching the rule pattern

### Bug 4: Broken glyph in unfilled paradigm cells
- Cells without inflected forms show a broken character (missing glyph icon)
- Should show empty or a dash/placeholder
