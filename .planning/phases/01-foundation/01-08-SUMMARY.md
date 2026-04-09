---
phase: 01-foundation
plan: "08"
subsystem: ui
tags: [flutter, ipa-keyboard, tap-region, phonotactics, dsl]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: IpaTextField widget, phonotactic DSL, sound rules page from plans 04 and 07
provides:
  - IPA keyboard popup that stays open when clicking symbols (TapRegion groupId fix)
  - Template editor pattern field using plain TextField with visible validation icon
  - IPA chart consonant grid rendering without overflow
  - Constraint editor with clear, example-rich DSL syntax documentation
affects: [01-09, phonology-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TapRegion groupId: share a single Object() between TextField and overlay to keep them in one tap group, preventing premature dismissal"
    - "Preserve caller's suffixIcon in IpaTextField by Row-combining it with the keyboard toggle when both are present"
    - "DSL input fields use plain TextField, not IpaTextField — IPA keyboard is irrelevant for C/V/[]/() pattern syntax"

key-files:
  created: []
  modified:
    - lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart
    - lib/features/phonology/presentation/sound_rules/template_editor.dart
    - lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart
    - lib/features/phonology/presentation/sound_rules/constraint_editor.dart

key-decisions:
  - "01-08: TapRegion groupId (Object()) shared between TextField and overlay popup — clicks inside popup no longer trigger focus loss that collapses the popup before the symbol button onTap fires"
  - "01-08: IpaTextField.build() preserves caller's suffixIcon via Row when showIpaKeyboard=true — validation icons (check/error) are no longer overwritten by the keyboard toggle"
  - "01-08: Template editor pattern field switched to plain TextField — DSL uses C/V/[]/() not IPA symbols; removes unwanted keyboard, reveals validation icon, eliminates stale-error visual from popup overlap"
  - "01-08: _IpaSymbolButton minWidth reduced from 12 to 9 and horizontal padding zeroed — 11-column pulmonic grid fits within 280px panel without RIGHT OVERFLOWED BY 4px errors"

patterns-established:
  - "Shared TapRegion groupId pattern for popup/field pairs that must coexist without mutual dismissal"

# Metrics
duration: 18min
completed: 2026-04-08
---

# Phase 01 Plan 08: UAT Gap Closure — UI Bug Fixes Summary

**TapRegion groupId fix keeps IPA keyboard popup open during symbol selection; template editor and IPA chart overflow both resolved; constraint DSL docs expanded with 4 concrete examples**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-08T00:00:00Z
- **Completed:** 2026-04-08T00:18:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- IPA keyboard popup no longer dismisses when the user clicks a symbol button — the shared TapRegion groupId ensures the popup and TextField are treated as one tap region
- Template editor pattern field now shows the validation checkmark/X icon and the Save button enables correctly — switching from IpaTextField to plain TextField was the targeted fix
- IPA reference chart consonant grid renders without overflow — reducing _IpaSymbolButton minWidth from 12 to 9 gives each button pair 18px, fitting comfortably in the ~20px column budget
- Constraint editor help text replaced with structured, example-rich documentation covering 4 common patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix IPA keyboard popup dismissal and template editor IpaTextField misuse** - `234167a` (fix)
2. **Task 2: Fix IPA chart overflow and improve constraint editor docs** - `9e60a0c` (fix)

**Plan metadata:** _(final docs commit below)_

## Files Created/Modified
- `lib/features/phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart` - Added `_tapGroupId` field; applied to both TextField's TapRegion wrapper and overlay TapRegion; merged suffixIcon with keyboard toggle via Row when both present
- `lib/features/phonology/presentation/sound_rules/template_editor.dart` - Replaced IpaTextField with plain TextField for DSL pattern field; removed ipa_text_field import
- `lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart` - Reduced _IpaSymbolButton minWidth to 9 and zeroed horizontal padding; updated SizedBox placeholder widths to match
- `lib/features/phonology/presentation/sound_rules/constraint_editor.dart` - Replaced terse one-line help with multi-line, example-rich DSL syntax block (4 examples with inline comments)

## Decisions Made
- TapRegion groupId uses `Object()` (not `UniqueKey()`) since it only needs object identity, not widget key semantics
- Removed `onTapOutside` from the overlay TapRegion — groupId membership prevents the overlay from receiving outside-tap callbacks when the TextField is tapped, so the callback was redundant; dismissal is still handled correctly via `_onFocusChanged`
- Did not reduce fontSize below 11 in _IpaSymbolButton — the 9px minimum width with zero padding is sufficient to resolve the overflow without sacrificing readability

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- None. The pre-existing error in `test/widget_test.dart` (`MyApp` class not found) is a stale auto-generated Flutter test file unrelated to this plan; it pre-dated plan execution and was not introduced by these changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- IPA keyboard is now reliable — Plan 09 gap closure work that depends on IpaTextField can proceed
- Template editor save flow is functional end-to-end
- IPA chart is visually clean without overflow errors
- No blockers for Phase 2 (Morphology Engine) from this plan

---
*Phase: 01-foundation*
*Completed: 2026-04-08*
