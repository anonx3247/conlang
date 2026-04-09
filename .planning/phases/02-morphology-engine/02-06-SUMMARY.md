---
phase: 02-morphology-engine
plan: 06
subsystem: ui
tags: [flutter, morphology, ipa-keyboard, ux-polish]

# Dependency graph
requires:
  - phase: 02-morphology-engine
    provides: rule editor dialog and preview panel widgets (02-03)
  - phase: 01-foundation
    provides: IpaTextField widget with IPA keyboard popup (01-08, 01-10)
provides:
  - Plain-language OpType dropdown labels in rule editor
  - IpaTextField in all IPA-entry fields (affix, ablaut, suppletive, literal conditions)
  - Regenerate button in preview panel header (main and empty state)
affects: [02-morphology-engine, 03-lexicon]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "IpaTextField as drop-in for TextField where IPA input is expected"
    - "Conditional IpaTextField based on condition type (literal vs class-based)"

key-files:
  created: []
  modified:
    - lib/features/morphology/presentation/rules/rule_editor_dialog.dart
    - lib/features/morphology/presentation/rules/preview_panel.dart

key-decisions:
  - "02-06: IpaTextField used conditionally in condition value field — only for endsWithLiteral/startsWithLiteral, not class-based conditions (nasal, stop, V) which take plain text"
  - "02-06: Regenerate button added to _emptyState as well as main preview view — always visible regardless of rule completeness"

patterns-established:
  - "Conditional IpaTextField: use when field content is IPA symbols; use plain TextField when content is class names or numeric"

# Metrics
duration: 2min
completed: 2026-04-09
---

# Phase 2 Plan 06: Rule Editor UX Polish Summary

**Plain-language OpType labels, IpaTextField in all IPA-entry fields, and a regenerate button in the preview panel header**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-09T09:24:47Z
- **Completed:** 2026-04-09T09:26:16Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Renamed all OpType enum labels to plain-language (e.g. "Prefix (add to start)" instead of "Prefix", "Replacement form" instead of "Suppletive")
- Replaced TextField with IpaTextField for all IPA-entry fields: prefix/suffix/infix affix, ablaut from/to, suppletive form, and literal condition value
- Added Icons.refresh regenerate button next to "Preview" heading in both the main table view and all empty-state variants

## Task Commits

1. **Task 1: Jargon clarity + IPA keyboards in rule editor** - `da7071b` (feat)
2. **Task 2: Preview panel monospace font + regenerate button** - `a3505ee` (feat)

## Files Created/Modified
- `lib/features/morphology/presentation/rules/rule_editor_dialog.dart` - Import IpaTextField, rename OpType labels, swap TextField to IpaTextField for IPA fields, conditional IpaTextField in condition row
- `lib/features/morphology/presentation/rules/preview_panel.dart` - Add regenerate IconButton to Preview header in both build() and _emptyState()

## Decisions Made
- IpaTextField used conditionally in condition value field — only for `endsWithLiteral` / `startsWithLiteral`, not class-based conditions (`endsWithClass`, `startsWithClass`) which take plain text class names like "nasal", "stop", "V"
- Regenerate button added to `_emptyState` as well as main preview view so the button is always visible regardless of rule completeness

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- UAT gaps 1, 2, 6, 7 are now closed
- Remaining gap closure plans (05, 07-10) address rule reordering, POS filtering, condition pattern redesign, and preview panel layout

---
*Phase: 02-morphology-engine*
*Completed: 2026-04-09*
