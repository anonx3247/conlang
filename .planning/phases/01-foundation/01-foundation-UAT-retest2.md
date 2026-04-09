---
status: complete
phase: 01-foundation
source: 01-08-SUMMARY.md, 01-09-SUMMARY.md, 01-10-SUMMARY.md, 01-11-SUMMARY.md, 01-12-SUMMARY.md, 01-13-SUMMARY.md
started: 2026-04-09T12:00:00Z
updated: 2026-04-09T12:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. IPA Keyboard Popup Stays Open
expected: Focus any IPA text field (e.g. IPA field in romanization edit row). The IPA keyboard popup appears. Click a symbol inside the popup — it should insert the symbol into the text field AND the popup should stay open. You can click multiple symbols in sequence without the popup dismissing. Pressing Escape or clicking outside the popup dismisses it.
result: pass

### 2. IPA Keyboard Audio Preview
expected: When clicking a symbol in the IPA keyboard popup, you should hear the audio recording of that sound as it inserts. Symbols without recordings insert silently. Rapid clicks should not cause audio overlap.
result: pass

### 3. IPA Reference Chart Without Overflow
expected: The IPA reference chart panel on the right side shows the full pulmonic consonant grid without any visual overflow or clipping. All column headers and symbol buttons are readable. No "OVERFLOWED BY" error banners.
result: pass

### 4. Phoneme Dialog — Feature-Driven IPA Symbol
expected: Click "Add Phoneme" (single button at top of Inventory page). A dialog opens with a Type dropdown (consonant/vowel). Select a type, then set the feature dropdowns (manner/place/voicing for consonant; height/backness/rounding for vowel). As you complete the features, a large IPA symbol badge appears showing the derived symbol. Only the relevant feature dropdowns for the selected type are shown.
result: pass

### 5. Phoneme Dialog — Reverse IPA Derivation
expected: In the Add Phoneme dialog, there's an "IPA Symbol" text field at the top. Type a known IPA symbol like "b" or "a" — the type dropdown and feature dropdowns should auto-fill to match (e.g. "b" fills consonant, plosive, bilabial, voiced). Unknown symbols are silently ignored (dropdowns stay unchanged).
result: pass

### 6. Phoneme Dialog — Delete Button
expected: Open an existing phoneme by clicking its chip in the inventory grid. The edit dialog shows a Delete button (error/red color) in the bottom-left of the dialog actions. Clicking it shows a confirmation, then removes the phoneme from the inventory.
result: pass

### 7. Romanization — Latin-First Direction
expected: The Romanization section header reads "Latin letters -> IPA sounds" (or similar). The table shows the Latin letter in the first column, IPA sound in the second column (monospace, colored). When adding a new mapping, the first field is for the Latin letter, the second field (with IPA keyboard) is for the IPA sound.
result: pass

### 8. Romanization Toggle
expected: The Romanization section has an Enabled switch in the header. Toggling it off hides the romanization table and Add button, showing a disabled message instead. Toggling it back on restores the table. The toggle state persists when you close and reopen the project.
result: pass

### 9. Romanization — Auto-Create Phoneme
expected: With romanization enabled, add a new romanization mapping for an IPA symbol that is NOT already in your phoneme inventory. After saving the mapping, the phoneme should be automatically created in the inventory. A snackbar confirms the auto-creation.
result: pass

### 10. Phoneme — Romanization Prompt
expected: Add a new phoneme via the dialog. After saving, if romanization is enabled and no mapping exists for that symbol, a follow-up dialog appears asking "Add romanization for /x/?" with a Latin text field and Skip/Add buttons. Clicking Add creates the mapping. Clicking Skip dismisses without creating one.
result: pass

### 11. Template Editor Save and Validation
expected: On the Sound Rules page, add a syllable template like "(C)V(C)". The pattern field shows a green checkmark icon when valid. The Save button works and the template appears in the list. Enter an invalid pattern — a red X icon appears with an error description. The error clears when you fix the input. No IPA keyboard appears on the pattern field.
result: pass

### 12. Forbidden Sequences
expected: On the Sound Rules page, the "Forbidden Sequences" section has clear syntax documentation with examples (e.g. "[stop][stop]", "CC"). You can add a forbidden sequence pattern, see validation, save it, and it appears in the list. No arrow notation needed — just the pattern.
result: pass

### 13. Word Generator
expected: On the Sound Rules page, with at least one active template and some phonemes defined, the right panel shows ~20 randomly generated words. Each word shows both IPA and romanized forms (if romanization is enabled). Words update automatically when you change templates or inventory. Deleting a phoneme should immediately remove it from generated words.
result: pass

### 14. Rewrite Rules — Add and Validate
expected: On the Sound Rules page, there's a "Rewrite Rules" section below Forbidden Sequences. Click Add to open a dialog. Enter a rule in SPE notation like "k -> x / V_V". A green checkmark shows it's valid. Save it — it appears in the list in monospace font. Invalid notation shows a red X with error.
result: pass

### 15. Rewrite Rules — Edit and Delete
expected: Click an existing rewrite rule in the list to edit it. The dialog pre-fills with the current rule text. You can modify and save. There's also a delete option that removes the rule from the list.
result: pass

## Summary

total: 15
passed: 15
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
