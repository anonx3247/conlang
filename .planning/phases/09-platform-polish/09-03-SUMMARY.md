---
phase: 09-platform-polish
plan: 03
subsystem: ui
tags: [flutter, macos, platform-menu-bar, project-management, welcome-screen]

requires:
  - phase: 09-02
    provides: ProjectRegistry with .conlang file paths, recentProjectsProvider, Project.filePath

provides:
  - PlatformMenuBar in app.dart with File (7 items), Edit (4 items), View (placeholder) menus
  - WelcomeScreen widget with logo, app name, New/Open buttons, recent projects list
  - project_actions.dart shared helpers: showNewProjectDialog, showOpenProjectDialog, showSaveAsDialog, openRecentProject
  - AppShell without in-app File button (ProjectMenu removed)
  - assets/logo.png registered in pubspec.yaml

affects: [09-platform-polish, future-phases-using-project-lifecycle]

tech-stack:
  added: []
  patterns:
    - "PlatformMenuBar wraps MaterialApp.router at app root for macOS native menus"
    - "project_actions.dart shared helpers pattern — both menu bar and welcome screen call same functions"
    - "T-09-06 pattern: always File.existsSync() before opening recent project, delete stale registry entry if missing"

key-files:
  created:
    - lib/features/project/presentation/welcome_screen.dart
    - lib/features/project/presentation/project_actions.dart
  modified:
    - lib/app.dart
    - lib/shared/widgets/app_shell.dart
    - pubspec.yaml

key-decisions:
  - "Extracted project action logic into project_actions.dart so both PlatformMenuBar and WelcomeScreen share the same new/open/save-as/open-recent implementations without duplication"
  - "PlatformProvidedMenuItemType does not include cut/copy/paste on Flutter macOS; used PlatformMenuItem with standard keyboard shortcuts instead — macOS routes them to first responder automatically"
  - "_NoProjectEmptyState removed entirely from AppShell in favour of WelcomeScreen"
  - "logo.png fallback to Icons.translate if asset missing (errorBuilder on Image.asset)"

patterns-established:
  - "Pattern: native file dialogs via FileSelectorPlatform.instance — getSaveLocation for new/save-as, openFile for open"
  - "Pattern: all .conlang path handling ensures .conlang extension suffix before registry call"

requirements-completed: [PLAT-01, PLAT-02]

duration: 45min
completed: 2026-04-12
---

# Phase 09 Plan 03: Native Menu Bar & Welcome Screen Summary

**macOS PlatformMenuBar (File/Edit/View) replaces in-app File button; WelcomeScreen with logo and recent-projects list replaces empty state**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-12T00:00:00Z
- **Completed:** 2026-04-12T00:45:00Z
- **Tasks:** 2 of 3 (Task 3 is checkpoint:human-verify — awaiting user approval)
- **Files modified:** 5

## Accomplishments

- PlatformMenuBar at app root with full File menu (New/Open/Open Recent/Save As/Rename/Close), Edit menu (Cut/Copy/Paste/Select All), View placeholder
- WelcomeScreen widget: custom logo, "Conlang Workbench" title, New Project + Open Project action buttons, scrollable recent projects list with relative timestamps
- Shared `project_actions.dart` helpers eliminate duplication between menu bar and welcome screen
- T-09-06 threat mitigated: file existence check before opening recent projects, stale entries auto-removed from registry

## Task Commits

1. **Task 1: PlatformMenuBar + remove in-app File button** - `bb41270` (feat)
2. **Task 2: WelcomeScreen with logo, recent projects, action buttons** - `3a98e24` (feat)
3. **Task 3: Human verification checkpoint** — awaiting

## Files Created/Modified

- `lib/app.dart` — ConlangApp now wraps MaterialApp.router in PlatformMenuBar; delegates all actions to project_actions.dart
- `lib/features/project/presentation/welcome_screen.dart` — New: WelcomeScreen ConsumerWidget
- `lib/features/project/presentation/project_actions.dart` — New: shared showNewProjectDialog, showOpenProjectDialog, showSaveAsDialog, openRecentProject helpers
- `lib/shared/widgets/app_shell.dart` — Removed ProjectMenu, VerticalDivider, _NoProjectEmptyState; uses WelcomeScreen
- `pubspec.yaml` — Added assets/logo.png asset registration

## Decisions Made

- Used `project_actions.dart` shared helpers rather than duplicating file-picker logic in app.dart and welcome_screen.dart
- `PlatformProvidedMenuItemType` lacks cut/copy/paste/selectAll on Flutter macOS — used `PlatformMenuItem` with standard keyboard shortcuts (macOS routes to first responder)
- Kept `_saveAs` and `_renameProject` logic in `project_actions.dart` so the entire project lifecycle API is in one file

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] T-09-06 file existence check in openRecentProject**
- **Found during:** Task 1 (PlatformMenuBar implementation)
- **Issue:** Plan's threat model marks T-09-06 (missing .conlang file in recent list) as `mitigate`; plan text described it but did not spell out the stale-entry deletion
- **Fix:** `openRecentProject` checks `File(filePath).existsSync()` before opening; if missing, shows SnackBar and calls `registry.deleteProject()` + invalidates `recentProjectsProvider`
- **Files modified:** lib/features/project/presentation/project_actions.dart
- **Verification:** Logic present in both PlatformMenuBar path and WelcomeScreen ListTile onTap
- **Committed in:** bb41270 / 3a98e24

**2. [Rule 1 - Bug] PlatformProvidedMenuItemType.cut/copy/paste/selectAll don't exist**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** Plan spec used `PlatformProvidedMenuItemType.cut` etc. which are not valid enum values in Flutter 3.38
- **Fix:** Replaced with `PlatformMenuItem` entries with explicit `SingleActivator` shortcuts (Cmd+X/C/V/A); macOS routes these to the first responder text field automatically
- **Files modified:** lib/app.dart
- **Verification:** `flutter analyze lib/` reports zero errors
- **Committed in:** bb41270

---

**Total deviations:** 2 auto-fixed (1 Rule 2 missing critical, 1 Rule 1 bug)
**Impact on plan:** Both fixes required for security/correctness. No scope creep.

## Issues Encountered

- `XFile.exists()` method does not exist — XFile (from cross_file package) has no `exists()`. Used `dart:io File(path).existsSync()` instead.
- Pre-existing test errors (test/widget_test.dart `MyApp`, glossary_providers_test.dart, marker_dao_test.dart) are unrelated to this plan's changes — left as deferred items.

## Known Stubs

None — all project management flows are wired to real data (ProjectRegistry, FileSelectorPlatform).

## Threat Flags

None — all new surface (native file dialogs, recent projects list) was covered by the plan's threat model (T-09-05, T-09-06, T-09-07).

## Next Phase Readiness

- Task 3 (human verification) awaits user running `flutter run -d macos` and approving the 14-step checklist
- Once approved, phase 09-platform-polish is complete
- No blockers for subsequent phases

## Self-Check

- `lib/app.dart` — exists, contains PlatformMenuBar
- `lib/features/project/presentation/welcome_screen.dart` — exists
- `lib/features/project/presentation/project_actions.dart` — exists
- `lib/shared/widgets/app_shell.dart` — exists, no ProjectMenu reference
- Commits bb41270, 3a98e24 — verified in git log

## Self-Check: PASSED

---
*Phase: 09-platform-polish*
*Completed: 2026-04-12*
