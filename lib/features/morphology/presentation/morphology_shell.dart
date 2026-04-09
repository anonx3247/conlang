import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Morphology sub-shell with a left sidebar for navigation.
///
/// Mirrors the PhonologyShell pattern without the persistent IPA chart panel.
/// Later phases can add more sidebar items (e.g. "Derivation" for word
/// derivation rules).
class MorphologyShell extends StatelessWidget {
  const MorphologyShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _sidebarItems = [
    _SidebarItem(label: 'Rules', icon: Icons.rule, path: '/morphology/rules'),
    _SidebarItem(
      label: 'Parts of Speech',
      icon: Icons.category,
      path: '/morphology/pos',
    ),
  ];

  void _onSidebarTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Left sidebar (~200px wide)
        SizedBox(
          width: 200,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'MORPHOLOGY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...List.generate(_sidebarItems.length, (index) {
                  final item = _sidebarItems[index];
                  final isSelected = navigationShell.currentIndex == index;
                  return _SidebarTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => _onSidebarTap(context, index),
                  );
                }),
              ],
            ),
          ),
        ),

        // Vertical divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),

        // Main content area
        Expanded(
          child: navigationShell,
        ),
      ],
    );
  }
}

class _SidebarItem {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface.withValues(alpha: 0.85),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
