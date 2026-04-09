---
status: complete
phase: 01-foundation
source: 01-01-SUMMARY.md, 01-02-SUMMARY.md, 01-03-SUMMARY.md, 01-04-SUMMARY.md, 01-05-SUMMARY.md, 01-06-SUMMARY.md, 01-07-SUMMARY.md
started: 2026-04-08T21:00:00Z
updated: 2026-04-08T21:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Window and Theme
expected: App launches as a desktop window (~1280x800). Dark theme with Material 3 styling. Top tab bar shows "Phonology" as the active tab. Other tabs (Lexicon, Grammar, Culture) are visible but disabled with "Coming in Phase N" tooltips on hover.
result: pass

### 2. Create a New Project
expected: File menu has a "New Project" option. Clicking it opens a dialog where you enter a project name. After creation, the project name appears in a badge in the app bar, and the phonology workspace becomes active.
result: pass

### 3. Open and Switch Projects
expected: File menu has an "Open Project" option. Clicking it shows a list of existing projects with names and last-opened dates. Selecting one switches to that project's data. You can also close the current project, returning to the empty state.
result: pass

### 4. Delete a Project
expected: File menu has a "Delete" option for the current project. Clicking it shows a confirmation dialog. After confirming, the project is removed from the list and its data is gone.
result: pass

### 5. IPA Reference Chart Panel
expected: On the Phonology tab, a persistent panel on the right side (~280px) shows the IPA reference chart. It displays a pulmonic consonant grid (manner x place) and a vowel chart (height x backness). Non-pulmonic consonants and suprasegmentals are also shown.
result: issue
reported: "the chart is there, and clicking works for audio, hovering also does shows the right description however overflows occur in the rendering — column headers overflow with RIGHT OVERFLOWED BY 4.0 PIXELS errors obscuring parts of the consonant grid"
severity: minor

### 6. IPA Audio Playback
expected: Clicking any IPA symbol in the reference chart panel plays an audio recording of that sound. Symbols without recordings appear in a muted/disabled style. No audio overlap when clicking rapidly.
result: pass

### 7. Phonology Sidebar Navigation
expected: Within the Phonology tab, a left sidebar shows "Inventory" and "Sound Rules" navigation items. Clicking each switches the main content area to the corresponding page.
result: pass

### 8. Add a Phoneme to Inventory
expected: On the Inventory page, there's a way to add a new phoneme. A dialog opens where you can enter an IPA symbol (with IPA keyboard popup), select type (consonant/vowel), and set articulation properties (manner, place, voicing for consonants; height, backness, rounding for vowels). After saving, the phoneme appears in the appropriate grid.
result: issue
reported: "IPA keyboard is completely unclickable — clicking anywhere inside it dismisses it instead of inserting symbols. Design issues: selecting manner/place/voicing already determines the IPA symbol so dual input is redundant — should be either IPA symbol OR feature selection. Consonant properties show for vowels and vice versa. Cannot delete a phoneme once added. Cannot set Latin representation for a phoneme."
severity: major

### 9. Consonant Grid and Vowel Chart Display
expected: The Inventory page shows a consonant grid (manner rows x place columns) and a vowel chart (height x backness). Only rows/columns with phonemes are shown (sparse display). Consonant cells show voiceless/voiced pairs; vowel cells show unrounded/rounded pairs.
result: pass

### 10. Natural Class Management
expected: On the Inventory page, there's a section for natural classes. You can create a named class (e.g., "stops"), select phonemes from the inventory using chip multi-select, and save. Classes can be edited and deleted.
result: pass

### 11. IPA Keyboard Popup
expected: Any IPA text field in the app shows a small IPA icon. Focusing the field (or clicking the icon) opens a popup with tabbed categories of IPA symbols (Consonants, Vowels, Diacritics, Suprasegmentals, Other). Tapping a symbol inserts it at the cursor. Pressing Escape or clicking outside dismisses the popup.
result: issue
reported: "keyboard only appears in phoneme dialog, not other IPA fields like romanization. Where it does appear, clicking anywhere in it just closes the keyboard without typing anything — completely unusable"
severity: blocker

### 12. Romanization Mappings
expected: On the Inventory page, there's a romanization section with a two-column table (IPA symbol | Latin). You can add, edit, and delete mappings. A live preview panel lets you type IPA text and see the romanized output update instantly.
result: issue
reported: "it works but mapping direction should be reversed: you write romanisation letters first and associate a main IPA symbol to each, not the other way around. The IPA symbol is just the default sound; Sound Rules tab handles context-dependent sound changes. Also the live preview for IPA is completely useless — remove it."
severity: major

### 13. Define Syllable Templates
expected: On the Sound Rules page, there's a template editor. You can add syllable templates like "(C)V(C)" or "[stop]V". Each template shows a parse status icon (green check if valid, red X with error if not). Templates can be toggled active/inactive, edited, and deleted.
result: issue
reported: "Save button doesn't appear/work for templates. IPA keyboard shows up on template pattern field which shouldn't have IPA input. Syntax checker shows stale errors — stays on last found error even after fixing input, only updates when a new error is found."
severity: blocker

### 14. Define Constraint Rules
expected: On the Sound Rules page, there's a constraint editor. You can add rules like "VN -> nasalised V" or mark patterns as forbidden. Each shows a parse status icon. Constraints can be toggled, edited, and deleted.
result: issue
reported: "Same issues as templates: save button doesn't work, IPA keyboard appears on non-IPA fields, stale error messages. The constraint DSL syntax is unclear and needs better design."
severity: blocker

### 15. Word Generator Live Preview
expected: On the Sound Rules page, a right panel generates ~20 random words from your active templates and phoneme inventory. Words show both IPA and romanized forms. A syllable count range slider adjusts generation. Words violating constraints are highlighted. The preview updates automatically with a slight debounce when you change templates, constraints, or inventory.
result: skipped
reason: Blocked by template save issue (Test 13) — cannot add templates so word generator has no input

## Summary

total: 15
passed: 8
issues: 6
pending: 0
skipped: 1

## Gaps

- truth: "IPA reference chart displays without overflow or rendering artifacts"
  status: failed
  reason: "User reported: column headers overflow with RIGHT OVERFLOWED BY 4.0 PIXELS errors obscuring parts of the consonant grid"
  severity: minor
  test: 5
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Phoneme edit dialog has working IPA keyboard, appropriate type-specific fields, delete capability, and Latin representation field"
  status: failed
  reason: "User reported: IPA keyboard unclickable (dismisses on any click), dual input redundant (features already determine symbol), consonant/vowel properties not scoped to type, no delete, no Latin representation field"
  severity: major
  test: 8
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "IPA keyboard popup works in all IPA text fields and correctly inserts symbols on click"
  status: failed
  reason: "User reported: keyboard only appears in phoneme dialog not other IPA fields, clicking anywhere inside it dismisses it instead of inserting symbols — completely unusable"
  severity: blocker
  test: 11
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Romanization mappings are Latin-first (user defines romanisation letters and associates IPA symbols)"
  status: failed
  reason: "User reported: mapping direction should be reversed — Latin-first not IPA-first. Live preview for IPA is useless, remove it."
  severity: major
  test: 12
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Template editor saves templates, has no IPA keyboard on non-IPA fields, and syntax checker clears errors when input is valid"
  status: failed
  reason: "User reported: Save button doesn't appear/work, IPA keyboard shows on template pattern field, syntax checker shows stale errors after fixing input"
  severity: blocker
  test: 13
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Constraint editor saves constraints, has no IPA keyboard on non-IPA fields, syntax checker clears errors, and DSL syntax is clear"
  status: failed
  reason: "User reported: same issues as templates — save doesn't work, IPA keyboard on non-IPA fields, stale errors, unclear DSL syntax"
  severity: blocker
  test: 14
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
