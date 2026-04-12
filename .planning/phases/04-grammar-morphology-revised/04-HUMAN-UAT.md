---
status: failed
phase: 04-grammar-morphology-revised
source: [04-VERIFICATION.md]
started: 2026-04-11T00:00:00Z
updated: 2026-04-11T00:00:00Z
---

## Current Test

[all 8 structural tests passed; 19 separate issues recorded as gaps]

## Tests

### 1. POS and dimension creation flow
expected: POS + dimension creation via template picker works end-to-end.
result: passed

### 2. Live tiebreak banner on identical inflectional bindings
expected: Live banner on duplicate specificity.
result: passed

### 3. Paradigm viewer for 3+ dimension POS
expected: TabBar/Dropdown threshold, ViolationText, amber overrides, coverage matrix.
result: passed

### 4. Cell override dialog — auto-derive + reactive render
expected: Auto-derive, amber after save, clear override reverts.
result: passed

### 5. Typology auto-save + reload across app restart
expected: Persisted via project_settings.
result: passed

### 6. Lexicon Derivations sub-tab
expected: 4th sidebar entry, derivational-only editor.
result: passed

### 7. Word detail paradigm embed
expected: Embedded paradigm table below derivation tree.
result: passed

### 8. v7→v8 migration on a real legacy project.db
expected: .v7.bak + silent reclassification + rules under Derivations.
result: passed

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

Separate issues reported by user during UAT. These are current-phase work (per feedback_uat_items_are_requirements.md) and must be closed via `/gsd-plan-phase 04 --gaps`.

### G-01: Paradigm viewer — selected word not persisted
status: failed
area: ui, persistence
The currently selected word in the paradigm viewer doesn't persist across tab switches / app restart. Need per-POS "last selected word" stored in project_settings or similar.

### G-02: Dimension templates render as "-" (broken)
status: failed
area: ui, bug
The dimension template picker shows literal "-" characters instead of dimension/level names. Template payload is not being unpacked correctly — likely a rendering bug in `dimension_template_picker.dart` or the template data itself.

### G-03: "Unmarked / unchanged" cell state without a rule
status: failed
area: semantics, ui
Users need to mark a feature-set combination as producing no form change, without having to create a blank/identity rule. Requires either a tri-state cell (derived / unmarked / override) or an explicit "marker" table. Paradigm viewer should render unmarked cells distinctly from uncovered cells.

### G-04: Paradigm viewer shows IPA, should show romanization
status: failed
area: ui, bug
D-29 says romanization + IPA stacked with romanization primary. Currently IPA appears to be shown as primary (or only form). Bug in `paradigm_table_widget.dart` cell renderer — rom and IPA may be swapped or rom is missing.

### G-05: Inflectional rules should support multiple POS
status: failed
area: schema, semantics
A single rule should be assignable to multiple POS (e.g. a rule that applies to both Noun and Adjective). Currently rules are tied to one POS. Schema already has a legacy `posIds` CSV column (kept-and-ignored per research A9) that can be repurposed, or we switch to a dedicated junction table.

### G-06: Paradigm viewer needs a better name
status: failed
area: ui, naming
The name "Paradigm Viewer" is unclear. Related to G-10 (merge with rules into "Inflections" tab).

### G-07: Clicking a paradigm cell should open new-rule dialog directly
status: failed
area: ui, semantics
Currently clicking a cell opens CellOverrideDialog (rom + IPA editing). User wants:
- Click on empty/uncovered cell → open new inflectional rule dialog with feature bindings pre-filled from the cell's axis position
- Per-word rom + IPA overrides should move to the Lexicon word detail (not paradigm viewer), because those are word-specific exceptions
This removes CellOverrideDialog's current purpose and splits concerns.

### G-08: Phonetic rewrite rules not applied to inflected forms
status: failed
area: pipeline, bug
Phonology rewrite rules are not applied to inflected forms in the paradigm output. The rewrite pipeline apparently stops at the root / derivational output and doesn't re-run after inflectional rule application. Separate from pitfall #9 (kind filter) — this is a pipeline ordering bug.

### G-09: Group inflectional rules by POS in list
status: failed
area: ui
The rules page should group rules by POS. Multi-POS rules (after G-05) get their own category (e.g. "Noun + Adj").

### G-10: Merge Paradigm Viewer + Rules tabs into "Inflections" tab
status: failed
area: router, ui
The global morphology preview is useless (popup previews are enough). Restructure:
- Delete the global morphology preview
- Grammar tab goes from 4 sub-tabs to 3: **POS & Dimensions**, **Inflections**, **Typology**
- The new **Inflections** tab merges paradigm viewer (top) + rules list (bottom, filterable by POS)
Touches: app_router.dart, grammar_shell.dart, inflectional_rules_page.dart, paradigm_viewer_page.dart.

### G-11: Dimensions can't be renamed
status: failed
area: ui
DimensionEditorPanel missing rename UI. GrammarDao already supports update — just missing the edit affordance.

### G-12: Multiple "Custom" buttons in template picker
status: failed
area: ui, bug
Template picker renders multiple "Custom" entries (one per group). Should render exactly one "Custom" button (or one per group by design — clarify).

### G-13: Derivations applied irrespective of source/target POS
status: failed
area: pipeline, bug
`computedDerivedFormsProvider` filters to `kind='derivational'` (fixed in 04-07) but does NOT filter by input POS. A derivation rule with inputPosId=Noun is currently applied to all words including Verbs. Need POS filter in the provider.

### G-14: Derived words should be assignable a meaning
status: failed
area: schema, ui
Each derived form needs its own gloss / definition. Currently the derived form is just a string. Requires a new `DerivedWordMeanings` table or a column on Lexemes to store per-derivation glosses.

### G-15: POS abbreviation next to derived words
status: failed
area: ui
In the word detail derivation tree, show each derived form's output POS abbreviation next to the form.

### G-16: "+New word" button + root-only-via-derivations toggle
status: failed
area: ui, schema
- Rename "+New root" → "+New word" in the lexicon toolbar
- Add a toggle on Lexemes: "This root only exists through derivations" (no standalone entry in the dictionary)
- Filter the dictionary to hide root-only-via-derivations entries when not drilled into their derivation tree

### G-17: Manual word derivation with parent selection (etymology trees)
status: failed
area: schema, ui
When creating a new word that derives from another without an existing rule, allow selecting "parent" lexemes. Store parent relationships for future etymology tree rendering. Requires a new `LexemeParents` junction table or a `parentLexemeIds` JSON column.

### G-18: Derivation rules — "apply to all words" toggle
status: failed
area: schema, semantics
Add a `autoApply: bool` column to MorphologicalRules (or `applyToAll`). When true, the rule creates derived forms for every matching-POS word by default. When false, the rule is only a suggestion (see G-19).

### G-19: Non-auto derivations shown as suggestions in word UI
status: failed
area: ui
In the word detail panel, show all applicable non-auto derivational rules as clickable "suggestion" chips. Clicking creates a new word from that derivation (which the user can then edit / confirm).

## Notes

- All 19 gaps are current-phase work per memory feedback (`UAT feedback is current-phase work`).
- Several gaps cluster together and should be planned as a unit:
  - G-05 + G-09 (multi-POS rules)
  - G-02 + G-11 + G-12 (dimension/template UI bugs)
  - G-04 + G-08 (romanization + rewrite pipeline)
  - G-06 + G-07 + G-10 (Inflections tab restructure — biggest change)
  - G-13 + G-14 + G-15 + G-16 + G-17 + G-18 + G-19 (derivation overhaul)
- G-03 (unmarked cells) is semantically subtle and should be discussed before planning.
- Estimated: 4–6 gap plans, probably schema v9.
