import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Top-level application shell with a horizontal tab bar for major sections.
/// Only the Phonology tab is interactive in Phase 1; other tabs are disabled
/// with a tooltip indicating when they will be available.
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Top tab bar
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
                      // App title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Conlang Workbench',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tab buttons
                      ...List.generate(_tabs.length, (index) {
                        final tab = _tabs[index];
                        final isSelected = navigationShell.currentIndex == index;
                        return _TabButton(
                          tab: tab,
                          isSelected: isSelected,
                          onTap: tab.enabled
                              ? () => navigationShell.goBranch(
                                    index,
                                    initialLocation: index == navigationShell.currentIndex,
                                  )
                              : null,
                        );
                      }),
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
          // Main content
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

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
