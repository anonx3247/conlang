import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_providers.dart';
import 'project_selector_dialog.dart';

/// The "File" menu button that appears in the top app bar.
///
/// Contains actions for managing projects: New, Open, Close, Delete.
/// This widget is integrated into AppShell's menu bar area.
class ProjectMenu extends ConsumerWidget {
  const ProjectMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProjectId = ref.watch(currentProjectIdProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.add, size: 18),
          child: const Text('New Project...'),
          onPressed: () => _showNewProjectDialog(context, ref),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open, size: 18),
          child: const Text('Open Project...'),
          onPressed: () => _showProjectSelector(context, ref),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.close,
            size: 18,
            color: currentProjectId != null
                ? null
                : colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          onPressed: currentProjectId != null
              ? () => ref.read(currentProjectIdProvider.notifier).close()
              : null,
          child: Text(
            'Close Project',
            style: TextStyle(
              color: currentProjectId != null
                  ? null
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.delete_outline,
            size: 18,
            color: currentProjectId != null
                ? colorScheme.error
                : colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          onPressed: currentProjectId != null
              ? () => _showDeleteConfirmation(context, ref, currentProjectId)
              : null,
          child: Text(
            'Delete Project...',
            style: TextStyle(
              color: currentProjectId != null
                  ? colorScheme.error
                  : colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        return TextButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.folder, size: 16),
          label: const Text('File'),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // New project dialog
  // ---------------------------------------------------------------------------

  void _showNewProjectDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _NewProjectDialog(ref: ref),
    );
  }

  // ---------------------------------------------------------------------------
  // Open project dialog
  // ---------------------------------------------------------------------------

  void _showProjectSelector(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProjectSelectorDialog(ref: ref),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation dialog
  // ---------------------------------------------------------------------------

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text(
          'This will permanently delete the project and all its data '
          '(including the SQLite database). This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteProject(ref, projectId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(WidgetRef ref, String projectId) async {
    final registryAsync = ref.read(projectRegistryProvider);
    final registry = await registryAsync.whenOrNull(data: (r) async => r);
    if (registry == null) return;

    // Close the project first (disposes the DB connection).
    ref.read(currentProjectIdProvider.notifier).close();

    // Then delete from disk + registry.
    await registry.deleteProject(projectId);
  }
}

// ---------------------------------------------------------------------------
// New project creation dialog
// ---------------------------------------------------------------------------

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _controller = TextEditingController();
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Project name cannot be empty');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final registryAsync = widget.ref.read(projectRegistryProvider);
      final registry = await registryAsync.when(
        data: (r) async => r,
        loading: () async {
          // Wait for the registry to resolve.
          return widget.ref.read(projectRegistryProvider.future);
        },
        error: (e, _) async => throw Exception('Registry not available'),
      );

      final project = await registry.createProject(name);

      // Open the newly created project. Awaited so Phase 4's pre-open
      // backup step (no-op for brand-new dbs but symmetric with the
      // selector dialog path) completes before the project goes live.
      await widget.ref.read(currentProjectIdProvider.notifier).open(project.id);

      // Update lastOpened in registry.
      await registry.updateLastOpened(project.id);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = 'Failed to create project: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Project name',
              hintText: 'e.g. Elvish, Dothraki, My First Conlang',
              errorText: _error,
            ),
            onSubmitted: (_) => _create(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _create,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
