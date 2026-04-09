import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/lexeme_providers.dart';
import '../../data/semantic_providers.dart';

/// Thesaurus page — shows the Conlanger's Thesaurus as a hierarchical category
/// tree. Users can browse semantic domains, expand/collapse nodes, and search
/// for specific concepts. Uncovered leaf concepts have a "Name this concept"
/// action that navigates to word creation with the meaning pre-filled.
///
/// Implements D-14, D-15, D-16 from 03-CONTEXT.md and the UI-SPEC Thesaurus
/// interaction contract.
class ThesaurusPage extends ConsumerStatefulWidget {
  const ThesaurusPage({super.key});

  @override
  ConsumerState<ThesaurusPage> createState() => _ThesaurusPageState();
}

class _ThesaurusPageState extends ConsumerState<ThesaurusPage> {
  String _searchQuery = '';
  final Set<String> _expandedNodes = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns true if [category] or any descendant matches [query].
  bool _matchesSearch(ThesaurusCategory category, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (category.name.toLowerCase().contains(q)) return true;
    if (category.concepts.any((c) => c.toLowerCase().contains(q))) return true;
    return category.subcategories.any((sub) => _matchesSearch(sub, q));
  }

  /// Returns the node path key used to track expand/collapse state.
  String _nodePath(String parentPath, String name) =>
      parentPath.isEmpty ? name : '$parentPath/$name';

  bool _isExpanded(String path) => _expandedNodes.contains(path);

  void _toggleExpanded(String path) {
    setState(() {
      if (_expandedNodes.contains(path)) {
        _expandedNodes.remove(path);
      } else {
        _expandedNodes.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thesaurusAsync = ref.watch(thesaurusProvider);
    final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];

    // Build a meaning lookup set for O(1) coverage checks.
    final coveredMeanings = {
      for (final l in allLexemes)
        if (l.meaning != null && l.meaning!.isNotEmpty)
          l.meaning!.toLowerCase(): l,
    };

    return Container(
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search concepts...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: colorScheme.outlineVariant),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    // When searching, auto-expand all nodes that match.
                    if (value.isNotEmpty) {
                      _expandedNodes.clear();
                    }
                  });
                },
              ),
            ),
          ),
          // Tree view
          Expanded(
            child: thesaurusAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Could not load lexicon. Check that the project database is accessible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.error,
                  ),
                ),
              ),
              data: (categories) {
                // Filter top-level categories when searching.
                final visible = _searchQuery.isEmpty
                    ? categories
                    : categories
                        .where((c) => _matchesSearch(c, _searchQuery))
                        .toList();

                if (visible.isEmpty && allLexemes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No lexicon entries yet. Browse categories to find concepts to name.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }

                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      'No matching concepts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final category = visible[index];
                    return _CategoryTile(
                      category: category,
                      nodePath: category.name,
                      depth: 0,
                      isExpanded: _isExpanded(category.name),
                      onToggle: () => _toggleExpanded(category.name),
                      coveredMeanings: coveredMeanings,
                      searchQuery: _searchQuery,
                      matchesSearch: _matchesSearch,
                      expandedNodes: _expandedNodes,
                      onToggleNode: _toggleExpanded,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recursive category tile
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.nodePath,
    required this.depth,
    required this.isExpanded,
    required this.onToggle,
    required this.coveredMeanings,
    required this.searchQuery,
    required this.matchesSearch,
    required this.expandedNodes,
    required this.onToggleNode,
  });

  final ThesaurusCategory category;
  final String nodePath;
  final int depth;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Map<String, dynamic> coveredMeanings;
  final String searchQuery;
  final bool Function(ThesaurusCategory, String) matchesSearch;
  final Set<String> expandedNodes;
  final void Function(String) onToggleNode;

  bool get hasChildren =>
      category.subcategories.isNotEmpty || category.concepts.isNotEmpty;

  bool get hasSubcategories => category.subcategories.isNotEmpty;

  // Whether this node should auto-expand when search is active.
  bool get _autoExpand => searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final indentPx = depth * 24.0;

    // A category with subcategories is a container node (expand/collapse).
    if (hasSubcategories) {
      final expanded = _autoExpand || isExpanded;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category header row (expand/collapse)
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16 + indentPx, 8, 16, 8),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Children (when expanded)
          if (expanded) ...[
            for (final sub in category.subcategories)
              if (searchQuery.isEmpty || matchesSearch(sub, searchQuery))
                _CategoryTile(
                  category: sub,
                  nodePath: '$nodePath/${sub.name}',
                  depth: depth + 1,
                  isExpanded:
                      expandedNodes.contains('$nodePath/${sub.name}'),
                  onToggle: () =>
                      onToggleNode('$nodePath/${sub.name}'),
                  coveredMeanings: coveredMeanings,
                  searchQuery: searchQuery,
                  matchesSearch: matchesSearch,
                  expandedNodes: expandedNodes,
                  onToggleNode: onToggleNode,
                ),
          ],
        ],
      );
    }

    // A category with only concepts is a leaf group node.
    if (category.concepts.isNotEmpty) {
      final expanded = _autoExpand || isExpanded;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subcategory header
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16 + indentPx, 6, 16, 6),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Leaf concepts
          if (expanded) ...[
            for (final concept in category.concepts)
              if (searchQuery.isEmpty ||
                  concept.toLowerCase().contains(searchQuery.toLowerCase()))
                _ConceptTile(
                  concept: concept,
                  lexeme: coveredMeanings[concept.toLowerCase()],
                  depth: depth + 1,
                ),
          ],
        ],
      );
    }

    // Bare category with no children — show as a leaf concept group header.
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + indentPx, 6, 16, 6),
      child: Text(
        category.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaf concept tile
// ---------------------------------------------------------------------------

class _ConceptTile extends StatelessWidget {
  const _ConceptTile({
    required this.concept,
    required this.lexeme,
    required this.depth,
  });

  final String concept;
  final dynamic lexeme; // Lexeme? — nullable
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCovered = lexeme != null;
    final indentPx = depth * 24.0;

    if (isCovered) {
      // Covered leaf: show check icon + word form
      final displayForm =
          (lexeme.romanization as String?)?.isNotEmpty == true
              ? lexeme.romanization as String
              : lexeme.ipa as String;

      return Padding(
        padding:
            EdgeInsets.fromLTRB(16 + indentPx, 3, 16, 3),
        child: Row(
          children: [
            Icon(Icons.check, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(concept, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text(
              displayForm,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    // Uncovered leaf: show "Name this concept" action
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + indentPx, 2, 8, 2),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(concept, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorScheme.primary,
            ),
            onPressed: () {
              context.go(
                '/lexicon/dictionary?create=true&meaning=${Uri.encodeComponent(concept)}',
              );
            },
            child: const Text(
              'Name this concept',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
