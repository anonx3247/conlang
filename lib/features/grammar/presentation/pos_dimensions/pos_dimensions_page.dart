import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../project/data/project_providers.dart';
import 'dimension_editor_panel.dart';
import 'pos_crud_dialog.dart';

/// POS & Dimensions master-detail page — Phase 4 plan 04-04 (D-23 / D-32).
///
/// Left panel: POS list scoped to the current project with an "Add POS"
/// button that opens `showPosCrudDialog`.
/// Right panel: empty-state prompt or [DimensionEditorPanel] for the
/// currently-selected POS.
class PosDimensionsPage extends ConsumerStatefulWidget {
  const PosDimensionsPage({super.key});

  @override
  ConsumerState<PosDimensionsPage> createState() => _PosDimensionsPageState();
}

class _PosDimensionsPageState extends ConsumerState<PosDimensionsPage> {
  int? _selectedPosId;

  Future<void> _deletePos(
    BuildContext context,
    PartsOfSpeechData pos,
    List<PartsOfSpeechData> allPosList,
  ) async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;

    // Count how many lexemes use this POS (stored as text).
    final wordCountResult = await db.customSelect(
      'SELECT COUNT(*) AS cnt FROM lexemes WHERE part_of_speech = ?',
      variables: [Variable.withString(pos.name)],
    ).getSingle();
    final wordCount = wordCountResult.read<int>('cnt');

    final otherPos = allPosList.where((p) => p.id != pos.id).toList();

    if (!context.mounted) return;

    if (wordCount > 0 && otherPos.isEmpty) {
      // Cannot delete — would orphan words and no target to migrate to.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cannot delete ${pos.name}'),
          content: Text(
            '$wordCount word(s) use this POS and there are no other '
            'parts of speech to migrate them to. Add another POS first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    int? migrationTargetId =
        otherPos.isNotEmpty ? otherPos.first.id : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PosDeleteDialog(
        pos: pos,
        wordCount: wordCount,
        otherPos: otherPos,
        initialMigrationTargetId: migrationTargetId,
        onMigrationTargetChanged: (id) => migrationTargetId = id,
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Migrate words if needed.
    if (wordCount > 0 && migrationTargetId != null) {
      final targetPos =
          otherPos.firstWhere((p) => p.id == migrationTargetId);
      await db.customStatement(
        'UPDATE lexemes SET part_of_speech = ? WHERE part_of_speech = ?',
        [targetPos.name, pos.name],
      );
    }

    // Null out inputPosId/outputPosId on morphological rules that reference this POS.
    await db.customStatement(
      'UPDATE morphological_rules SET input_pos_id = NULL WHERE input_pos_id = ?',
      [pos.id],
    );
    await db.customStatement(
      'UPDATE morphological_rules SET output_pos_id = NULL WHERE output_pos_id = ?',
      [pos.id],
    );

    // Delete the POS — cascades to dimensions, markers, inflectional_rule_pos rows.
    await db.morphologyDao.deletePos(pos.id);

    // Reset selection if deleted POS was selected.
    if (_selectedPosId == pos.id) {
      setState(() {
        _selectedPosId =
            otherPos.isNotEmpty ? otherPos.first.id : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? const [];

    // Auto-select the first POS on first data arrival so the right pane
    // is not permanently empty in the common "one project, one POS" case.
    if (_selectedPosId == null && posList.isNotEmpty) {
      // no-op: selection is an explicit user action; leaving the right pane
      // at the "Select a POS" hint is the correct empty-state per UI-SPEC.
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Material(
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Parts of Speech',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add POS',
                        onPressed: () => showPosCrudDialog(context, ref),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: posList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No parts of speech yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: posList.length,
                          itemBuilder: (ctx, i) {
                            final pos = posList[i];
                            final selected = pos.id == _selectedPosId;
                            return ListTile(
                              title: Text('${pos.name} (${pos.abbreviation})'),
                              selected: selected,
                              selectedTileColor: cs.primaryContainer,
                              onTap: () =>
                                  setState(() => _selectedPosId = pos.id),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Edit POS',
                                    onPressed: () =>
                                        showPosCrudDialog(context, ref,
                                            existing: pos),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: cs.error,
                                    ),
                                    tooltip: 'Delete POS',
                                    onPressed: () =>
                                        _deletePos(context, pos, posList),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: cs.outlineVariant),
        Expanded(
          child: _selectedPosId == null
              ? Center(
                  child: Text(
                    'Select a Part of Speech to edit its dimensions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : DimensionEditorPanel(posId: _selectedPosId!),
        ),
      ],
    );
  }
}

/// Dialog that confirms POS deletion and, when words exist, shows a migration
/// target picker.
class _PosDeleteDialog extends StatefulWidget {
  const _PosDeleteDialog({
    required this.pos,
    required this.wordCount,
    required this.otherPos,
    required this.initialMigrationTargetId,
    required this.onMigrationTargetChanged,
  });

  final PartsOfSpeechData pos;
  final int wordCount;
  final List<PartsOfSpeechData> otherPos;
  final int? initialMigrationTargetId;
  final ValueChanged<int?> onMigrationTargetChanged;

  @override
  State<_PosDeleteDialog> createState() => _PosDeleteDialogState();
}

class _PosDeleteDialogState extends State<_PosDeleteDialog> {
  late int? _targetId;

  @override
  void initState() {
    super.initState();
    _targetId = widget.initialMigrationTargetId;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMigration = widget.wordCount > 0 && widget.otherPos.isNotEmpty;

    return AlertDialog(
      title: Text('Delete ${widget.pos.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMigration) ...[
            Text(
              '${widget.wordCount} word(s) use this POS. Reassign them to:',
            ),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: _targetId,
              isExpanded: true,
              items: widget.otherPos
                  .map(
                    (p) => DropdownMenuItem<int>(
                      value: p.id,
                      child: Text('${p.name} (${p.abbreviation})'),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                setState(() => _targetId = id);
                widget.onMigrationTargetChanged(id);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'All its dimensions, inflectional rules, and markers will '
              'also be deleted. This cannot be undone.',
            ),
          ] else ...[
            const Text(
              'This will also delete all its dimensions, inflectional rules, '
              'and markers for this POS. This cannot be undone.',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          onPressed: hasMigration && _targetId == null
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
