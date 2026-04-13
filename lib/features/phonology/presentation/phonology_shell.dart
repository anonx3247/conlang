import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/glossary/data/glossary_providers.dart';
import '../../../shared/widgets/resizable_divider.dart';
import 'shared/ipa_chart/ipa_chart_panel.dart';

/// Phonology sub-shell with a left sidebar for navigation
/// and a persistent IPA reference chart placeholder on the right.
class PhonologyShell extends ConsumerStatefulWidget {
  const PhonologyShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<PhonologyShell> createState() => _PhonologyShellState();
}

class _PhonologyShellState extends ConsumerState<PhonologyShell> {
  double _sidebarWidth = 200;
  double _ipaChartWidth = 360;

  static const _sidebarItems = [
    _SidebarItem(label: 'Inventory', icon: Icons.grid_on, path: '/phonology/inventory'),
    _SidebarItem(label: 'Natural Classes', icon: Icons.category, path: '/phonology/natural-classes'),
    _SidebarItem(label: 'Sound Rules', icon: Icons.rule, path: '/phonology/sound-rules'),
  ];

  void _onSidebarTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Left sidebar (resizable)
        SizedBox(
          width: _sidebarWidth,
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
                        'PHONOLOGY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 16),
                        tooltip: 'Glossary: Phonology terms',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          ref
                              .read(glossaryCategoryFilterProvider.notifier)
                              .set('Phonology');
                          ref.read(glossaryOpenProvider.notifier).open();
                        },
                      ),
                    ],
                  ),
                ),
                ...List.generate(_sidebarItems.length, (index) {
                  final item = _sidebarItems[index];
                  final isSelected = widget.navigationShell.currentIndex == index;
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

        // Draggable divider between sidebar and content
        ResizableDivider(
          onDrag: (d) => setState(() {
            _sidebarWidth = (_sidebarWidth + d).clamp(140, 320);
          }),
        ),

        // Main content area
        Expanded(
          child: widget.navigationShell,
        ),

        // Draggable divider before IPA panel
        ResizableDivider(
          onDrag: (d) => setState(() {
            // Right panel: dragging right makes it smaller, left makes it larger.
            _ipaChartWidth = (_ipaChartWidth - d).clamp(280, 600);
          }),
        ),

        // Persistent IPA reference chart — width controlled by _ipaChartWidth.
        SizedBox(width: _ipaChartWidth, child: const IpaChartPanel()),
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
