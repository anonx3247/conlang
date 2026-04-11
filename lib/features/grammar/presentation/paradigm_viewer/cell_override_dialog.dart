import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../db/app_database.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../project/data/project_providers.dart';
import '../../data/paradigm_cell_override_dao.dart';
import '../../domain/paradigm_cell.dart';

/// Per-cell override dialog (D-28).
///
/// Fields:
///   - Romanization (primary) — auto-derives IPA on first input via
///     `deromanizeProvider`
///   - IPA — editable; editing locks the auto-derive
///
/// Uncovered cells additionally show a "Create a rule for this cell"
/// shortcut that navigates to `/grammar/inflectional` with the feature set
/// as `GoRouter.extra`. Covered cells with an existing override show
/// a "Clear override" button that deletes the row.
class CellOverrideDialog extends ConsumerStatefulWidget {
  const CellOverrideDialog({
    super.key,
    required this.lexemeId,
    required this.featureSet,
    required this.currentCell,
    this.existingOverride,
  });

  final int lexemeId;
  final Map<int, int> featureSet;
  final ParadigmCell? currentCell;
  final ParadigmCellOverride? existingOverride;

  @override
  ConsumerState<CellOverrideDialog> createState() => _CellOverrideDialogState();
}

class _CellOverrideDialogState extends ConsumerState<CellOverrideDialog> {
  late final TextEditingController _romController;
  late final TextEditingController _ipaController;
  bool _ipaDerivedFromRom = true;

  @override
  void initState() {
    super.initState();
    _romController = TextEditingController(
      text: widget.existingOverride?.overrideRomanization ?? '',
    );
    _ipaController = TextEditingController(
      text: widget.existingOverride?.overrideIpa ?? '',
    );
    if (widget.existingOverride != null) _ipaDerivedFromRom = false;
  }

  @override
  void dispose() {
    _romController.dispose();
    _ipaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deromanize = ref.watch(deromanizeProvider);
    final isUncovered =
        widget.currentCell == null || widget.currentCell is ParadigmUncovered;

    return AlertDialog(
      title: const Text('Edit cell'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _romController,
              decoration: const InputDecoration(labelText: 'Romanization'),
              onChanged: (v) {
                if (_ipaDerivedFromRom) {
                  _ipaController.text = deromanize(v);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ipaController,
              decoration: const InputDecoration(labelText: 'IPA'),
              onChanged: (_) => _ipaDerivedFromRom = false,
            ),
            if (isUncovered) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).go(
                    '/grammar/inflectional',
                    extra: widget.featureSet,
                  );
                },
                child: const Text('Create a rule for this cell'),
              ),
            ],
            if (widget.existingOverride != null) ...[
              const SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () async {
                  final db = ref.read(currentDatabaseProvider);
                  if (db == null) return;
                  final navigator = Navigator.of(context);
                  await ParadigmCellOverrideDao(db).clearOverride(
                    lexemeId: widget.lexemeId,
                    featureSet: widget.featureSet,
                  );
                  if (mounted) navigator.pop();
                },
                child: const Text('Clear override'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final db = ref.read(currentDatabaseProvider);
            if (db == null) return;
            final navigator = Navigator.of(context);
            final ipa = _ipaController.text;
            if (ipa.isEmpty) {
              // Nothing to save — just dismiss. This matches the UI-SPEC's
              // implicit "IPA is the primary stored form" requirement without
              // throwing a FK/NOT NULL error from Drift.
              navigator.pop();
              return;
            }
            await ParadigmCellOverrideDao(db).upsertOverride(
              lexemeId: widget.lexemeId,
              featureSet: widget.featureSet,
              overrideIpa: ipa,
              overrideRomanization:
                  _romController.text.isEmpty ? null : _romController.text,
            );
            if (mounted) navigator.pop();
          },
          child: const Text('Save Override'),
        ),
      ],
    );
  }
}
