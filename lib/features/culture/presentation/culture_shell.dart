import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/culture_providers.dart';
import '../../project/data/project_providers.dart';
import '../domain/page_history.dart';
import 'back_forward_bar.dart';
import 'culture_page_view.dart';
import 'page_tree_sidebar.dart';

/// Top-level shell for the Culture wiki feature.
///
/// Layout: 240px tree sidebar (left) + VerticalDivider + Expanded content area.
/// Mirrors the grammar_shell.dart pattern but uses a dynamic tree for
/// navigation rather than a StatefulNavigationShell with fixed sub-routes.
class CultureShell extends ConsumerStatefulWidget {
  const CultureShell({super.key});

  @override
  ConsumerState<CultureShell> createState() => _CultureShellState();
}

class _CultureShellState extends ConsumerState<CultureShell> {
  late PageHistory _pageHistory;

  @override
  void initState() {
    super.initState();
    _pageHistory = PageHistory();
  }

  @override
  void dispose() {
    _pageHistory.dispose();
    super.dispose();
  }

  void _onPageSelected(int pageId) {
    _pageHistory.push(pageId);
    ref.read(selectedCulturePageIdProvider.notifier).set(pageId);
  }

  Future<void> _createRootPage() async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    final id = await db.cultureDao.createPage(title: 'Untitled');
    _onPageSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedPageId = ref.watch(selectedCulturePageIdProvider);

    return Row(
      children: [
        // Left sidebar (240px)
        SizedBox(
          width: 240,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'CULTURE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Tree sidebar
                Expanded(
                  child: PageTreeSidebar(
                    onPageSelected: _onPageSelected,
                    onCreatePage: ({int? parentId}) async {
                      final db = ref.read(currentDatabaseProvider);
                      if (db == null) return;
                      final maxOrder =
                          await db.cultureDao.maxSiblingOrdering(parentId);
                      final id = await db.cultureDao.createPage(
                        title: 'Untitled',
                        parentId: parentId,
                        ordering: maxOrder + 1,
                      );
                      _onPageSelected(id);
                    },
                  ),
                ),

                // "New page" button at the bottom
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New page'),
                    onPressed: _createRootPage,
                  ),
                ),
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

        // Content area
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back/forward navigation bar
              BackForwardBar(
                history: _pageHistory,
                onNavigate: (pageId) {
                  ref.read(selectedCulturePageIdProvider.notifier).set(pageId);
                },
              ),

              // Page content or empty state
              Expanded(
                child: selectedPageId == null
                    ? _EmptyState(onCreatePage: _createRootPage)
                    : CulturePageView(pageId: selectedPageId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePage});

  final VoidCallback onCreatePage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 72,
            color: colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 24),
          Text(
            'No pages yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first wiki page to start documenting\nyour conlang\'s world and culture.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New page'),
            onPressed: onCreatePage,
          ),
        ],
      ),
    );
  }
}
