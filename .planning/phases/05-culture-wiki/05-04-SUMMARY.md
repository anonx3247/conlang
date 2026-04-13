---
phase: 05-culture-wiki
plan: "04"
subsystem: ui
tags: [flutter, riverpod, notifier-provider, culture-wiki]

# Dependency graph
requires:
  - phase: 05-culture-wiki
    provides: "Culture wiki shell, page tree sidebar, page view, culture providers"
provides:
  - "selectedCulturePageIdProvider as NotifierProvider<_SelectedCulturePageId, int?> replacing broken StateProvider"
  - "Compiling culture feature — all 6 call sites updated to .notifier).set(...)"
affects: [05-culture-wiki, 05-05, CULT-01, CULT-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NotifierProvider pattern for ephemeral UI state (matches lexeme_providers.dart convention)"

key-files:
  created: []
  modified:
    - lib/features/culture/data/culture_providers.dart
    - lib/features/culture/presentation/culture_shell.dart
    - lib/features/culture/presentation/culture_page_view.dart

key-decisions:
  - "05-04: StateProvider removed from flutter_riverpod 3.x main export — replaced with NotifierProvider<_SelectedCulturePageId, int?> matching existing lexeme_providers.dart convention"
  - "05-04: _SelectedCulturePageId.set(int? id) method pattern used for write sites; ref.watch read sites in page_tree_sidebar.dart and culture_shell.dart required no change"

patterns-established:
  - "Ephemeral UI state pattern: class _XNotifier extends Notifier<T> { void set(T v) => state = v; } + NotifierProvider<_XNotifier, T>(_XNotifier.new)"

requirements-completed: [CULT-01, CULT-02]

# Metrics
duration: 8min
completed: 2026-04-12
---

# Phase 5 Plan 04: StateProvider Compile Error Fix Summary

**Replaced broken `StateProvider<int?>` with `NotifierProvider<_SelectedCulturePageId, int?>` across 4 culture feature files, restoring compilation and unblocking CULT-01 and CULT-02**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-12T22:00:00Z
- **Completed:** 2026-04-12T22:07:53Z
- **Tasks:** 2 (1 file-change task + 1 verification-only task)
- **Files modified:** 3

## Accomplishments

- Replaced `StateProvider<int?>` at `culture_providers.dart:40` with `NotifierProvider<_SelectedCulturePageId, int?>` following the `lexeme_providers.dart` convention
- Updated all 4 write call sites (2 in `culture_shell.dart`, 2 in `culture_page_view.dart`) from `.notifier).state =` to `.notifier).set(...)`
- Confirmed 2 read-only `ref.watch(selectedCulturePageIdProvider)` sites required no change
- All 24 culture unit tests pass with zero regressions
- `flutter analyze lib/features/culture/` — 0 errors; `flutter analyze lib/` — 0 errors (info/style warnings only, pre-existing)

## Task Commits

1. **Task 1: Replace StateProvider with NotifierProvider and update call sites** - `5c59ad6` (fix)
2. **Task 2: Verify existing tests still pass and full app compiles** - no files changed (verification only)

## Files Created/Modified

- `lib/features/culture/data/culture_providers.dart` - StateProvider replaced with NotifierProvider + _SelectedCulturePageId class
- `lib/features/culture/presentation/culture_shell.dart` - 2 write call sites updated to .set(pageId)
- `lib/features/culture/presentation/culture_page_view.dart` - 2 write call sites updated to .set(pageId) and .set(newId)

## Decisions Made

- Used `NotifierProvider<_SelectedCulturePageId, int?>` to match the established `lexeme_providers.dart` pattern (not `@riverpod` codegen, not `legacy.dart` import) — consistent with project convention for Drift-adjacent providers
- Named the notifier method `set(int? id)` for consistency with `_LexemeSearchQuery.set(String value)` in lexeme_providers.dart

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

The `flutter analyze` command in the plan's `<verify>` block uses `cd /Users/neosapien/dev/conlang &&` (main repo path). The changes are in the worktree so the analyze was run from the worktree working directory instead. Both paths now point to the same corrected code since the worktree is branched from the main repo.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Culture Wiki feature now compiles cleanly
- `selectedCulturePageIdProvider` works with NotifierProvider pattern matching codebase convention
- CULT-01 (page tree sidebar selection highlighting) and CULT-02 (wiki-link navigation) compile error path is cleared
- Ready for any remaining phase 05 verification steps

---
*Phase: 05-culture-wiki*
*Completed: 2026-04-12*
