---
phase: 11-lexicon-etymology-chain
plan: 02
subsystem: ui
tags: [flutter, riverpod, autocomplete, lexicon, etymology]

requires:
  - phase: 04-grammar-morphology-revised
    provides: LexemeParentsDao and _selectedParents Set<int> in word_creation_form.dart

provides:
  - SearchableParentSelector ConsumerStatefulWidget with Autocomplete<Lexeme> and InputChip pills
  - word_creation_form.dart using SearchableParentSelector instead of FilterChip wall

affects:
  - 11-03-etymology-chain-section (reuses SearchableParentSelector in edit mode)

tech-stack:
  added: []
  patterns:
    - "Autocomplete<Lexeme> pattern: optionsBuilder returns empty on empty query, filters client-side allLexemeListProvider, max 20 results (T-11-04 DoS mitigation)"
    - "InputChip for removable pills: onDeleted callback + deleteButtonTooltipMessage (ActionChip does not support onDeleted)"

key-files:
  created:
    - lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart
  modified:
    - lib/features/lexicon/presentation/dictionary/word_creation_form.dart

key-decisions:
  - "Used InputChip instead of ActionChip for pills — ActionChip has no onDeleted API; InputChip is the correct Material widget for chips with delete affordance"
  - "_selectedParents changed from final to non-final Set<int> — required to support SearchableParentSelector.onChanged replacing the set reference"

patterns-established:
  - "SearchableParentSelector.excludeId = -1 for new-word contexts where no ID exists yet"

requirements-completed:
  - LEX-09

duration: 18min
completed: 2026-04-14
---

# Phase 11 Plan 02: SearchableParentSelector Summary

**Searchable autocomplete parent selector with InputChip pills replaces the non-scalable FilterChip wall in the word creation form**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-14T20:15:00Z
- **Completed:** 2026-04-14T20:33:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `SearchableParentSelector` as a self-contained `ConsumerStatefulWidget` with `Autocomplete<Lexeme>` filtering `allLexemeListProvider` client-side
- Replaced the FilterChip wall in `word_creation_form.dart` (lines 514-550) with a single `SearchableParentSelector` invocation
- Empty query shows no dropdown (prevents pill-wall scaling problem); max 20 results cap enforces T-11-04 DoS mitigation
- Selected parents render as removable `InputChip` pills with `deleteButtonTooltipMessage: 'Remove parent link'`
- Widget supports `enabled/disabled` state for future read-only contexts

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SearchableParentSelector widget** - `358b55e` (feat)
2. **Task 2: Replace FilterChip wall in word_creation_form.dart** - `ac683f8` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart` - New `ConsumerStatefulWidget`: Autocomplete search field + removable InputChip pills for parent lexeme selection
- `lib/features/lexicon/presentation/dictionary/word_creation_form.dart` - Replaced Consumer/FilterChip wall with `SearchableParentSelector`; changed `_selectedParents` from `final` to non-final

## Decisions Made

- **InputChip instead of ActionChip for pills:** The plan specified `ActionChip` with `onDeleted`, but `ActionChip` does not expose `onDeleted` in the Flutter Material API. `InputChip` is the correct Material widget for removable chips with a delete button. This is a plan spec error — fixed automatically (Rule 1).
- **_selectedParents made non-final:** `SearchableParentSelector.onChanged` delivers a new `Set<int>` reference. The field must be non-final to support set replacement inside `setState`. Changed with explanatory comment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used InputChip instead of ActionChip for removable pills**
- **Found during:** Task 1 (Create SearchableParentSelector widget)
- **Issue:** Plan spec used `ActionChip(onDeleted: ...)` but `ActionChip` has no `onDeleted` parameter in Flutter Material. `dart analyze` caught the undefined named parameter.
- **Fix:** Used `InputChip` which is the Material widget designed for removable chips with a delete affordance (`onDeleted` + `deleteButtonTooltipMessage`).
- **Files modified:** `lib/features/lexicon/presentation/dictionary/searchable_parent_selector.dart`
- **Verification:** `dart analyze` reports 0 errors
- **Committed in:** `358b55e` (Task 1 commit)

**2. [Rule 1 - Bug] Changed _selectedParents from final to non-final**
- **Found during:** Task 2 (Replace FilterChip wall)
- **Issue:** `_selectedParents` was `final Set<int>` but `SearchableParentSelector.onChanged` provides a replacement set via `setState(() { _selectedParents = ids; })`, which requires the field to be reassignable.
- **Fix:** Changed declaration from `final Set<int>` to `Set<int>` with explanatory comment.
- **Files modified:** `lib/features/lexicon/presentation/dictionary/word_creation_form.dart`
- **Verification:** `dart analyze` reports 0 errors
- **Committed in:** `ac683f8` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 - Bug)
**Impact on plan:** Both fixes necessary for compilation and correct behavior. No scope creep. The functional intent of the plan is fully implemented.

## Issues Encountered

- `flutter test` full suite triggered a transient Dart compiler OOM crash after 530+ tests passed. Not caused by our changes — pre-existing resource issue in the test environment. Static analysis (`dart analyze`) confirms 0 errors in all affected files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `SearchableParentSelector` is ready for reuse in Plan 03 (etymology chain section edit mode)
- `word_creation_form.dart` parent selection is fully functional with the new widget
- No blockers for Plan 03

---
*Phase: 11-lexicon-etymology-chain*
*Completed: 2026-04-14*

## Self-Check: PASSED

- searchable_parent_selector.dart: FOUND
- word_creation_form.dart: FOUND
- 11-02-SUMMARY.md: FOUND
- Commit 358b55e: FOUND
- Commit ac683f8: FOUND
