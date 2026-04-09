---
status: partial
phase: 03-lexicon
source: [03-VERIFICATION.md]
started: 2026-04-09T20:15:00Z
updated: 2026-04-09T20:15:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Root word CRUD with reactive list update
expected: Add a root word (IPA, romanization, meaning, POS), verify it appears in the word list. Edit it, verify changes reflect. Delete it, verify it disappears.
result: [pending]

### 2. Derivation tree live computation (LEX-02)
expected: Create a root word and active morphology rules. Open word detail — derivation tree shows derived forms computed on-the-fly by MorphologyEngine.
result: [pending]

### 3. Derived-form search bubbling
expected: Search for a substring that only appears in a derived form. The root word should still surface in the filtered list.
result: [pending]

### 4. Swadesh coverage and cross-page navigation
expected: Swadesh list shows coverage progress. Click "Add word" on an uncovered concept — navigates to dictionary with meaning pre-filled. After adding, return to Swadesh — concept shows green checkmark.
result: [pending]

### 5. Thesaurus browser and "Name this concept"
expected: Browse hierarchical category tree, expand/collapse nodes, search filters visible nodes. Click "Name this concept" — navigates to word creation with meaning pre-filled.
result: [pending]

### 6. Anki export file write and import
expected: Select words via checkboxes, click export. File saves as .apkg. Import into Anki desktop — cards appear with correct fields.
result: [pending]

### 7. Phonotactic violation rendering and exception toggle
expected: Words violating phonotactic rules show wavy red underline with tooltip in both word list and detail panel. Toggle "Mark as exception" — violation styling disappears, amber label appears.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
