import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/glossary/data/glossary_providers.dart';

/// Grammar sub-shell with a left sidebar for navigation.
///
/// Mirrors the LexiconShell pattern exactly: 200px sidebar + VerticalDivider
/// + Expanded content area. Plan 04-13 / D-48 collapsed the sidebar from
/// 4 entries to 3 — `Paradigm Viewer` and `Inflectional Rules` have been
/// merged into the single `Inflections` sub-tab with a stacked paradigm +
/// rules layout. Final sidebar:
///
///  1. POS & Dimensions — POS manager + dimension editor
///  2. Inflections — stacked paradigm (top) + POS-scoped rules (bottom)
///  3. Typology — alignment / word order / modality form
class GrammarShell extends ConsumerWidget {
  const GrammarShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _sidebarItems = [
    _SidebarItem(
      label: 'POS & Dimensions',
      icon: Icons.category_outlined,
      path: '/grammar/pos',
    ),
    _SidebarItem(
      label: 'Inflections',
      icon: Icons.auto_fix_high_outlined,
      path: '/grammar/inflections',
    ),
    _SidebarItem(
      label: 'Typology',
      icon: Icons.language_outlined,
      path: '/grammar/typology',
    ),
  ];

  void _onSidebarTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Left sidebar (200px wide)
        SizedBox(
          width: 200,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Text(
                        'GRAMMAR',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 16),
                        tooltip: 'Glossary: Grammar terms',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          ref
                              .read(glossaryCategoryFilterProvider.notifier)
                              .set('Morphology');
                          ref.read(glossaryOpenProvider.notifier).open();
                        },
                      ),
                    ],
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
            Expanded(
              child: Text(
                item.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface.withValues(alpha: 0.85),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
