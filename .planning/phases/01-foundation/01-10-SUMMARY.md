---
phase: 01-foundation
plan: 10
subsystem: ui
tags: [flutter, ipa-keyboard, audio, riverpod, overlay]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: IpaAudioPlayer (plan 03), IpaSound static data (plan 03), IpaTextField/IpaKeyboardPopup (plan 04/08)

provides:
  - IPA keyboard popup that stays open during symbol selection (pointer-down interaction guard)
  - Audio preview on symbol tap via IpaAudioPlayer lookup from IpaSound data

affects:
  - Any future plan using IpaTextField

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Listener onPointerDown/Up/Cancel flag to guard focus-loss hide in overlay widgets
    - ConsumerStatefulWidget for widgets needing Riverpod inside overlays where ProviderScope is inaccessible
    - Audio player passed as constructor param to overlay-rendered widgets

key-files:
  created: []
  modified:
    - lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart
    - lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart

key-decisions:
  - "01-10: _isInteractingWithPopup Listener flag + 100ms delay in _onFocusChanged replaces microtask — eliminates race where focus-loss hide fires before requestFocus() in symbol insertion"
  - "01-10: IpaAudioPlayer passed as constructor param to IpaKeyboardPopup — avoids ProviderScope unavailability in overlay context; IpaTextField (ConsumerStatefulWidget) reads provider"
  - "01-10: _symbolToAudioPath built lazily from IpaSound static lists — single source of truth, no duplicated asset paths in keyboard popup"

patterns-established:
  - "Overlay interaction guard: wrap overlay child in Listener, set boolean flag on onPointerDown, clear on onPointerUp/Cancel, check flag before hiding in focus listener"

# Metrics
duration: 15min
completed: 2026-04-09
---

# Phase 01 Plan 10: IPA Keyboard Popup Fix + Audio Preview Summary

**IPA keyboard popup kept open during symbol selection via Listener-based interaction guard, with audio playback on tap using IpaSound asset lookup**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-09T04:30:00Z
- **Completed:** 2026-04-09T04:46:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fixed IPA keyboard popup dismissal: popup stays open when clicking symbol buttons inside it
- Added `_isInteractingWithPopup` boolean flag (set/cleared by Listener on the overlay) that prevents the focus-loss hide timer from firing during symbol interaction
- Extended focus-loss delay from `Future.microtask()` to `Future.delayed(100ms)` for additional robustness
- Converted `IpaTextField` to `ConsumerStatefulWidget` to access `ipaAudioPlayerProvider`
- `IpaKeyboardPopup` now accepts `IpaAudioPlayer` as a constructor parameter and plays audio on symbol tap
- Built `_symbolToAudioPath` lookup map from `IpaSound.pulmonicConsonants`, `IpaSound.vowels`, and `IpaSound.nonPulmonicConsonants` — symbols without audio insert silently without error

## Task Commits

1. **Task 1 + 2: Fix popup dismissal and add audio preview** - `a6f32bc` (fix)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart` — Added `_isInteractingWithPopup` flag, `Listener` wrapper on overlay, 100ms delay, ConsumerStatefulWidget + audioPlayer read
- `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_keyboard_popup.dart` — Added `audioPlayer` constructor param, `_symbolToAudioPath` lookup, `_onSymbolTapped` plays audio then inserts

## Decisions Made

- Used constructor-param pattern for `IpaAudioPlayer` in `IpaKeyboardPopup` rather than converting it to `ConsumerStatefulWidget` — the popup renders in an OverlayPortal which shares the ProviderScope, but passing as parameter is simpler and more testable
- Used `Listener` (raw pointer events) instead of `GestureDetector` for the interaction guard — pointer events fire earlier than gesture recognition, ensuring the flag is set before any focus change can trigger
- Combined tasks 1 and 2 into a single commit since the audioPlayer parameter threads through both files simultaneously

## Deviations from Plan

None — plan executed exactly as written. The robust fallback approach (Listener pointer-down/up flag) was chosen from the plan's ordered fix list.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- UAT test 1 (IPA Keyboard Popup Stays Open) should now pass — popup interaction guard prevents premature dismissal
- Audio preview on symbol tap is live — confirms sound when selecting phonemes in any IPA text field
- All gap closure plans (10-13) can proceed; this plan addresses the highest-priority UAT failure

---
*Phase: 01-foundation*
*Completed: 2026-04-09*
