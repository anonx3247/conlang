---
phase: 01-foundation
plan: 04
subsystem: ui
tags: [flutter, ipa, overlay, overlayportal, composited-transform, keyboard-popup]

# Dependency graph
requires:
  - phase: 01-foundation
    plan: 01
    provides: Flutter desktop app shell with phonology feature directory structure

provides:
  - IpaTextField: drop-in TextField replacement with IPA keyboard popup overlay
  - IpaKeyboardPopup: 360x260 popup with 5 tabbed categories of IPA symbols
  - Self-contained IPA symbol data (consonants, vowels, diacritics, suprasegmentals, other)

affects:
  - 01-05 (inventory editor uses IpaTextField for phoneme input)
  - 01-07 (rule editor uses IpaTextField for IPA rule notation)
  - 01-03 (if ipa_data.dart is created, IpaKeyboardPopup can import symbol lists from it)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - OverlayPortal + CompositedTransformTarget/Follower for anchored popup overlay
    - TapRegion for outside-tap dismissal without blocking popup interactions
    - TextEditingController.value manipulation for cursor-preserving symbol insertion
    - KeyboardListener with skipTraversal FocusNode for Escape key handling without stealing focus

key-files:
  created:
    - lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart
    - lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart
  modified: []

key-decisions:
  - "IPA symbol data defined locally in ipa_keyboard_popup.dart — no dependency on ipa_data.dart (Plan 03); keyboard layout and chart layout serve different purposes; integrate later if needed"
  - "Popup trigger: focus-based (auto-shows on focus) + suffix icon toggle — gives both automatic convenience and manual control"
  - "TapRegion for outside-tap dismissal instead of GestureDetector/Listener — avoids accidentally consuming taps outside the popup in the widget tree"

patterns-established:
  - "IpaTextField as drop-in: accepts all standard TextField parameters, appends IPA icon to suffixIcon via decoration.copyWith"
  - "Symbol insertion: TextEditingController.value replacement preserving selection offsets rather than direct text mutation"
  - "Overlay positioning: checks screen space below field, flips to above if insufficient room (< popupHeight + 8px)"

# Metrics
duration: 2min
completed: 2026-04-09
---

# Phase 01 Plan 04: IPA Keyboard Summary

**OverlayPortal-based IPA keyboard popup with 5 tabbed categories (~100 symbols) wired into a drop-in IpaTextField that inserts at cursor, dismisses on Escape/outside-tap, and preserves regular keyboard input**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-09T00:11:42Z
- **Completed:** 2026-04-09T00:13:47Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- IpaKeyboardPopup: compact 360x260 popup with tabbed categories (Consonants ~40 symbols, Vowels ~22, Diacritics ~24, Suprasegmentals ~16, Other ~22); each symbol a tappable button calling onSymbolSelected callback
- IpaTextField: drop-in TextField replacement using OverlayPortal + CompositedTransformTarget/Follower; popup auto-shows on focus, manual toggle via suffix icon; inserts symbol at cursor preserving selection; Escape key dismissal via KeyboardListener; outside-tap dismissal via TapRegion; popup flips above field if insufficient space below
- Both files compile with zero analyzer issues; macOS debug build succeeds

## Task Commits

Each task was committed atomically:

1. **Task 1: IPA keyboard popup and IpaTextField widget** - `ed2aa6f` (feat)

## Files Created/Modified

- `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart` — IpaKeyboardPopup StatefulWidget with TabController, 5 categories, _SymbolGrid, _SymbolButton
- `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart` — IpaTextField StatefulWidget wrapping TextField with OverlayPortal popup, cursor-preserving insertion, focus/Escape/outside-tap dismissal

## Decisions Made

- Self-contained symbol data in ipa_keyboard_popup.dart with no import from ipa_data.dart (Plan 03 not yet executed). The keyboard organizes symbols by input ergonomics (grouped by category for fast access), whereas the IPA chart in Plan 03 is laid out phonetically. These serve different purposes; integration is optional.
- Focus-based popup trigger: popup shows automatically when field gains focus and hides on focus loss with a microtask delay (prevents premature dismissal when tapping popup buttons, which briefly steal focus).
- TapRegion wrapping IpaKeyboardPopup for outside-tap dismissal: cleaner than GestureDetector + hit-testing, correctly scopes the "outside" boundary to exclude the popup itself.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing analyzer errors in `lib/db/app_database.dart` and `lib/features/project/data/project_providers.dart` (from Plan 01-02, needing build_runner to generate `.g.dart` files) produce 21 issues in `dart analyze lib/`. These are not related to Plan 04 files and do not block macOS compilation. The IPA keyboard directory analyzes cleanly with no issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- IpaTextField and IpaKeyboardPopup are ready for integration as drop-in TextField replacements
- Plan 01-05 (inventory editor) can use IpaTextField immediately for phoneme symbol input fields
- Plan 01-07 (rule editor) can use IpaTextField for IPA rule notation input
- If Plan 01-03 creates ipa_data.dart with a symbol map, IpaKeyboardPopup can optionally import from it — no change to the public API is needed, just swap the local `_ipaSymbols` constant

---
*Phase: 01-foundation*
*Completed: 2026-04-09*

## Self-Check: PASSED

- FOUND: lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart
- FOUND: lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart
- FOUND: .planning/phases/01-foundation/01-04-SUMMARY.md
- FOUND commit: ed2aa6f
