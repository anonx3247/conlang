import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/construction_dao.dart';
import '../../data/construction_providers.dart';
import 'construction_preview.dart';
import 'slot_editor.dart';

/// Full Constructions page with master-detail layout.
///
/// Left panel: list of named phrase constructions with add/delete actions.
/// Right panel: slot editor + live preview for the selected construction.
///
/// Phase 10 AGRAM-02.
class ConstructionsPage extends ConsumerStatefulWidget {
  const ConstructionsPage({super.key});

  @override
  ConsumerState<ConstructionsPage> createState() => _ConstructionsPageState();
}

class _ConstructionsPageState extends ConsumerState<ConstructionsPage> {
  int? _selectedConstructionId;
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, FocusNode> _nameFocusNodes = {};
  FocusNode? _dummyFocusNode;

  @override
  void dispose() {
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final f in _nameFocusNodes.values) {
      f.dispose();
    }
    _dummyFocusNode?.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(
    PhraseConstruction construction,
  ) {
    return _nameControllers.putIfAbsent(
      construction.id,
      () => TextEditingController(text: construction.name),
    );
  }

  FocusNode _focusNodeFor(
    PhraseConstruction construction,
    ConstructionDao dao,
  ) {
    if (!_nameFocusNodes.containsKey(construction.id)) {
      final node = FocusNode();
      node.addListener(() async {
        if (!node.hasFocus) {
          final controller = _nameControllers[construction.id];
          if (controller == null) return;
          final newName = controller.text.trim();
          if (newName.isEmpty || newName == construction.name) return;
          await dao.updateConstruction(
            construction.copyWith(name: newName),
          );
        }
      });
      _nameFocusNodes[construction.id] = node;
    }
    return _nameFocusNodes[construction.id]!;
  }

  Future<void> _addConstruction(
    BuildContext context,
    ConstructionDao dao,
    List<PhraseConstruction> existingList,
  ) async {
    final id = await dao.insertConstruction(
      PhraseConstructionsCompanion.insert(
        name: 'New Construction',
        ordering: Value(existingList.length),
      ),
    );
    setState(() {
      _selectedConstructionId = id;
    });
  }

  Future<void> _deleteConstruction(
    BuildContext context,
    ConstructionDao dao,
    PhraseConstruction construction,
    List<PhraseConstruction> allConstructions,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete construction?'),
        content: Text(
          "'${construction.name}' and all its slots will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await dao.deleteConstruction(construction.id);

    // Select adjacent construction if this was selected.
    if (_selectedConstructionId == construction.id) {
      final remaining =
          allConstructions.where((c) => c.id != construction.id).toList();
      setState(() {
        _selectedConstructionId =
            remaining.isNotEmpty ? remaining.first.id : null;
        _nameControllers.remove(construction.id)?.dispose();
        _nameFocusNodes.remove(construction.id)?.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final constructionsAsync = ref.watch(constructionListProvider);
    final dao = ref.read(constructionDaoProvider);

    return constructionsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (constructions) {
        // Auto-select first construction on load if none selected.
        if (_selectedConstructionId == null && constructions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedConstructionId == null) {
              setState(() {
                _selectedConstructionId = constructions.first.id;
              });
            }
          });
        }

        // Update name controllers when constructions list changes.
        for (final c in constructions) {
          final ctrl = _nameControllers[c.id];
          if (ctrl != null && ctrl.text != c.name) {
            // Only update if not currently focused (user may be editing).
            final focusNode = _nameFocusNodes[c.id];
            if (focusNode == null || !focusNode.hasFocus) {
              ctrl.text = c.name;
            }
          }
        }

        if (constructions.isEmpty) {
          return _EmptyState(
            onAdd: dao == null
                ? null
                : () => _addConstruction(context, dao, constructions),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            // Left panel — construction list
            // ----------------------------------------------------------------
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      'Constructions',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: FilledButton.icon(
                      onPressed: dao == null
                          ? null
                          : () => _addConstruction(
                                context,
                                dao,
                                constructions,
                              ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Construction'),
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: ListView.builder(
                      itemCount: constructions.length,
                      itemBuilder: (context, index) {
                        final construction = constructions[index];
                        final isSelected =
                            _selectedConstructionId == construction.id;
                        return _ConstructionListItem(
                          construction: construction,
                          isSelected: isSelected,
                          onTap: () => setState(() {
                            _selectedConstructionId = construction.id;
                          }),
                          onDelete: dao == null
                              ? null
                              : () => _deleteConstruction(
                                    context,
                                    dao,
                                    construction,
                                    constructions,
                                  ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const VerticalDivider(width: 1),

            // ----------------------------------------------------------------
            // Right panel — slot editor + preview
            // ----------------------------------------------------------------
            Expanded(
              child: _selectedConstructionId == null
                  ? Center(
                      child: Text(
                        'Select a construction to edit',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : _buildDetailPanel(context, theme, dao, constructions),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPanel(
    BuildContext context,
    ThemeData theme,
    ConstructionDao? dao,
    List<PhraseConstruction> constructions,
  ) {
    final construction = constructions.firstWhere(
      (c) => c.id == _selectedConstructionId,
      orElse: () => constructions.first,
    );

    final nameController = _controllerFor(construction);
    final focusNode =
        dao != null ? _focusNodeFor(construction, dao) : (_dummyFocusNode ??= FocusNode());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Construction name — editable
          TextField(
            controller: nameController,
            focusNode: focusNode,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Construction name',
              hintText: 'e.g. Negation, Future tense, Genitive',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Slot editor
          SlotEditor(constructionId: construction.id),
          const SizedBox(height: 24),

          // Live preview
          ConstructionPreview(constructionId: construction.id),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Construction list item
// ---------------------------------------------------------------------------

class _ConstructionListItem extends ConsumerWidget {
  const _ConstructionListItem({
    required this.construction,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final PhraseConstruction construction;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slotsAsync =
        ref.watch(constructionSlotsProvider(construction.id));
    final slots = slotsAsync.asData?.value ?? [];
    final subtitle = slots.isEmpty
        ? null
        : slots.map((s) => s.slotValue).join(' + ');

    return ListTile(
      title: Text(construction.name),
      subtitle: subtitle != null ? Text(subtitle) : null,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        color: theme.colorScheme.error,
        onPressed: onDelete,
        tooltip: 'Delete construction',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No constructions yet',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Define phrase patterns (e.g. NEG + V, AUX:FUT + V) to describe\n'
            'how your language expresses grammatical meaning analytically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Construction'),
          ),
        ],
      ),
    );
  }
}
