---
status: diagnosed
phase: 01-foundation
source: 01-08-SUMMARY.md, 01-09-SUMMARY.md
started: 2026-04-08T22:00:00Z
updated: 2026-04-08T22:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. IPA Keyboard Popup Stays Open
expected: Focus any IPA text field (e.g. in romanization edit row). The IPA keyboard popup appears. Click a symbol button inside the popup — the symbol inserts at the cursor AND the popup stays open. Click outside the popup or press Escape — popup dismisses.
result: issue
reported: "the popup appears but still clicking anywhere in it just closes it"
severity: blocker

### 2. IPA Chart Renders Without Overflow
expected: Open a project. The IPA reference chart panel on the right shows the pulmonic consonant grid without any overflow errors. All columns fit cleanly within the panel. No "RIGHT OVERFLOWED BY X PIXELS" debug banners.
result: pass

### 3. Template Editor Save and Validation
expected: Go to Sound Rules > Templates. Click Add. Enter a pattern like "(C)V(C)" using the keyboard. A green checkmark icon appears next to the field. The Save button is enabled and clickable. No IPA keyboard popup appears on the pattern field. Saving works and the template appears in the list.
result: pass

### 4. Constraint Editor DSL Docs
expected: Go to Sound Rules > Constraints. Click Add or Edit. The help/syntax section shows clear documentation with at least 4 concrete examples (e.g. "[stop][stop] -> forbidden", "VN -> nasalised vowel"). The pattern format "segments -> label" is explained.
result: pass

### 5. Phoneme Dialog — Feature-Driven IPA Symbol
expected: Go to Inventory. Click a phoneme chip (or Add Phoneme). The dialog shows feature dropdowns (manner, place, voicing for consonants OR height, backness, rounding for vowels). There is NO separate IPA symbol text input field. As you select features, a large IPA symbol badge appears showing the derived symbol. If features don't match a known symbol, a "Custom symbol" text field appears as fallback.
result: pass

### 6. Phoneme Dialog — Delete Button
expected: Click an existing phoneme chip to open the edit dialog. A red "Delete" button is visible in the dialog actions (bottom-left). Clicking it shows a confirmation, then deletes the phoneme. Long-pressing the chip no longer triggers delete.
result: pass

### 7. Phoneme Dialog — Romanization Info
expected: Open the edit dialog for a phoneme that has a romanization mapping defined. The dialog shows the Latin representation (e.g. "sh" for /ʃ/) as read-only info. For phonemes without mappings, it shows "No romanization defined" in muted text.
result: pass

### 8. Romanization Section — Latin-First Direction
expected: Go to Inventory > Romanization section. The section title says "Latin letters → IPA sounds" (not "IPA → Latin"). The table header shows "Latin letter" as the first column and "IPA sound" as the second. Each row shows the Latin letter first, then the IPA symbol in monospace. No live preview panel exists.
result: pass

### 9. Romanization Edit — IPA Keyboard on IPA Field
expected: In the Romanization section, click Add or Edit. The first field is "Latin letter" (plain text input, no IPA keyboard). The second field is "IPA sound" with the IPA keyboard popup available for entering IPA symbols.
result: pass

### 10. Word Generator End-to-End
expected: On the Sound Rules page, add at least one template (e.g. "CV" or "(C)V(C)") and have phonemes in inventory. The word generator panel on the right shows ~20 randomly generated words in both IPA and romanized forms. Changing templates or inventory triggers a debounced refresh.
result: pass

## Summary

total: 10
passed: 9
issues: 6
pending: 0
skipped: 0

## Gaps

- truth: "IPA keyboard popup stays open when clicking symbols inside it"
  status: failed
  reason: "User reported: the popup appears but still clicking anywhere in it just closes it"
  severity: blocker
  test: 1
  root_cause: "TextField's internal onTapOutside (from EditableText) was unfocusing the field independently of the outer TapRegion groupId. Fixed by disabling TextField's onTapOutside and adding onTapOutside to the outer TapRegion."
  artifacts:
    - path: "lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart"
      issue: "TextField's built-in onTapOutside bypasses TapRegion groupId grouping"
  missing:
    - "Fix committed (3ef282c) — needs re-test after hot restart"

- truth: "User can type an IPA symbol (e.g. 'b') in phoneme dialog and have features auto-filled (reverse derivation)"
  status: failed
  reason: "User requested: selecting features derives symbol, but typing a symbol should also fill in features"
  severity: major
  test: 5
  root_cause: "Reverse lookup not implemented — only forward derivation (features → symbol) exists"
  artifacts:
    - path: "lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart"
      issue: "No reverse mapping from IPA symbol to features"
  missing:
    - "Add IPA symbol text input that reverse-derives features from IpaSound data"

- truth: "Phoneme ↔ romanization stay in sync: adding a romanization auto-creates the phoneme and vice versa; romanization is a project-wide toggle"
  status: failed
  reason: "User requested: romanization and phoneme inventory should be bidirectionally synced, romanization is project-wide on/off"
  severity: major
  test: 8
  root_cause: "Phoneme and romanization are independent tables with no sync logic"
  artifacts:
    - path: "lib/features/phonology/presentation/inventory/romanization_section.dart"
      issue: "No auto-creation of phoneme when romanization added"
    - path: "lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart"
      issue: "No auto-creation of romanization when phoneme added"
  missing:
    - "Bidirectional sync between phonemes and romanization mappings"
    - "Project-wide romanization enabled/disabled toggle"

- truth: "Single 'Add Phoneme' button with consonant/vowel type dropdown inside the dialog"
  status: failed
  reason: "User requested: consonant/vowel should be a dropdown in dialog, not separate add buttons for each section"
  severity: major
  test: 5
  root_cause: "Inventory page has separate add buttons for consonants and vowels sections"
  artifacts:
    - path: "lib/features/phonology/presentation/inventory/inventory_page.dart"
      issue: "Separate add buttons per section instead of unified add"
  missing:
    - "Single Add Phoneme button with type selection in dialog"

- truth: "Phonological rewrite rules (A → B / C_D) can be defined on the Sound Rules page"
  status: failed
  reason: "User requested: want to define sound change rules like a[stop] -> e[stop], not just phonotactic constraints"
  severity: major
  test: 4
  root_cause: "Constraint system only supports labeling (allowed/forbidden), not transformational rules"
  artifacts:
    - path: "lib/features/phonology/domain/phonotactic_dsl.dart"
      issue: "DSL only parses LHS pattern + label, no RHS transformation"
  missing:
    - "New rule type: phonological rewrite rules with LHS → RHS transformation"

- truth: "IPA keyboard popup plays audio preview when clicking a symbol"
  status: failed
  reason: "User requested: clicking IPA symbol in keyboard popup should play its sound"
  severity: minor
  test: 9
  root_cause: "IpaKeyboardPopup only inserts symbol text, no audio playback integration"
  artifacts:
    - path: "lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart"
      issue: "No IpaAudioPlayer integration in symbol buttons"
  missing:
    - "Play audio via IpaAudioPlayer when symbol is tapped in keyboard popup"
