import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/grammar_providers.dart';
import '../../domain/dimension_level.dart';
import 'dimension_template_picker.dart';

/// Right-pane dimension editor for the POS & Dimensions master-detail page.
///
/// Subscribes to `dimensionsForPosProvider(posId)` and renders one Card per
/// dimension with level chips and delete controls, plus the "Add Dimension"
/// CTA that opens the template picker.
class DimensionEditorPanel extends ConsumerWidget {
  const DimensionEditorPanel({super.key, required this.posId});

  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    // Treat loading as empty-list so the page doesn't flash a spinner on
    // the first listen. Matches the project-wide `asData?.value ?? const []`
    // pattern used in the POS list on the left pane.
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    if (dimsAsync.hasError) {
      return Center(child: Text('Error: ${dimsAsync.error}'));
    }
    return _buildContent(context, ref, theme, dims);
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<Dimension> dims,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dimensions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _onAddDimension(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Dimension'),
              ),
            ],
          ),
        ),
        if (dims.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 64,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dimensions yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click "Add Dimension" to begin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dims.length,
              itemBuilder: (ctx, i) =>
                  _dimensionCard(ctx, ref, theme, dims[i]),
            ),
          ),
      ],
    );
  }

  Future<void> _onAddDimension(BuildContext ctx, WidgetRef ref) async {
    final template = await showDimensionTemplatePicker(ctx);
    if (template == null) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    final ordering = await dao.nextDimensionOrdering(posId);
    await dao.insertDimension(
      DimensionsCompanion.insert(
        posId: posId,
        name: template.name,
        ordering: Value(ordering),
        levelsJson: encodeLevelsJson(template.levels),
        templateId: Value(template.id),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext ctx,
    WidgetRef ref,
    Dimension dim,
  ) async {
    final newName = await showDialog<String>(
      context: ctx,
      builder: (dlgCtx) => _RenameDimensionDialog(initialName: dim.name),
    );
    if (newName == null || newName.isEmpty) return;
    if (newName == dim.name) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    await dao.updateDimension(dim.copyWith(name: newName));
  }

  Widget _dimensionCard(
    BuildContext ctx,
    WidgetRef ref,
    ThemeData theme,
    Dimension dim,
  ) {
    final levels = decodeLevelsJson(dim.levelsJson);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dim.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // G-11: rename affordance — opens a dialog with the current
                // name pre-filled, rejects empty input, and calls
                // GrammarDao.updateDimension on save.
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Rename dimension',
                  onPressed: () => _showRenameDialog(ctx, ref, dim),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete dimension',
                  onPressed: () async {
                    final dao = ref.read(grammarDaoProvider);
                    if (dao == null) return;
                    await dao.deleteDimension(dim.id);
                  },
                ),
              ],
            ),
            if (levels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final l in levels)
                    InputChip(
                      label: Text('${l.name} (${l.abbr})'),
                      onDeleted: () async {
                        final dao = ref.read(grammarDaoProvider);
                        if (dao == null) return;
                        final updated = decodeLevelsJson(dim.levelsJson)
                            .where((x) => x.id != l.id)
                            .toList();
                        await dao.updateDimensionLevels(dim.id, updated);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stateful dialog body for the rename-dimension flow (G-11). Owns its
/// own [TextEditingController] so the controller lifecycle matches the
/// dialog's State lifecycle — avoids "used after dispose" errors from
/// the in-build callback chain that fires when the dialog is popped.
class _RenameDimensionDialog extends StatefulWidget {
  const _RenameDimensionDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDimensionDialog> createState() =>
      _RenameDimensionDialogState();
}

class _RenameDimensionDialogState extends State<_RenameDimensionDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Name cannot be empty');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename dimension'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _onSave(),
        decoration: InputDecoration(
          labelText: 'Dimension name',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
