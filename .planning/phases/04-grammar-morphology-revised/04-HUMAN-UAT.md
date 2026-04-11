---
status: partial
phase: 04-grammar-morphology-revised
source: [04-VERIFICATION.md]
started: 2026-04-11T00:00:00Z
updated: 2026-04-11T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. POS and dimension creation flow
expected: Open Grammar → POS & Dimensions. Create a POS (e.g. Noun). Add a dimension from the template picker — templates should group by category (tense, aspect, case, number, person, gender, voice, mood, polarity) and render a "Custom" entry in every visible group. Tooltips appear on long-press / hover. After selecting, the dimension is inserted on the selected POS and visible in the editor panel.
result: [pending]

### 2. Live tiebreak banner on identical inflectional bindings
expected: Open Grammar → Inflectional Rules. Create two inflectional rules with the exact same feature bindings (same dimensions + levels) on the same POS. The RuleEditorDialog (or the rules page list) should show a live tiebreak banner / warning explaining the duplicate specificity conflict — the banner should update the instant the second rule's chips match the first.
result: [pending]

### 3. Paradigm viewer for 3+ dimension POS
expected: Open Grammar → Paradigm Viewer. Pick a POS with 3+ dimensions (e.g. tense × aspect × person). Verify:
- Affordance: ≤6 slices → TabBar; ≥7 slices → Dropdown (D-25)
- Per-cell romanization + IPA stacked (D-29)
- ViolationText highlight on any cell whose derived form breaks phonotactics (D-30)
- Amber override rendering when a cell has been overridden (D-28)
- Coverage matrix side panel shows green/red dots per (dimension, level) pair
result: [pending]

### 4. Cell override dialog — auto-derive + reactive render
expected: In the paradigm viewer, tap a cell. CellOverrideDialog opens with current romanization + IPA pre-filled (auto-derived if no override exists). Edit the IPA, save — the cell immediately switches to amber override rendering. Re-open the dialog, tap "Clear override" — the cell reverts to the auto-derived form.
result: [pending]

### 5. Typology auto-save + reload across app restart
expected: Open Grammar → Typology. Change word order, morphological type, alignment, and head-marking fields. Close and reopen the app — the saved typology values should reappear exactly as entered (persisted via project_settings).
result: [pending]

### 6. Lexicon Derivations sub-tab
expected: Open Lexicon. The sidebar should have a 4th entry: "Derivations". Click it — `/lexicon/derivations` route loads, showing only rules with `kind='derivational'`. Create a derivational rule (Input POS dropdown + Output POS dropdown, no feature binding chip picker).
result: [pending]

### 7. Word detail paradigm embed
expected: Open Lexicon → pick any word whose POS has ≥1 dimension. Word detail panel should show the paradigm table embedded below the derivation tree (WordDetailParadigmSection). The embedded table should match what Grammar → Paradigm Viewer shows for the same word.
result: [pending]

### 8. v7→v8 migration on a real legacy project.db
expected: Open a project that was created before this phase (or restore one from a backup). Migration should:
- Create `project.db.v7.bak` alongside `project.db` (file-level safety backup)
- Silently reclassify all existing morphological rules to `kind='derivational'`
- Existing rules should now appear only under Lexicon → Derivations (not Grammar → Inflectional Rules)
- Schema version should be 8 after open
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
