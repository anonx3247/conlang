---
status: complete
phase: 11-lexicon-etymology-chain
source:
  - 11-01-SUMMARY.md
  - 11-02-SUMMARY.md
  - 11-03-SUMMARY.md
started: 2026-04-14T21:00:00Z
updated: 2026-04-15T00:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Searchable Parent Selector in Word Creation Form
expected: Open the "New Word" / word creation form. The parent lexeme field should now be a search text box (not the old wall of filter chips). Typing a partial word filters matching lexemes and shows a dropdown of up to 20 results. Selecting a result adds it as a removable chip below the field. Clicking the × on a chip removes it. Leaving the search field empty shows no dropdown.
result: issue
reported: "works however it shows the non-derived forms instead of the full forms of words"
severity: major

### 2. Etymology Chain Section — Word With Parents
expected: Open the detail panel for a word that has at least one parent. The panel should show an etymology/ancestry tree section with compact pill chips for each ancestor. Ancestors at the same depth appear in a single horizontal row. A connecting line runs from each ancestor chip to the current word. The current word's chip has a primary-colored border. Edge labels (e.g. "via Actor") appear below parent chips when set.
result: pass

### 3. Etymology Chain Section — Children Display
expected: Open the detail panel for a word that has at least one child (another word listing it as a parent). Below the current word in the etymology section there should be a children row showing those derived words as chips, with a fan/bracket connector above them pointing up to the current word.
result: pass

### 4. Inline Parent Management in Word Detail
expected: In the etymology section of a word's detail panel, there should be a searchable parent selector (same autocomplete + chip UI as in word creation). Adding a parent via the selector updates the ancestry tree immediately. Removing a chip removes that parent link.
result: pass

### 5. Multi-Level Promoted Derivation IPA
expected: For a word C that is a promoted derivation of B, which is itself a promoted derivation of A (chain A→B→C with rules R1 and R2): word C's displayed IPA should equal R2(R1(A.ipa)) — the correctly chained result — not R2(A.ipa) (the pre-fix wrong result). Verify by checking C's computed form against what you'd expect from composing both rules.
result: pass

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Autocomplete dropdown shows the full/derived form of each word"
  status: failed
  reason: "User reported: works however it shows the non-derived forms instead of the full forms of words"
  severity: major
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
