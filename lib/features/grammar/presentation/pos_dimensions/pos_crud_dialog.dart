import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../project/data/project_providers.dart';

/// Shows the POS create/edit dialog relocated from the deleted
/// `lib/features/morphology/presentation/pos/pos_page.dart`.
///
/// Returns true on save, false on cancel / dismiss.
///
/// When [existing] is null, inserts a new row; otherwise updates it.
Future<bool> showPosCrudDialog(
  BuildContext context,
  WidgetRef ref, {
  PartsOfSpeechData? existing,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _PosCrudDialog(existing: existing),
  );
  return saved ?? false;
}

class _PosCrudDialog extends ConsumerStatefulWidget {
  const _PosCrudDialog({this.existing});

  final PartsOfSpeechData? existing;

  @override
  ConsumerState<_PosCrudDialog> createState() => _PosCrudDialogState();
}

class _PosCrudDialogState extends ConsumerState<_PosCrudDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _abbrCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _abbrCtrl =
        TextEditingController(text: widget.existing?.abbreviation ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final abbr = _abbrCtrl.text.trim().toLowerCase();
    if (name.isEmpty || abbr.isEmpty) return;

    setState(() => _saving = true);
    try {
      final db = ref.read(currentDatabaseProvider);
      if (db == null) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      if (widget.existing == null) {
        await db.into(db.partsOfSpeech).insert(
              PartsOfSpeechCompanion.insert(name: name, abbreviation: abbr),
            );
      } else {
        await (db.update(db.partsOfSpeech)
              ..where((t) => t.id.equals(widget.existing!.id)))
            .write(PartsOfSpeechCompanion(
          name: Value(name),
          abbreviation: Value(abbr),
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Part of Speech' : 'Add Part of Speech'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Noun, Verb, Adjective',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _abbrCtrl,
            decoration: const InputDecoration(
              labelText: 'Abbreviation',
              hintText: 'e.g. N, V, ADJ',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
