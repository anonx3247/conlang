import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view2/flutter_fancy_tree_view2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart' show CulturePage;
import '../../project/data/project_providers.dart';
import '../data/culture_providers.dart';

// ---------------------------------------------------------------------------
// In-memory tree node model
// ---------------------------------------------------------------------------

/// In-memory node wrapping a [CulturePage] with parent/children links.
class CulturePageNode {
  CulturePageNode({
    required this.page,
    CulturePageNode? parent,
  }) : _parent = parent;

  final CulturePage page;
  final List<CulturePageNode> children = [];
  final CulturePageNode? _parent;

  CulturePageNode? get parent => _parent;

  int get id => page.id;
}

// ---------------------------------------------------------------------------
// Tree builder
// ---------------------------------------------------------------------------

List<CulturePageNode> _buildTree(List<CulturePage> allPages) {
  final Map<int, CulturePageNode> nodeMap = {};

  // Create all nodes first (no parent links yet)
  for (final page in allPages) {
    nodeMap[page.id] = CulturePageNode(page: page);
  }

  final roots = <CulturePageNode>[];

  // Second pass: wire parent/children
  for (final page in allPages) {
    final node = nodeMap[page.id]!;
    final parentId = page.parentId;
    if (parentId == null) {
      roots.add(node);
    } else {
      final parentNode = nodeMap[parentId];
      if (parentNode != null) {
        // Re-create node with parent set (since parent is final)
        // We use a workaround: store parent reference via a helper map
        parentNode.children.add(
          _CulturePageNodeWithParent(page: page, parent: parentNode),
        );
        // Remove the parentless version
        nodeMap[page.id] = parentNode.children.last;
      } else {
        // Orphaned node (parent deleted) — show as root
        roots.add(node);
      }
    }
  }

  // Sort each level by ordering
  _sortChildren(roots);

  return roots;
}

void _sortChildren(List<CulturePageNode> nodes) {
  nodes.sort((a, b) => a.page.ordering.compareTo(b.page.ordering));
  for (final node in nodes) {
    _sortChildren(node.children);
  }
}

// Helper subclass that allows setting parent on construction
class _CulturePageNodeWithParent extends CulturePageNode {
  _CulturePageNodeWithParent({
    required super.page,
    required CulturePageNode parent,
  }) : super(parent: parent);
}

// ---------------------------------------------------------------------------
// Page Tree Sidebar
// ---------------------------------------------------------------------------

/// Hierarchical page tree sidebar with expand/collapse, drag-and-drop, and
/// context menu CRUD.
class PageTreeSidebar extends ConsumerStatefulWidget {
  const PageTreeSidebar({
    super.key,
    required this.onPageSelected,
    required this.onCreatePage,
  });

  final void Function(int pageId) onPageSelected;
  final Future<void> Function({int? parentId}) onCreatePage;

  @override
  ConsumerState<PageTreeSidebar> createState() => _PageTreeSidebarState();
}

class _PageTreeSidebarState extends ConsumerState<PageTreeSidebar> {
  TreeController<CulturePageNode>? _treeController;
  List<CulturePageNode> _roots = [];
  bool _initialExpansionDone = false;

  @override
  void dispose() {
    _treeController?.dispose();
    super.dispose();
  }

  void _rebuildTree(List<CulturePage> allPages) {
    final roots = _buildTree(allPages);
    _roots = roots;

    if (_treeController == null) {
      _treeController = TreeController<CulturePageNode>(
        roots: roots,
        childrenProvider: (node) => node.children,
        parentProvider: (node) => node.parent,
      );
    } else {
      _treeController!.roots = roots;
    }

    // Expand first 2 levels by default (only on first build)
    if (!_initialExpansionDone && roots.isNotEmpty) {
      _initialExpansionDone = true;
      _treeController!.expandAll();
      // Collapse nodes at depth >= 2
      _collapseDeep(roots, 0);
      _treeController!.rebuild();
    } else if (_initialExpansionDone) {
      _treeController!.rebuild();
    }
  }

  void _collapseDeep(List<CulturePageNode> nodes, int depth) {
    for (final node in nodes) {
      if (depth >= 2) {
        _treeController!.setExpansionState(node, false);
      }
      _collapseDeep(node.children, depth + 1);
    }
  }

  Future<void> _showContextMenu(
      BuildContext ctx, Offset position, CulturePageNode node) async {
    final RenderBox overlay =
        Overlay.of(ctx).context.findRenderObject()! as RenderBox;
    final errorColor = Theme.of(ctx).colorScheme.error;

    final value = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'set_icon', child: Text('Set icon')),
        const PopupMenuItem(
            value: 'add_child', child: Text('Add child page')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete page',
            style: TextStyle(color: errorColor),
          ),
        ),
      ],
    );

    if (!mounted) return;

    // Use this.context (State's own context) after async gap — linter-safe.
    switch (value) {
      case 'rename':
        _showRenameDialog(context, node);
        break;
      case 'set_icon':
        _showSetIconDialog(context, node);
        break;
      case 'add_child':
        widget.onCreatePage(parentId: node.id).then((_) {
          if (mounted && _treeController != null) {
            _treeController!.setExpansionState(node, true);
            _treeController!.rebuild();
          }
        });
        break;
      case 'delete':
        _showDeleteDialog(context, node);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, CulturePageNode node) {
    final controller = TextEditingController(text: node.page.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Page title'),
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                ref
                    .read(currentDatabaseProvider)
                    ?.cultureDao
                    .updatePage(node.id, title: title);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showSetIconDialog(BuildContext context, CulturePageNode node) {
    final controller = TextEditingController(text: node.page.icon ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set page icon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Page icon (emoji)'),
          onSubmitted: (_) => Navigator.of(ctx).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final icon = controller.text.trim();
              ref.read(currentDatabaseProvider)?.cultureDao.updatePage(
                    node.id,
                    icon: Value(icon.isEmpty ? null : icon),
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Set icon'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDeleteDialog(BuildContext context, CulturePageNode node) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete '${node.page.title}'?"),
        content: const Text(
          'This page and all its child pages will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () {
              ref
                  .read(currentDatabaseProvider)
                  ?.cultureDao
                  .deletePage(node.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete Page'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(culturePageListProvider);

    return pagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load pages. Check the project database is accessible.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
      data: (pages) {
        _rebuildTree(pages);
        final controller = _treeController;
        if (controller == null || _roots.isEmpty) {
          return const SizedBox.shrink();
        }

        return AnimatedTreeView<CulturePageNode>(
          treeController: controller,
          nodeBuilder: (context, entry) {
            return _TreeNodeTile(
              entry: entry,
              onTap: () => widget.onPageSelected(entry.node.id),
              onToggleExpand: () =>
                  controller.toggleExpansion(entry.node),
              onContextMenu: (pos) =>
                  _showContextMenu(context, pos, entry.node),
              onCreateChild: () =>
                  widget.onCreatePage(parentId: entry.node.id).then((_) {
                if (mounted) {
                  controller.setExpansionState(entry.node, true);
                  controller.rebuild();
                }
              }),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tree node tile
// ---------------------------------------------------------------------------

class _TreeNodeTile extends ConsumerStatefulWidget {
  const _TreeNodeTile({
    required this.entry,
    required this.onTap,
    required this.onToggleExpand,
    required this.onContextMenu,
    required this.onCreateChild,
  });

  final TreeEntry<CulturePageNode> entry;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;
  final void Function(Offset position) onContextMenu;
  final VoidCallback onCreateChild;

  @override
  ConsumerState<_TreeNodeTile> createState() => _TreeNodeTileState();
}

class _TreeNodeTileState extends ConsumerState<_TreeNodeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedId = ref.watch(selectedCulturePageIdProvider);
    final isSelected = selectedId == widget.entry.node.id;
    final page = widget.entry.node.page;
    final hasChildren = widget.entry.hasChildren;

    return TreeDragTarget<CulturePageNode>(
      node: widget.entry.node,
      onNodeAccepted: (details) async {
        final db = ref.read(currentDatabaseProvider);
        if (db == null) return;
        final maxOrder = await db.cultureDao
            .maxSiblingOrdering(widget.entry.node.id);
        await db.cultureDao.reparentPage(
          details.draggedNode.id,
          widget.entry.node.id,
          maxOrder + 1,
        );
      },
      builder: (context, details) {
        Decoration? dropDecoration;
        if (details != null) {
          dropDecoration = BoxDecoration(
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          );
        }

        return TreeDraggable<CulturePageNode>(
          node: widget.entry.node,
          longPressDelay: Durations.long2,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 200,
              child: _TileContent(
                page: page,
                hasChildren: hasChildren,
                isExpanded: widget.entry.isExpanded,
                isSelected: false,
                hovered: false,
                onToggleExpand: () {},
                onContextMenu: (_) {},
              ),
            ),
          ),
          child: GestureDetector(
            onSecondaryTapDown: (details) =>
                widget.onContextMenu(details.globalPosition),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: TreeIndentation(
                entry: widget.entry,
                guide: const IndentGuide(indent: 16),
                child: InkWell(
                  onTap: widget.onTap,
                  child: DecoratedBox(
                    decoration: dropDecoration ??
                        BoxDecoration(
                          color: isSelected
                              ? colorScheme.primaryContainer
                              : _hovered
                                  ? colorScheme.surfaceContainer
                                  : Colors.transparent,
                          border: isSelected
                              ? Border(
                                  left: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                )
                              : null,
                        ),
                    child: _TileContent(
                      page: page,
                      hasChildren: hasChildren,
                      isExpanded: widget.entry.isExpanded,
                      isSelected: isSelected,
                      hovered: _hovered,
                      onToggleExpand: widget.onToggleExpand,
                      onContextMenu: widget.onContextMenu,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tile content (used both in normal tile and drag feedback)
// ---------------------------------------------------------------------------

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.page,
    required this.hasChildren,
    required this.isExpanded,
    required this.isSelected,
    required this.hovered,
    required this.onToggleExpand,
    required this.onContextMenu,
  });

  final CulturePage page;
  final bool hasChildren;
  final bool isExpanded;
  final bool isSelected;
  final bool hovered;
  final VoidCallback onToggleExpand;
  final void Function(Offset position) onContextMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final textColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface.withValues(alpha: 0.85);

    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Expand/collapse arrow
            if (hasChildren)
              GestureDetector(
                onTap: onToggleExpand,
                child: Icon(
                  isExpanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  size: 16,
                  color: textColor,
                ),
              )
            else
              const SizedBox(width: 16),

            // Emoji icon prefix
            if (page.icon != null && page.icon!.isNotEmpty) ...[
              Text(page.icon!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
            ],

            // Page title
            Expanded(
              child: Text(
                page.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Drag indicator + overflow button on hover
            if (hovered) ...[
              Opacity(
                opacity: 0.4,
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTapDown: (d) => onContextMenu(d.globalPosition),
                child: Icon(
                  Icons.more_horiz,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

