import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/morphology_dao.dart';
import '../../data/morphology_providers.dart';

/// POS management page for creating, editing, and deleting parts of speech.
///
/// Shows all parts of speech in a Card list with edit/delete actions.
/// An FAB opens an add dialog; tapping the edit icon opens a pre-filled dialog.
class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dao = ref.watch(morphologyDaoProvider);
    final hasProject = dao != null;

    if (!hasProject) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final posAsync = ref.watch(posListProvider);

    return Scaffold(
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (posList) {
          if (posList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No parts of speech defined yet.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add one to categorize rules.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posList.length,
            itemBuilder: (context, i) {
              final pos = posList[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Abbreviation badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pos.abbreviation,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name
                      Expanded(
                        child: Text(
                          pos.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Edit button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () async {
                          await _showPosDialog(context, dao, existing: pos);
                        },
                      ),
                      // Delete button
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirmed = await _confirmDelete(
                            context,
                            pos.name,
                          );
                          if (confirmed && context.mounted) {
                            await dao.deletePos(pos.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: hasProject
          ? FloatingActionButton.extended(
              onPressed: () async {
                await _showPosDialog(context, dao);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add POS'),
            )
          : null,
    );
  }

  Future<void> _showPosDialog(
    BuildContext context,
    MorphologyDao dao, {
    PartsOfSpeechData? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PosDialog(dao: dao, existing: existing),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete part of speech?'),
            content: Text('Delete "$name"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Dialog for creating or editing a part of speech.
class _PosDialog extends StatefulWidget {
  const _PosDialog({required this.dao, this.existing});

  final MorphologyDao dao;
  final PartsOfSpeechData? existing;

  @override
  State<_PosDialog> createState() => _PosDialogState();
}

class _PosDialogState extends State<_PosDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _abbrevCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _abbrevCtrl = TextEditingController(
      text: widget.existing?.abbreviation ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final abbreviation = _abbrevCtrl.text.trim();
    if (name.isEmpty || abbreviation.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.dao.insertPos(
          PartsOfSpeechCompanion.insert(name: name, abbreviation: abbreviation),
        );
      } else {
        await widget.dao.updatePos(
          widget.existing!.copyWith(name: name, abbreviation: abbreviation),
        );
      }
      if (mounted) Navigator.of(context).pop();
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
            controller: _abbrevCtrl,
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
          onPressed: () => Navigator.of(context).pop(),
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
