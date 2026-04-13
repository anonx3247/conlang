import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../domain/leipzig_catalog.dart';

/// Add-or-edit dialog for a closed-class particle/auxiliary/determiner/etc.
///
/// Pass [existingParticle] to open in edit mode (pre-fills all fields);
/// omit it for add mode.
///
/// On save, inserts a new [Lexeme] with [Lexemes.isClosedClass] = true
/// (add mode) or replaces the existing row (edit mode). The
/// [closedClassLexemeListProvider] stream updates immediately because it
/// watches the same table.
class ParticleDialog extends ConsumerStatefulWidget {
  const ParticleDialog({super.key, this.existingParticle});

  /// When non-null the dialog is in edit mode; null = add mode.
  final Lexeme? existingParticle;

  @override
  ConsumerState<ParticleDialog> createState() => _ParticleDialogState();
}

class _ParticleDialogState extends ConsumerState<ParticleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ipaController;
  late final TextEditingController _meaningController;
  late final TextEditingController _glossTagController;

  String? _selectedPos;
  bool _saving = false;

  bool get _isEdit => widget.existingParticle != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingParticle;
    _ipaController = TextEditingController(text: p?.ipa ?? '');
    _meaningController = TextEditingController(text: p?.meaning ?? '');
    _glossTagController = TextEditingController(text: p?.glossTag ?? '');
    _selectedPos = p?.partOfSpeech;
  }

  @override
  void dispose() {
    _ipaController.dispose();
    _meaningController.dispose();
    _glossTagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) {
      setState(() => _saving = false);
      return;
    }

    final ipa = _ipaController.text.trim();
    final meaning = _meaningController.text.trim();
    final glossTag = _glossTagController.text.trim();
    final pos = _selectedPos;

    try {
      if (_isEdit) {
        final updated = widget.existingParticle!.copyWith(
          ipa: ipa,
          meaning: Value(meaning.isEmpty ? null : meaning),
          partOfSpeech: Value(pos),
          glossTag: Value(glossTag.isEmpty ? null : glossTag),
        );
        await dao.updateLexeme(updated);
      } else {
        await dao.insertLexeme(
          LexemesCompanion.insert(
            ipa: ipa,
            isClosedClass: const Value(true),
            meaning: Value(meaning.isEmpty ? null : meaning),
            partOfSpeech: Value(pos),
            glossTag: Value(glossTag.isEmpty ? null : glossTag),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posListAsync = ref.watch(posListProvider);
    final posList = posListAsync.asData?.value ?? const <PartsOfSpeechData>[];

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Particle' : 'Add Particle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IPA field with keyboard popup
              IpaTextField(
                controller: _ipaController,
                decoration: const InputDecoration(
                  labelText: 'IPA',
                  hintText: 'Enter IPA form',
                  border: OutlineInputBorder(),
                ),
                autofocus: !_isEdit,
              ),
              // IPA validation — checked manually below because IpaTextField
              // wraps a TextField (not TextFormField).
              const SizedBox(height: 16),

              // POS dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedPos,
                items: [
                  for (final p in posList)
                    DropdownMenuItem<String>(
                      value: p.name,
                      child: Text(p.name),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedPos = v),
                decoration: const InputDecoration(
                  labelText: 'Part of speech',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Gloss tag autocomplete — T-10-01/T-10-02: maxLength: 20
              Autocomplete<String>(
                initialValue: TextEditingValue(
                  text: _glossTagController.text,
                ),
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  if (query.isEmpty) return const Iterable<String>.empty();
                  return leipzigGlossAbbreviations.where(
                    (abbr) => abbr.toLowerCase().contains(query),
                  );
                },
                onSelected: (selection) {
                  _glossTagController.text = selection;
                },
                fieldViewBuilder: (
                  context,
                  fieldController,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  // Sync the external _glossTagController with the internal
                  // Autocomplete controller so we can read the value on save.
                  fieldController.addListener(() {
                    _glossTagController.text = fieldController.text;
                  });
                  return TextFormField(
                    controller: fieldController,
                    focusNode: focusNode,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Gloss tag',
                      hintText: 'e.g. NEG, DEF, PROG',
                      border: OutlineInputBorder(),
                      counterText: '', // hide the built-in maxLength counter
                    ),
                    validator: (v) {
                      if (v != null && v.length > 20) {
                        return 'Gloss tags must be 20 characters or fewer.';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Meaning field
              TextFormField(
                controller: _meaningController,
                decoration: const InputDecoration(
                  labelText: 'Meaning',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
          onPressed: _saving
              ? null
              : () async {
                  // Validate IPA manually (IpaTextField wraps a plain
                  // TextField, not a TextFormField).
                  if (_ipaController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('IPA form is required.'),
                      ),
                    );
                    return;
                  }
                  await _save();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
