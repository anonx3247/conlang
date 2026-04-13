import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/glossary/data/glossary_providers.dart';
import '../../../shared/widgets/resizable_divider.dart';

/// Lexicon sub-shell with a left sidebar for navigation.
///
/// Mirrors the GrammarShell pattern: resizable sidebar + ResizableDivider
/// + Expanded content area. Three sidebar items for Dictionary, Swadesh List,
/// and Thesaurus sub-sections (per D-12 in 03-CONTEXT.md).
class LexiconShell extends ConsumerStatefulWidget {
  const LexiconShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<LexiconShell> createState() => _LexiconShellState();
}

class _LexiconShellState extends ConsumerState<LexiconShell> {
  double _sidebarWidth = 200;

  static const _sidebarItems = [
    _SidebarItem(
      label: 'Dictionary',
      icon: Icons.menu_book,
      path: '/lexicon/dictionary',
    ),
    _SidebarItem(
      label: 'Swadesh List',
      icon: Icons.checklist,
      path: '/lexicon/swadesh',
    ),
    _SidebarItem(
      label: 'Thesaurus',
      icon: Icons.category,
      path: '/lexicon/thesaurus',
    ),
    // Phase 4 plan 04-07: 4th sub-tab — derivational rules relocated from
    // the old Morphology tab per D-24 / D-36. Linked route is
    // /lexicon/derivations, backed by DerivationsPage which reuses
    // RulesPage(kind: RuleKind.derivational).
    _SidebarItem(
      label: 'Derivations',
      icon: Icons.transform,
      path: '/lexicon/derivations',
    ),
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
                        'LEXICON',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 16),
                        tooltip: 'Glossary: Lexicon terms',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          ref
                              .read(glossaryCategoryFilterProvider.notifier)
                              .set('Semantics');
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
            // Expanded + ellipsis defensive pattern (matches GrammarShell's
            // _SidebarTile, plan 04-04). Phase 4 plan 04-07 introduced the
            // 4th 'Derivations' entry alongside the existing 'Swadesh List'
            // label. Under the widget-test viewport the 200px sidebar's
            // tile Row is constrained to ~152px, which is not enough for
            // the intrinsic Text width of longer labels → RenderFlex
            // overflow assertions. Wrap in Expanded and ellipsis-clip so
            // the tile always fits its parent regardless of label length.
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface.withValues(alpha: 0.85),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
