---
status: resolved
phase: 03-lexicon
source: [03-VERIFICATION.md]
started: 2026-04-09T20:15:00Z
updated: 2026-04-10T15:35:00Z
resolved_in: b41fbbf, f47c70b
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
  status: resolved
  resolution: "filteredLexemeListProvider now applies active morphological rules to each root on-the-fly and bubbles the root into the result list when any computed derivation contains the query substring. Previously only stored derived children were checked — but derivations are computed on-the-fly and never stored, so the derived-match set was always empty."
  fixed_in: b41fbbf
  reason: "User reported: nope, maybe because the search is expecting an IPA search and i'm searching a romanized form"
  severity: major
  test: 3
  artifacts: [lib/features/lexicon/data/lexeme_providers.dart]
  missing: []

- truth: "Words violating phonotactic rules show wavy red underline with tooltip in both word list and detail panel."
  status: resolved
  resolution: "Bracket-offset fix — word_list_panel list and table views were passing `'[${lexeme.ipa}]'` to ViolationText, shifting every underline one character right because violation positions index into the unbracketed word. Brackets are now rendered as sibling TextSpans outside the ViolationText WidgetSpan so offsets line up. Violation detection pipeline itself was already wired via lexemeViolationsProvider + phonotacticValidatorProvider; the highlights simply rendered against wrong character spans and were invisible to the user."
  fixed_in: b41fbbf
  reason: "User reported: nope, i can perfectly enter them without anything."
  severity: major
  test: 7
  artifacts: [lib/features/lexicon/presentation/dictionary/word_list_panel.dart]
  missing: []

- truth: "Toggle 'Mark as exception' removes violation styling and shows amber 'exception' label."
  status: resolved
  resolution: "Reachable now that violation highlights render correctly (see previous gap). The Mark-as-exception and Remove-exception buttons in word_detail_panel were already wired — they were just unreachable because violations never appeared."
  fixed_in: b41fbbf
  reason: "Not reachable — since violations are never flagged on lexicon words in the first place (see gap above), the exception toggle cannot be exercised."
  severity: major
  test: 7
  artifacts: [lib/features/lexicon/presentation/dictionary/word_detail_panel.dart]
  missing: []

- truth: "Entering a romanized form auto-derives the IPA via configured romanization rules; the IPA field is only for manual override. Words with manually overridden IPA are visually flagged (distinct color) to indicate non-standard pronunciation."
  status: resolved
  resolution: "New deromanizeProvider (greedy longest-first inverse of romanizeProvider). Word creation form and word detail panel edit mode now auto-fill the IPA field from the romanization as the user types, gated by an _ipaManuallyEdited flag with a reentrancy guard to prevent listener ping-pong. Manually-overridden IPAs render in orange italic (Colors.orange.shade300) everywhere they appear: word list primary label, table Word column, and detail view IPA heading. The edit-mode IPA field label toggles between `IPA (auto-derived — edit to override)` and `IPA (manual override)`. New helper `isIpaManuallyOverridden(ipa, romanization, deromanize)` encapsulates the divergence check."
  fixed_in: b41fbbf
  reason: "User reported: when i input a word in romanised form, the IPA form should be determined automatically, the field should be there only for me to overload it (e.g. a abnormal pronunciation, in which case the word should be highlighted at all times with a certain color indicating this)"
  severity: major
  test: 7
  artifacts:
    - lib/features/phonology/data/romanization_providers.dart
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart
    - lib/features/lexicon/presentation/dictionary/word_detail_panel.dart
    - lib/features/lexicon/presentation/dictionary/word_list_panel.dart
  missing: []

- truth: "Word list filter row does not overflow in narrow lexicon panel."
  status: resolved
  resolution: "Follow-up fix after initial Flexible wrapping left a residual ~4.7px overflow because Material's OutlinedButton minimumSize (~64dp) ignored the Flexible's narrower allocation. Set minimumSize: Size.zero + tapTargetSize: shrinkWrap + tighter padding on the Export-to-Anki button so it honors its Flexible share."
  fixed_in: b41fbbf, f47c70b
  reason: "Out-of-band report during UAT session — a debug overflow indicator was visible in the word list filter row alongside the three in-scope test-7 issues."
  severity: minor
  test: 7
  artifacts: [lib/features/lexicon/presentation/dictionary/word_list_panel.dart]
  missing: []
