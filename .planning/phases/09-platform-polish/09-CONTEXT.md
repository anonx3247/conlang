# Phase 9: Platform Polish - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Move to native macOS menu bar, overhaul project management (rename, save-as, .conlang file format with user-chosen location), fix app name everywhere, add app logo, and create a welcome screen for project discovery.

</domain>

<decisions>
## Implementation Decisions

### macOS Native Menu (PLAT-01)
- D-01: Replace in-app File menu button with PlatformMenuBar widget — File, Edit, View menus appear in macOS global menu bar
- D-02: File menu items: New Project, Open Project..., Open Recent >, Save As..., Rename Project, Close Project, Quit
- D-03: Edit menu: standard Undo/Redo/Cut/Copy/Paste (Flutter defaults)
- D-04: View menu: placeholder for future use (zoom, etc.)
- D-05: Remove the current in-app "File" button from AppShell tab bar entirely

### Project Management (PLAT-02)
- D-06: Projects stored as .conlang files (SQLite DB with custom extension) — user chooses save location via native file picker
- D-07: "New Project" shows native save dialog to pick location and name → creates .conlang file there
- D-08: "Open Project" shows native file picker filtered to .conlang files
- D-09: "Save As..." duplicates current project to a new .conlang file at user-chosen location
- D-10: "Rename Project" shows a dialog to change the display name (stored in project metadata, not filename)
- D-11: Recent projects list maintained in app preferences (last 10 projects with paths)
- D-12: Welcome screen shown when no project is open — displays recent projects list + Open + Create buttons

### App Identity (PLAT-03)
- D-13: App name "Conlang Workbench" everywhere — macOS menu bar title, window title, about dialog. No underscores.
- D-14: App logo from ~/Downloads/conlang_workbench.svg — convert to required sizes for macOS app icon (16, 32, 64, 128, 256, 512, 1024px)
- D-15: Use logo in welcome screen and about dialog

### Claude's Discretion
- PlatformMenuBar keyboard shortcuts (standard macOS conventions)
- Welcome screen layout details
- Recent projects storage mechanism (SharedPreferences or JSON file)
- SVG to PNG conversion approach for icon sizes

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/project/presentation/project_menu.dart` — current File menu implementation to replace
- `lib/features/project/data/project_registry.dart` — project CRUD operations
- `lib/features/project/data/project_providers.dart` — currentProjectIdProvider
- `lib/shared/widgets/app_shell.dart` — AppShell with tab bar (remove File button)
- `~/Downloads/conlang_workbench.svg` — app logo source file

### Established Patterns
- file_selector package already in pubspec for native file dialogs
- Project databases opened via DriftNativeOptions.databasePath callback
- ConsumerWidget/ConsumerStatefulWidget for all pages

### Integration Points
- AppShell — remove File button, add PlatformMenuBar wrapper
- main.dart — wrap MaterialApp with PlatformMenuBar
- Project registry — update to support .conlang extension and arbitrary paths
- macOS Runner — update app name in Info.plist, replace AppIcon assets

</code_context>

<specifics>
## Specific Ideas

- The welcome screen should feel like a proper app launcher — clean, professional, shows the logo prominently
- .conlang extension should be registered with macOS so double-clicking opens the app (LSHandlerRank in Info.plist)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
