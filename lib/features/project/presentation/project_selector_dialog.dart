import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_providers.dart';
import '../domain/project.dart';

/// Modal dialog that lists all known projects and lets the user select one.
///
/// Opening a project sets [currentProjectIdProvider] to the project's ID,
/// which causes the [projectDatabase] family provider to open (or return the
/// cached) SQLite connection for that project.
class ProjectSelectorDialog extends StatefulWidget {
  const ProjectSelectorDialog({super.key, required this.ref});

  /// The Riverpod [WidgetRef] from the parent — passed in because dialogs
  /// run in their own widget sub-tree outside the ConsumerWidget hierarchy.
  final WidgetRef ref;

  @override
  State<ProjectSelectorDialog> createState() => _ProjectSelectorDialogState();
}

class _ProjectSelectorDialogState extends State<ProjectSelectorDialog> {
  List<Project>? _projects;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final registry = await widget.ref.read(projectRegistryProvider.future);
      final projects = await registry.listProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load projects: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openProject(Project project) async {
    Navigator.of(context).pop();

    // Switch to the selected project.
    widget.ref.read(currentProjectIdProvider.notifier).open(project.id);

    // Update lastOpened in registry (fire-and-forget; UI updates via provider).
    try {
      final registry = await widget.ref.read(projectRegistryProvider.future);
      await registry.updateLastOpened(project.id);
    } catch (_) {
      // Non-fatal — the project is still open even if the timestamp fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          style: TextStyle(color: colorScheme.error),
        ),
      );
    } else if (_projects == null || _projects!.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use File → New Project to create one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        itemCount: _projects!.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: colorScheme.outlineVariant,
        ),
        itemBuilder: (ctx, index) {
          final project = _projects![index];
          return _ProjectTile(
            project: project,
            onTap: () => _openProject(project),
          );
        },
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 480, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.folder_open, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Open Project',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.outlineVariant),

            // Content
            Flexible(child: body),

            // Footer
            Divider(color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              color: colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last opened: ${_formatDate(project.lastOpenedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
