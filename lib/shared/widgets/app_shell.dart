import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/project/data/project_providers.dart';
import '../../features/project/domain/project.dart';
import '../../features/project/presentation/project_menu.dart';

/// Top-level application shell with a horizontal tab bar for major sections.
///
/// Integrates the File menu (ProjectMenu) for project lifecycle management.
/// When no project is open, the main content area shows an empty state.
/// Only the Phonology tab is interactive in Phase 1; other tabs are disabled
/// with a tooltip indicating when they will be available.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabItem(label: 'Phonology', icon: Icons.music_note, enabled: true, phase: null),
    _TabItem(label: 'Lexicon', icon: Icons.menu_book, enabled: false, phase: 'Phase 3'),
    _TabItem(label: 'Grammar', icon: Icons.account_tree, enabled: false, phase: 'Phase 4'),
    _TabItem(label: 'Culture', icon: Icons.language, enabled: false, phase: 'Phase 5'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch current project to show name in title and toggle content.
    final currentProjectId = ref.watch(currentProjectIdProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Top tab bar (with integrated File menu and project name)
          Material(
            color: colorScheme.surfaceContainer,
            elevation: 0,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),

                      // File menu button
                      const ProjectMenu(),

                      const SizedBox(width: 8),

                      // Separator
                      VerticalDivider(
                        width: 16,
                        thickness: 1,
                        indent: 10,
                        endIndent: 10,
                        color: colorScheme.outlineVariant,
                      ),

                      // Tab buttons (only shown when a project is open)
                      if (currentProjectId != null) ...[
                        ...List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final isSelected = navigationShell.currentIndex == index;
                          return _TabButton(
                            tab: tab,
                            isSelected: isSelected,
                            onTap: tab.enabled
                                ? () => navigationShell.goBranch(
                                      index,
                                      initialLocation:
                                          index == navigationShell.currentIndex,
                                    )
                                : null,
                          );
                        }),
                      ],

                      const Spacer(),

                      // Current project name (right-aligned)
                      if (currentProjectId != null)
                        _ProjectNameBadge(projectId: currentProjectId)
                      else
                        _projectNamePlaceholder(theme, colorScheme),

                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant,
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: currentProjectId != null
                ? navigationShell
                : _NoProjectEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _projectNamePlaceholder(ThemeData theme, ColorScheme colorScheme) {
    return Text(
      'No project open',
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.35),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project name badge (async, reads from registry)
// ---------------------------------------------------------------------------

class _ProjectNameBadge extends ConsumerWidget {
  const _ProjectNameBadge({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final registryAsync = ref.watch(projectRegistryProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.folder, size: 14, color: colorScheme.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        registryAsync.when(
          data: (registry) => FutureBuilder<Project?>(
            future: registry.findById(projectId),
            builder: (_, snap) => Text(
              snap.data?.name ?? projectId,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          loading: () => Text(
            projectId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          error: (_, _) => Text(
            projectId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (no project open)
// ---------------------------------------------------------------------------

class _NoProjectEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 72,
            color: colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 24),
          Text(
            'No project open',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Open or create a project from the File menu',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab item data
// ---------------------------------------------------------------------------

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.phase,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final String? phase; // null if enabled, otherwise "Phase N" string
}

// ---------------------------------------------------------------------------
// Tab button widget
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _TabItem tab;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveColor = tab.enabled
        ? (isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7))
        : colorScheme.onSurface.withValues(alpha: 0.3);

    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: isSelected && tab.enabled
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: effectiveColor,
                fontWeight: isSelected && tab.enabled ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );

    if (!tab.enabled && tab.phase != null) {
      return Tooltip(
        message: 'Coming in ${tab.phase}',
        child: button,
      );
    }

    return button;
  }
}
