---
phase: 09-platform-polish
plan: 02
subsystem: project-data-layer
tags: [project-management, file-format, registry, providers, backward-compat]
dependency_graph:
  requires: []
  provides: [project-filePath-model, registry-file-ops, recent-projects-provider]
  affects: [project-providers, project-registry, project-model]
tech_stack:
  added: []
  patterns: [optional-param-backward-compat, async-family-provider-chain]
key_files:
  created:
    - lib/features/project/data/recent_projects_service.dart
    - lib/features/project/data/recent_projects_service.g.dart
  modified:
    - lib/features/project/domain/project.dart
    - lib/features/project/data/project_registry.dart
    - lib/features/project/data/project_providers.dart
    - lib/features/project/data/project_providers.g.dart
decisions:
  - createProject filePath is optional (defaults to legacy layout) so project_menu.dart keeps compiling until Plan 03 adds native save dialog
  - projectDatabaseProvider watches projectFilePathProvider (async family) for path resolution
  - _resolveDbPath extracted as helper to avoid final variable re-assignment in try/catch
metrics:
  duration_minutes: 25
  completed: "2026-04-13"
  tasks_completed: 2
  files_changed: 6
---

# Phase 9 Plan 02: Project Data Layer — .conlang File Format

Project model and registry overhauled to support user-chosen .conlang file paths with rename, duplicate, and open-from-file operations; providers updated to resolve DB connections from registry; recent projects provider added.

## Tasks Completed

| # | Name | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Refactor Project model + ProjectRegistry | 155c9b3 | project.dart, project_registry.dart |
| 2 | Update providers + RecentProjectsService | edc0168 | project_providers.dart, recent_projects_service.dart |

## What Was Built

**Project model** (`project.dart`):
- Replaced stored `directoryPath` field with `filePath` (absolute path to .conlang file)
- `directoryPath` kept as a computed getter (`path.dirname(filePath)`) for backward compat
- `fromJson` handles legacy registry entries that have `directoryPath` but no `filePath` — derives `filePath` as `{directoryPath}/project.db`

**ProjectRegistry** (`project_registry.dart`):
- `createProject(name, [filePath])` — filePath optional; defaults to legacy `{baseDir}/{id}/project.db` so existing call sites keep compiling
- `openProjectFile(filePath)` — registers an existing .conlang file; returns existing entry if already registered
- `duplicateProject(sourceId, newFilePath)` — copies file on disk, registers copy as new project
- `renameProject(id, newName)` — updates display name in registry only (no file rename per D-10)
- `deleteProject` updated to delete the .conlang file (not a directory)

**Providers** (`project_providers.dart`):
- New `projectFilePathProvider(projectId)` — async family that resolves filePath from registry with legacy fallback
- `projectDatabaseProvider` watches `projectFilePathProvider` instead of constructing path from `{docsDir}/{id}/project.db`
- `CurrentProjectId.open` uses `_resolveDbPath` helper to get filePath from registry for the backup step

**RecentProjectsService** (`recent_projects_service.dart`):
- `recentProjectsProvider` — thin wrapper returning `registry.listProjects().take(10)`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] createProject filePath made optional to preserve existing call sites**
- **Found during:** Task 1
- **Issue:** `project_menu.dart` calls `registry.createProject(name)` with one argument; making filePath required would break compilation before Plan 03 adds the native save dialog
- **Fix:** Made `filePath` an optional positional parameter with a legacy-path fallback
- **Files modified:** project_registry.dart
- **Commit:** 155c9b3

**2. [Rule 1 - Bug] Extracted _resolveDbPath helper to fix final-variable reassignment**
- **Found during:** Task 2
- **Issue:** Dart analyzer rejected assigning to `final String dbPath` in both a try block and a catch block
- **Fix:** Extracted `_resolveDbPath(id)` async helper method; `open()` assigns once from its return value
- **Files modified:** project_providers.dart
- **Commit:** edc0168

## Known Stubs

None — all data flows are wired. The `createProject` legacy fallback is intentional and documented; Plan 03 will update the call site to supply a user-chosen filePath via native save dialog.

## Threat Flags

None — no new network endpoints or trust-boundary changes. File-system path handling follows the threat register dispositions in the plan (all accepted for single-user desktop).

## Self-Check

- [x] `lib/features/project/domain/project.dart` — exists, contains `filePath`
- [x] `lib/features/project/data/project_registry.dart` — exists, contains `openProjectFile`, `duplicateProject`, `renameProject`
- [x] `lib/features/project/data/recent_projects_service.dart` — exists, contains `recentProjects`
- [x] `lib/features/project/data/project_providers.dart` — exists, contains `projectFilePathProvider`
- [x] Commit 155c9b3 — Task 1
- [x] Commit edc0168 — Task 2
- [x] `dart analyze lib/features/project/` — no issues
- [x] `dart run build_runner build` — completed successfully

## Self-Check: PASSED
