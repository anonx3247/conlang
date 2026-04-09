---
phase: 01-foundation
plan: "09"
subsystem: ui
tags: [flutter, phoneme-dialog, romanization, ipa, ux]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: IpaTextField widget, romanizationMappingsProvider, IpaSound data from plans 04, 03, 06
provides:
  - Phoneme edit dialog with feature-derived IPA symbol display (no redundant text input)
  - Phoneme edit dialog Delete button visible when editing
  - Phoneme edit dialog showing existing romanization mapping info
  - Romanization section with Latin-first column order and no preview panel
affects: [phonology-ui, inventory-page, romanization-ux]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "IPA symbol derivation from features via IpaSound.pulmonicConsonants/vowels lookup — no manual symbol entry for known combinations"
    - "Feature-complete + unknown-combination guard shows Custom symbol TextField fallback"
    - "_RomanizationInfo reads romanizationMappingsProvider inline in dialog for cross-feature info display"
    - "Latin-first table: latinMapping displayed first (normal font), ipaSymbol second (monospace + primary)"

key-files:
  created: []
  modified:
    - lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart
    - lib/features/phonology/presentation/inventory/inventory_page.dart
    - lib/features/phonology/presentation/inventory/romanization_section.dart

key-decisions:
  - "01-09: IPA symbol derived from IpaSound static data (pulmonicConsonants + vowels + nonPulmonicConsonants) by matching manner/place/voiced for consonants and height/backness/rounded for vowels"
  - "01-09: Custom symbol TextField appears only when all dropdowns selected but combo not found — avoids cluttering common case while handling rare sounds"
  - "01-09: Romanization info in phoneme dialog reads romanizationMappingsProvider (StreamProvider) — no DB schema change needed, info is read-only and cross-references existing mapping table"
  - "01-09: Delete button added to phoneme dialog actions (error-colored TextButton) — replaces hidden long-press on chip; uses existing confirmDeletePhoneme + pops dialog after deletion"
  - "01-09: IpaTextField kept for IPA sound input in romanization edit row — user still needs keyboard to enter IPA; only the Latin letter column uses plain TextField"

patterns-established:
  - "Feature-derived symbol display pattern: dropdowns determine the value, read-only badge shows result, fallback field appears only for edge cases"

# Metrics
duration: 4min
completed: 2026-04-09
---

# Phase 01 Plan 09: Phoneme Dialog Redesign and Romanization Section Flip Summary

**Feature-derived IPA symbol replaces redundant text input in phoneme dialog; romanization table flipped to Latin-first direction and preview panel removed**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-09T03:38:53Z
- **Completed:** 2026-04-09T03:42:50Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Phoneme edit dialog no longer has a redundant IPA symbol text field — the symbol is derived from feature dropdowns by matching against `IpaSound.pulmonicConsonants`, `IpaSound.vowels`, and `IpaSound.nonPulmonicConsonants`
- Derived symbol shows as a large monospace badge (headlineMedium size) in a surfaceContainerHighest container; placeholder "—" shown until features are selected
- A Custom symbol TextField appears only when all features are selected but the combination is unknown (rare edge case for non-standard sounds)
- Phoneme dialog now shows a compact romanization info row displaying the existing `latinMapping` for the phoneme's IPA symbol, queried from `romanizationMappingsProvider`; shows "No romanization defined" in muted italic when absent
- Delete button added to dialog actions (left-aligned, error color) when `_isEditing`; calls `confirmDeletePhoneme` then pops the dialog
- `_PhonemeChip.onLongPress` removed from `inventory_page.dart` — delete is now discoverable via the dialog, not hidden behind long-press
- Romanization section section title updated to 'Romanization (Latin letters → IPA sounds)' matching user mental model
- Table header flipped: 'Latin letter' first (160px), 'IPA sound (default)' second (expanded)
- Display rows now show `latinMapping` first in normal font, `ipaSymbol` second in monospace+primary
- Edit row: plain TextField for Latin letter (first), IpaTextField with IPA keyboard for IPA sound (second)
- `_buildPreviewPanel`, `_applyPreview`, and `_previewController` fully removed
- Empty state and "Add" button text updated to reflect Latin-first workflow

## Task Commits

Each task was committed atomically:

1. **Task 1: Redesign phoneme edit dialog** - `72b7ac3` (feat)
2. **Task 2: Flip romanization section to Latin-first, remove preview panel** - `29cc020` (feat)

## Files Created/Modified

- `lib/features/phonology/presentation/inventory/phoneme_edit_dialog.dart` - Removed IpaTextField import; added feature→symbol derivation via `_deriveConsonantSymbol`/`_deriveVowelSymbol` using IpaSound data; added IPA badge display; added custom symbol fallback TextField; added `_RomanizationInfo` widget; added Delete button in actions; added `_confirmAndDelete` method
- `lib/features/phonology/presentation/inventory/inventory_page.dart` - Removed `onLongPress` parameter from `_PhonemeChip` constructor and usage; fixed pre-existing `unnecessary_underscores` lint in `asyncAll.when` error callback
- `lib/features/phonology/presentation/inventory/romanization_section.dart` - Flipped column order (Latin first); updated all header/label text; swapped field positions in `_buildMappingRow` and `_buildEditRow`; replaced plain TextField with IpaTextField for IPA field in edit row; removed `_buildPreviewPanel`, `_applyPreview`, `_previewController`; updated empty state and button text

## Decisions Made

- Used `IpaSound` static data for derivation rather than building a separate map — single source of truth, automatically covers all 85+ consonants and 28+ vowels
- `_featuresComplete` getter guards the custom symbol fallback — prevents showing the fallback field prematurely when user is mid-selection
- `_RomanizationInfo` is a separate `ConsumerWidget` (not inline in the dialog state) — cleaner separation, lets it rebuild independently when mappings change
- Capture `Navigator.of(context)` before async gap in `_confirmAndDelete` to satisfy `use_build_context_synchronously` lint

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added IpaTextField for IPA sound field in romanization edit row**

- **Found during:** Task 2 implementation
- **Issue:** The plan specified "IpaTextField" for the IPA sound input in the edit row (Task 2, item 4) but the original code used a plain TextField for this field. Since the IPA keyboard is critical for entering IPA symbols correctly, we ensured IpaTextField is used.
- **Fix:** Used `IpaTextField` for the IPA sound column in `_buildEditRow`, plain `TextField` for the Latin letter column
- **Files modified:** `romanization_section.dart`
- **Commit:** `29cc020`

**2. [Rule 1 - Bug] Fixed use_build_context_synchronously in _confirmAndDelete**

- **Found during:** Task 1 — flutter analyze
- **Issue:** `Navigator.of(context).pop()` after `await confirmDeletePhoneme(...)` triggered lint warning for async context use
- **Fix:** Captured `final navigator = Navigator.of(context)` before the async gap
- **Files modified:** `phoneme_edit_dialog.dart`
- **Commit:** `72b7ac3`

## Issues Encountered

- The pre-existing error in `test/widget_test.dart` (`MyApp` class not found) continues to appear in `flutter analyze` output — it predates this plan and is the stale auto-generated Flutter counter test, unrelated to our changes (confirmed present in `a6b9f33` baseline)

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 1 UAT gap closure complete: all 9 plans executed
- Phoneme inventory UI is now fully functional with discoverable delete and feature-driven IPA symbol
- Romanization UI matches the user's mental model (Latin-first)
- No blockers for Phase 2 (Morphology Engine)

---
*Phase: 01-foundation*
*Completed: 2026-04-09*
