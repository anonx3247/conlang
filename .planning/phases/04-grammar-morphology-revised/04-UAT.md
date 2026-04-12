---
status: complete
phase: 04-grammar-morphology-revised
source: [04-HUMAN-UAT.md gaps G-01 through G-19, verified against plans 04-08 through 04-19-03]
started: 2026-04-12T18:00:00Z
updated: 2026-04-12T18:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. G-01 — Paradigm viewer persists selected word
expected: Selected word in paradigm viewer persists across tab switches within the Grammar section.
result: pass

### 2. G-02 — Dimension templates render correctly
expected: When creating a new POS, the dimension template picker shows actual dimension and level names — not literal "-" characters.
result: pass

### 3. G-03 — Unmarked/unchanged cell state (markers)
expected: "Leave as unmarked" checkbox in rule editor, ∅ cells in paradigm, marker rows in rules list, cell-click-to-edit.
result: pass

### 4. G-04 — Paradigm viewer shows romanization primary
expected: Paradigm cells show romanized form as primary display text.
result: pass

### 5. G-05 — Inflectional rules support multiple POS
expected: Rule editor allows assigning a rule to multiple POS; rule appears under each POS group.
result: pass

### 6. G-06 + G-10 — "Inflections" tab (merged paradigm + rules)
expected: Grammar tab has 3 sub-tabs: POS & Dimensions, Inflections, Typology. Paradigm viewer top, rules list bottom.
result: pass

### 7. G-07 — Click empty paradigm cell opens new-rule dialog
expected: Clicking empty cell opens rule editor with POS and dimension bindings pre-filled from cell position.
result: issue
reported: "it does open the dialog but doesn't pre-select the POS / dimensions' levels"
severity: major

### 8. G-08 — Phonetic rewrite rules applied to inflected forms
expected: Inflected forms show post-rewrite phonetic output in bracket notation.
result: pass

### 9. G-09 — Rules grouped by POS in list
expected: Rules list groups by POS with headers; multi-POS rules under combined group.
result: pass

### 10. G-11 — Dimensions can be renamed
expected: Edit icon on dimension level chip opens rename dialog.
result: pass

### 11. G-12 — Template picker shows exactly one "Custom" button
expected: One "Custom" option in template picker, not duplicated per group.
result: pass

### 12. G-13 — Derivations filter by source POS
expected: Derivation rules only apply to words matching input POS.
result: pass

### 13. G-14 — Derived words have their own meaning
expected: Each derived form row has inline meaning/gloss field.
result: pass

### 14. G-15 — POS abbreviation next to derived words
expected: Derived form rows show output POS abbreviation badge.
result: pass

### 15. G-16 — "+New word" button + root-only toggle
expected: Toolbar says "+New word", form has root-only toggle, muted sidebar rendering.
result: pass

### 16. G-17 — Manual word derivation with parent selection
expected: Parent lexeme selection during creation, Parents section with clickable pills in detail.
result: pass

### 17. G-18 — Derivation rules "apply to all words" toggle
expected: Auto-apply checkbox triggers derivation for every matching-POS word automatically.
result: issue
reported: "it works only when i click the apply checkbox, i.e. it doesn't do it automatically for new words"
severity: major

### 18. G-19 — Non-auto derivations shown as suggestion chips
expected: Applicable non-auto rules appear as clickable suggestion chips in word detail.
result: pass

### 19. Marker names persist and display
expected: Custom marker names saved and displayed; binding summaries show level abbreviations.
result: pass

## Summary

total: 19
passed: 17
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Clicking empty paradigm cell pre-fills POS and dimension bindings in the rule editor dialog"
  status: failed
  reason: "User reported: it does open the dialog but doesn't pre-select the POS / dimensions' levels"
  severity: major
  test: 7
  root_cause: ""
  artifacts: []
  missing: []

- truth: "Auto-apply derivation rules automatically trigger when a new matching-POS word is created"
  status: failed
  reason: "User reported: it works only when i click the apply checkbox, i.e. it doesn't do it automatically for new words"
  severity: major
  test: 17
  root_cause: ""
  artifacts: []
  missing: []

## New Gaps (observed during testing)

- truth: "Derivation rule editor allows specifying output intrinsic level when output POS has intrinsic dimensions"
  status: missing
  reason: "User reported: derivation output POS editor doesn't allow specifying output level for intrinsic dimensions (e.g. Gender for Noun)"
  severity: major
  source: test 5 note

- truth: "POS can be deleted with confirmation dialog and word migration picker"
  status: missing
  reason: "User reported: can't delete a POS; needs confirm dialog + migrate words to another POS"
  severity: major
  source: test 8 note

- truth: "Custom dimension template option appears at top of list and prompts for name before adding"
  status: missing
  reason: "User reported: Custom should be at top, clicking should show edit-name dialog instead of creating 'Custom' placeholder"
  severity: minor
  source: test 11 note

- truth: "Derivation rules in rules list show input→output POS labels using abbreviations (e.g. 'v. → n. (Masc.)')"
  status: missing
  reason: "User reported: derivation rules should show source and dest POS with abbreviations"
  severity: minor
  source: test 12 note

- truth: "Clicking a derived word in the derivation tree navigates to that word's detail page"
  status: missing
  reason: "User reported: clicking derived word should navigate to its own page"
  severity: major
  source: test 15 note

- truth: "Derived words (created via rules) show parent pill in their own detail page Parents section"
  status: missing
  reason: "User reported: words created by derivation rules don't show parent pill in their detail page"
  severity: major
  source: test 16 note

- truth: "Search matches derived/promoted forms — searching 'cimoma' returns that derived form"
  status: missing
  reason: "User reported: searching for a derived form name shows nothing in the list"
  severity: major
  source: test 16 note
