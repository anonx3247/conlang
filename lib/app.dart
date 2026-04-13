import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/project/data/project_providers.dart';
import 'features/project/data/project_registry.dart';
import 'features/project/data/recent_projects_service.dart';
import 'features/project/domain/project.dart';
import 'router/app_router.dart';

/// Root application widget. Wraps MaterialApp.router in a PlatformMenuBar
/// so macOS global menu bar shows File / Edit / View menus.
class ConlangApp extends ConsumerWidget {
  const ConlangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final currentProjectId = ref.watch(currentProjectIdProvider);
    final recentAsync = ref.watch(recentProjectsProvider);

    final hasProject = currentProjectId != null;

    final recentItems = recentAsync.when(
      data: (projects) => _buildRecentMenuItems(projects, ref, context),
      loading: () => [
        const PlatformMenuItem(label: 'Loading...'),
      ],
      error: (_, _) => [
        const PlatformMenuItem(label: 'No Recent Projects'),
      ],
    );

    return PlatformMenuBar(
      menus: [
        // File menu (D-02)
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Project...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
              onSelected: () => _newProject(ref, context),
            ),
            PlatformMenuItem(
              label: 'Open Project...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: () => _openProject(ref, context),
            ),
            // D-11: Open Recent submenu
            PlatformMenu(
              label: 'Open Recent',
              menus: recentItems.isEmpty
                  ? const [PlatformMenuItem(label: 'No Recent Projects')]
                  : recentItems,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Save As...',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: hasProject
                      ? () => _saveAs(ref, context, currentProjectId)
                      : null,
                ),
                PlatformMenuItem(
                  label: 'Rename Project...',
                  onSelected: hasProject
                      ? () => _renameProject(ref, context, currentProjectId)
                      : null,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Close Project',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyW,
                    meta: true,
                  ),
                  onSelected: hasProject
                      ? () => ref.read(currentProjectIdProvider.notifier).close()
                      : null,
                ),
              ],
            ),
          ],
        ),
        // Edit menu (D-03) — standard macOS text editing commands.
        // PlatformProvidedMenuItemType does not include cut/copy/paste on
        // macOS Flutter; we supply them as PlatformMenuItem with the
        // standard keyboard shortcuts so macOS wires them to the first
        // responder automatically.
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyX,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyC,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyV,
                meta: true,
              ),
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyA,
                meta: true,
              ),
            ),
          ],
        ),
        // View menu (D-04) — placeholder for future display options
        PlatformMenu(
          label: 'View',
          menus: const [],
        ),
      ],
      child: MaterialApp.router(
        title: 'Conlang Workbench',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recent menu items builder
  // ---------------------------------------------------------------------------

  List<PlatformMenuItem> _buildRecentMenuItems(
    List<Project> projects,
    WidgetRef ref,
    BuildContext context,
  ) {
    if (projects.isEmpty) {
      return const [PlatformMenuItem(label: 'No Recent Projects')];
    }
    return projects
        .map(
          (p) => PlatformMenuItem(
            label: p.name,
            onSelected: () => _openRecentProject(ref, context, p),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Menu action helpers
  // ---------------------------------------------------------------------------

  Future<void> _newProject(WidgetRef ref, BuildContext context) async {
    final saveLocation = await FileSelectorPlatform.instance.getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Conlang Project', extensions: ['conlang']),
      ],
      options: const SaveDialogOptions(suggestedName: 'MyLanguage.conlang'),
    );
    if (saveLocation == null) return;

    final filePath = saveLocation.path.endsWith('.conlang')
        ? saveLocation.path
        : '${saveLocation.path}.conlang';

    // Derive project name from filename (strip extension).
    final name = filePath
        .split('/')
        .last
        .replaceAll(RegExp(r'\.conlang$', caseSensitive: false), '');

    try {
      final registry = await ref.read(projectRegistryProvider.future);
      final project = await registry.createProject(
        name.isEmpty ? 'My Language' : name,
        filePath,
      );
      await ref.read(currentProjectIdProvider.notifier).open(project.id);
      await registry.updateLastOpened(project.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create project: $e')),
        );
      }
    }
  }

  Future<void> _openProject(WidgetRef ref, BuildContext context) async {
    final file = await FileSelectorPlatform.instance.openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Conlang Project', extensions: ['conlang']),
      ],
    );
    if (file == null) return;

    // Rule 2: validate file exists before opening (T-09-06)
    if (!File(file.path).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found.')),
        );
      }
      return;
    }

    try {
      final registry = await ref.read(projectRegistryProvider.future);
      final project = await registry.openProjectFile(file.path);
      await ref.read(currentProjectIdProvider.notifier).open(project.id);
      await registry.updateLastOpened(project.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open project: $e')),
        );
      }
    }
  }

  Future<void> _saveAs(
    WidgetRef ref,
    BuildContext context,
    String currentId,
  ) async {
    final saveLocation = await FileSelectorPlatform.instance.getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Conlang Project', extensions: ['conlang']),
      ],
      options: const SaveDialogOptions(suggestedName: 'MyLanguage.conlang'),
    );
    if (saveLocation == null) return;

    final filePath = saveLocation.path.endsWith('.conlang')
        ? saveLocation.path
        : '${saveLocation.path}.conlang';

    try {
      final registry = await ref.read(projectRegistryProvider.future);
      final copy = await registry.duplicateProject(currentId, filePath);
      await ref.read(currentProjectIdProvider.notifier).open(copy.id);
      await registry.updateLastOpened(copy.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save As failed: $e')),
        );
      }
    }
  }

  Future<void> _renameProject(
    WidgetRef ref,
    BuildContext context,
    String currentId,
  ) async {
    // Read current name first.
    final ProjectRegistry registry;
    try {
      registry = await ref.read(projectRegistryProvider.future);
    } catch (_) {
      return;
    }
    final project = await registry.findById(currentId);
    if (project == null) return;
    if (!context.mounted) return;

    final controller = TextEditingController(text: project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newName == null || newName.isEmpty) return;

    try {
      await registry.renameProject(currentId, newName);
      // Invalidate registry so the project name badge refreshes.
      ref.invalidate(projectRegistryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    }
  }

  Future<void> _openRecentProject(
    WidgetRef ref,
    BuildContext context,
    Project project,
  ) async {
    // Rule 2 / T-09-06: check file exists before opening; remove from recent
    // list and show error if missing.
    final fileExists = await _fileExists(project.filePath);
    if (!fileExists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot open "${project.name}": file not found at ${project.filePath}',
            ),
          ),
        );
      }
      // Remove the stale entry from the registry.
      try {
        final registry = await ref.read(projectRegistryProvider.future);
        await registry.deleteProject(project.id);
        ref.invalidate(recentProjectsProvider);
      } catch (_) {}
      return;
    }

    try {
      final registry = await ref.read(projectRegistryProvider.future);
      await ref.read(currentProjectIdProvider.notifier).open(project.id);
      await registry.updateLastOpened(project.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open project: $e')),
        );
      }
    }
  }

  Future<bool> _fileExists(String filePath) async {
    try {
      return File(filePath).existsSync();
    } catch (_) {
      return false;
    }
  }
}

/// Professional dark theme for a desktop linguistic tool.
ThemeData _buildDarkTheme() {
  const seedColor = Color(0xFF5B8DEF); // Professional blue

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'monospace',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 12),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.5),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}

ThemeData _buildLightTheme() {
  const seedColor = Color(0xFF1A56DB);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 12),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0.5),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}
