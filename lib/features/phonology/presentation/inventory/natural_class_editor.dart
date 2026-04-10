import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phoneme_providers.dart';

/// Validates a user-entered natural-class name for the editor dialog.
///
/// Returns `null` when the name is acceptable, or a human-readable error
/// string suitable for a [TextFormField]'s `errorText`.
///
/// Reserved names:
///   - `C`, `V` — system classes from Phase 1 (all consonants / all vowels).
///   - `S`, `N`, `F`, `L`, `R` — single-letter default-class aliases from
///     Phase 3.2 (Stop/Nasal/Fricative/Liquid/Rhotic). Blocking these prevents
///     users from creating classes whose names collide with the predefined
///     alias map, which would otherwise silently never be reached by the
///     resolver (alias lookup runs BEFORE the user-class lookup path).
///
/// Lowercase full names (`stop`, `nasal`, etc.) are INTENTIONALLY allowed —
/// D-06 lets users shadow default full-name classes with their own lists.
String? validateNaturalClassName(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final trimmed = v.trim();

  // Reserved system classes from Phase 1.
  if (trimmed == 'C' || trimmed == 'V') {
    return 'C and V are reserved system classes';
  }

  // Reserved single-letter aliases from Phase 3.2 (D-05a / RESEARCH F-2).
  const reservedAliases = {'S', 'N', 'F', 'L', 'R'};
  if (reservedAliases.contains(trimmed)) {
    return '$trimmed is a reserved default-class alias '
        '(${_aliasExpansion(trimmed)}). Use a different name.';
  }

  return null;
}

String _aliasExpansion(String letter) {
  switch (letter) {
    case 'S':
      return 'Stop';
    case 'N':
      return 'Nasal';
    case 'F':
      return 'Fricative';
    case 'L':
      return 'Liquid';
    case 'R':
      return 'Rhotic';
  }
  return '';
}

/// Dialog for creating or editing a natural phonological class.
///
/// A natural class is a named set of phonemes used in DSL expressions
/// such as `[stop]` or `[nasal]`. Two system classes are always available:
/// - `C` — all consonants
/// - `V` — all vowels
///
/// Pass [naturalClass] to open in edit mode; leave null to create a new class.
class NaturalClassEditor extends ConsumerStatefulWidget {
  const NaturalClassEditor({super.key, this.naturalClass});

  /// When provided, the dialog opens in edit mode.
  final NaturalClassesData? naturalClass;

  @override
  ConsumerState<NaturalClassEditor> createState() => _NaturalClassEditorState();
}

class _NaturalClassEditorState extends ConsumerState<NaturalClassEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late Set<int> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final nc = widget.naturalClass;
    _nameController = TextEditingController(text: nc?.name ?? '');
    if (nc != null) {
      final decoded = jsonDecode(nc.phonemeIds);
      _selectedIds = decoded is List
          ? decoded.whereType<int>().toSet()
          : <int>{};
    } else {
      _selectedIds = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.naturalClass != null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dao = ref.read(naturalClassDaoProvider);
    if (dao == null) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();
      final phonemeIds = jsonEncode(_selectedIds.toList()..sort());

      if (_isEditing) {
        final updated = widget.naturalClass!.copyWith(
          name: name,
          phonemeIds: phonemeIds,
        );
        await dao.updateClass(updated);
      } else {
        await dao.insertClass(
          NaturalClassesCompanion.insert(name: name, phonemeIds: phonemeIds),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPhonemes = ref.watch(allPhonemesProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Natural Class' : 'New Natural Class'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // System classes notice
              _SystemClassesNote(),
              const SizedBox(height: 12),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g. stop, nasal, liquid, obstruent',
                  helperText: 'Used in DSL as [name], e.g. [stop]',
                ),
                validator: validateNaturalClassName,
              ),
              const SizedBox(height: 16),

              // Phoneme multi-select
              Text(
                'Phonemes',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),

              allPhonemes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (phonemes) {
                  if (phonemes.isEmpty) {
                    return const Text(
                      'No phonemes in inventory yet. Add some phonemes first.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    );
                  }

                  // Group by type
                  final consonants =
                      phonemes.where((p) => p.type == 'consonant').toList();
                  final vowels =
                      phonemes.where((p) => p.type == 'vowel').toList();

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (consonants.isNotEmpty) ...[
                            _PhonemeGroupSelector(
                              label: 'Consonants',
                              phonemes: consonants,
                              selectedIds: _selectedIds,
                              onChanged: (id, selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            ),
                          ],
                          if (vowels.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _PhonemeGroupSelector(
                              label: 'Vowels',
                              phonemes: vowels,
                              selectedIds: _selectedIds,
                              onChanged: (id, selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SystemClassesNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'C (all consonants) and V (all vowels) are built-in system classes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonemeGroupSelector extends StatelessWidget {
  const _PhonemeGroupSelector({
    required this.label,
    required this.phonemes,
    required this.selectedIds,
    required this.onChanged,
  });

  final String label;
  final List<Phoneme> phonemes;
  final Set<int> selectedIds;
  final void Function(int id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: phonemes.map((p) {
            final selected = selectedIds.contains(p.id);
            return FilterChip(
              label: Text(p.symbol),
              selected: selected,
              onSelected: (v) => onChanged(p.id, v),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Confirms deletion of a natural class and removes it.
Future<void> confirmDeleteNaturalClass(
  BuildContext context,
  WidgetRef ref,
  NaturalClassesData nc,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Natural Class'),
      content: Text(
        'Remove the class [${nc.name}]? DSL patterns referencing it will break.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final dao = ref.read(naturalClassDaoProvider);
    await dao?.deleteClass(nc.id);
  }
}
