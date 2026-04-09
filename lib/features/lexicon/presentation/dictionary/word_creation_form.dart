import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../data/lexeme_providers.dart';
import 'inspiration_panel.dart';

import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';

/// Inline form for adding a new root word to the lexicon.
///
/// Layout: Row with form on the left (~60%) and [InspirationPanel] on the
/// right (~40%). The right panel lets users click candidate words to fill
/// the IPA field (D-08).
///
/// When [prefillMeaning] is provided (from Swadesh / Thesaurus "Add word"
/// navigation via `?create=true&meaning=X`), the meaning field is pre-filled
/// on first build (D-16).
class WordCreationForm extends ConsumerStatefulWidget {
  const WordCreationForm({
    super.key,
    required this.onCancel,
    required this.onSaved,
    this.prefillMeaning,
  });

  final VoidCallback onCancel;
  final VoidCallback onSaved;

  /// When non-null, pre-fills the meaning field on first build.
  final String? prefillMeaning;

  @override
  ConsumerState<WordCreationForm> createState() => _WordCreationFormState();
}

class _WordCreationFormState extends ConsumerState<WordCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _ipaController = TextEditingController();
  final _romanizationController = TextEditingController();
  final _meaningController = TextEditingController();
  String? _selectedPos;
  bool _saving = false;
  String? _ipaError;

  @override
  void initState() {
    super.initState();
    if (widget.prefillMeaning != null) {
      _meaningController.text = widget.prefillMeaning!;
    }
  }

  @override
  void dispose() {
    _ipaController.dispose();
    _romanizationController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ipa = _ipaController.text.trim();
    if (ipa.isEmpty) {
      setState(() => _ipaError = 'IPA is required');
      return;
    }
    setState(() {
      _ipaError = null;
      _saving = true;
    });

    try {
      final dao = ref.read(lexemeDaoProvider);
      if (dao == null) return;

      await dao.insertLexeme(
        LexemesCompanion(
          ipa: Value(ipa),
          romanization: Value(_romanizationController.text.trim().isEmpty
              ? null
              : _romanizationController.text.trim()),
          meaning: Value(_meaningController.text.trim().isEmpty
              ? null
              : _meaningController.text.trim()),
          partOfSpeech: Value(_selectedPos),
        ),
      );
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final romanizationEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? false;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Form (left ~60%) -----------------------------------------------
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add root word',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- IPA / Romanization fields ---------------------------
                  if (romanizationEnabled) ...[
                    // Romanization as primary input
                    TextField(
                      controller: _romanizationController,
                      decoration: const InputDecoration(
                        labelText: 'Romanization',
                        hintText: 'e.g. kala',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    IpaTextField(
                      controller: _ipaController,
                      decoration: InputDecoration(
                        labelText: 'IPA',
                        hintText: 'e.g. /kala/',
                        errorText: _ipaError,
                      ),
                      onChanged: (_) => setState(() => _ipaError = null),
                    ),
                  ] else ...[
                    // IPA as primary input
                    IpaTextField(
                      controller: _ipaController,
                      decoration: InputDecoration(
                        labelText: 'IPA *',
                        hintText: 'e.g. /kala/',
                        errorText: _ipaError,
                      ),
                      onChanged: (_) => setState(() => _ipaError = null),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ---- Meaning field --------------------------------------
                  TextField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Meaning',
                      hintText: 'e.g. water, to run',
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ---- POS dropdown --------------------------------------
                  if (posList.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedPos,
                      decoration: const InputDecoration(
                        labelText: 'Part of speech',
                      ),
                      hint: const Text('Select POS (optional)'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('— none —'),
                        ),
                        ...posList.map(
                          (pos) => DropdownMenuItem<String>(
                            value: pos.name,
                            child: Text(pos.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedPos = val),
                    ),

                  if (_ipaError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _ipaError!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: cs.error,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ---- Action buttons ------------------------------------
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Add root'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- Inspiration panel (right ~40%) --------------------------------
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: cs.outlineVariant,
        ),
        Expanded(
          flex: 4,
          child: InspirationPanel(
            onWordSelected: (ipa) {
              setState(() {
                _ipaController.text = ipa;
                _ipaError = null;
                // If romanization is enabled, also auto-fill romanization
                // using the current romanize function
                if (romanizationEnabled) {
                  final romanize = ref.read(romanizeProvider);
                  _romanizationController.text = romanize(ipa);
                }
              });
            },
          ),
        ),
      ],
    );
  }
}
