---
status: complete
phase: 03-lexicon
source: [03-VERIFICATION.md]
started: 2026-04-09T20:15:00Z
updated: 2026-04-10T14:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Root word CRUD with reactive list update
expected: Add a root word (IPA, romanization, meaning, POS), verify it appears in the word list. Edit it, verify changes reflect. Delete it, verify it disappears.
result: pass

### 2. Derivation tree live computation (LEX-02)
expected: Create a root word and active morphology rules. Open word detail — derivation tree shows derived forms computed on-the-fly by MorphologyEngine.
result: pass

### 3. Derived-form search bubbling
expected: Search for a substring that only appears in a derived form. The root word should still surface in the filtered list.
result: issue
reported: "nope, maybe because the search is expecting an IPA search and i'm searching a romanized form"
severity: major

### 4. Swadesh coverage and cross-page navigation
expected: Swadesh list shows coverage progress. Click "Add word" on an uncovered concept — navigates to dictionary with meaning pre-filled. After adding, return to Swadesh — concept shows green checkmark.
result: pass

### 5. Thesaurus browser and "Name this concept"
expected: Browse hierarchical category tree, expand/collapse nodes, search filters visible nodes. Click "Name this concept" — navigates to word creation with meaning pre-filled.
result: pass

### 6. Anki export file write and import
expected: Select words via checkboxes, click export. File saves as .apkg. Import into Anki desktop — cards appear with correct fields.
result: pass

### 7. Phonotactic violation rendering and exception toggle
expected: Words violating phonotactic rules show wavy red underline with tooltip in both word list and detail panel. Toggle "Mark as exception" — violation styling disappears, amber label appears.
result: issue
reported: "nope, i can perfectly enter them without anything. Also other problem but when i input a word in romanised form, the IPA form should be determined automatically, the field should be there only for me to overload it (e.g. a abnormal pronunciation, in which case the word should be highlighted at all times with a certain color indicating this)."
severity: major

## Summary

total: 7
passed: 5
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Search for a substring that only appears in a derived form. The root word should still surface in the filtered list."
  status: failed
  reason: "User reported: nope, maybe because the search is expecting an IPA search and i'm searching a romanized form"
  severity: major
  test: 3
  artifacts: []
  missing: []

- truth: "Words violating phonotactic rules show wavy red underline with tooltip in both word list and detail panel."
  status: failed
  reason: "User reported: nope, i can perfectly enter them without anything. — Phonotactic violation styling is not rendered on existing lexicon words (word list + detail panel). User can create and save words that contain forbidden sequences with zero visual feedback."
  severity: major
  test: 7
  artifacts: []
  missing: []

- truth: "Toggle 'Mark as exception' removes violation styling and shows amber 'exception' label."
  status: failed
  reason: "Not reachable — since violations are never flagged on lexicon words in the first place (see gap above), the exception toggle cannot be exercised. Both behaviors need the violation detection pipeline to run on saved words."
  severity: major
  test: 7
  artifacts: []
  missing: []

- truth: "Entering a romanized form auto-derives the IPA via configured romanization rules; the IPA field is only for manual override. Words with manually overridden IPA are visually flagged (distinct color) to indicate non-standard pronunciation."
  status: failed
  reason: "User reported: when i input a word in romanised form, the IPA form should be determined automatically, the field should be there only for me to overload it (e.g. a abnormal pronunciation, in which case the word should be highlighted at all times with a certain color indicating this) — Currently both fields are independently edited with no auto-derivation."
  severity: major
  test: 7
  artifacts: []
  missing: []
