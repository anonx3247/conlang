import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_providers.dart';
import '../data/recent_projects_service.dart';

/// Shared project action helpers used by both [WelcomeScreen] buttons and the
/// PlatformMenuBar actions in app.dart.
///
/// These are top-level functions so they can be imported anywhere without
/// carrying widget-level state.

// ---------------------------------------------------------------------------
// New Project — shows native save dialog, creates .conlang file
// ---------------------------------------------------------------------------

Future<void> showNewProjectDialog(
  BuildContext context,
  WidgetRef ref,
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

// ---------------------------------------------------------------------------
// Open Project — shows native file picker, opens existing .conlang file
// ---------------------------------------------------------------------------

Future<void> showOpenProjectDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final file = await FileSelectorPlatform.instance.openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Conlang Project', extensions: ['conlang']),
    ],
  );
  if (file == null) return;

  // T-09-06: validate file exists before opening.
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

// ---------------------------------------------------------------------------
// Save As — duplicates current project to a new user-chosen .conlang path
// ---------------------------------------------------------------------------

Future<void> showSaveAsDialog(
  BuildContext context,
  WidgetRef ref,
  String currentProjectId,
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
    final copy = await registry.duplicateProject(currentProjectId, filePath);
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

// ---------------------------------------------------------------------------
// Open Recent Project — opens a project by known path, validates existence
// ---------------------------------------------------------------------------

Future<void> openRecentProject(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required String projectName,
  required String filePath,
}) async {
  // T-09-06: check file exists before opening; remove stale entry if missing.
  if (!File(filePath).existsSync()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot open "$projectName": file not found at $filePath',
          ),
        ),
      );
    }
    // Remove the stale entry from the registry.
    try {
      final registry = await ref.read(projectRegistryProvider.future);
      await registry.deleteProject(projectId);
      ref.invalidate(recentProjectsProvider);
    } catch (_) {}
    return;
  }

  try {
    final registry = await ref.read(projectRegistryProvider.future);
    await ref.read(currentProjectIdProvider.notifier).open(projectId);
    await registry.updateLastOpened(projectId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open project: $e')),
      );
    }
  }
}
