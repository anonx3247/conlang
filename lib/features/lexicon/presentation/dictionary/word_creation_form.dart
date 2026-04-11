import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../data/lexeme_providers.dart';
import 'inspiration_panel.dart';

import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';

/// Inline form for adding a new word to the lexicon.
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

  /// True once the user has typed directly in the IPA field. Until then,
  /// the IPA field is auto-populated from the romanization field via
  /// [deromanizeProvider]. After the user overrides it manually, we stop
  /// rewriting it so their override sticks.
  bool _ipaManuallyEdited = false;

  /// Guards against reentrant listener callbacks during programmatic
  /// multi-field updates (e.g. tapping an InspirationPanel candidate, which
  /// sets both IPA and romanization in a single batch). While true, the
  /// controller listeners early-return so we don't treat our own writes as
  /// user edits.
  bool _updatingControllersProgrammatically = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillMeaning != null) {
      _meaningController.text = widget.prefillMeaning!;
    }
    _romanizationController.addListener(_onRomanizationChanged);
    _ipaController.addListener(_onIpaChanged);
  }

  @override
  void dispose() {
    _romanizationController.removeListener(_onRomanizationChanged);
    _ipaController.removeListener(_onIpaChanged);
    _ipaController.dispose();
    _romanizationController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  /// Called whenever the romanization field changes. Re-derives the IPA
  /// unless the user has manually edited it.
  void _onRomanizationChanged() {
    if (_updatingControllersProgrammatically) return;
    if (_ipaManuallyEdited) return;
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    if (_ipaController.text == derived) return;
    _updatingControllersProgrammatically = true;
    _ipaController.text = derived;
    _updatingControllersProgrammatically = false;
  }

  /// Called on ANY change to the IPA field. We only mark it as manually
  /// edited when the change wasn't driven by a programmatic update above.
  void _onIpaChanged() {
    if (_updatingControllersProgrammatically) return;
    // If the current IPA text matches what we'd derive from the romanization,
    // the "override" is identical to the default — treat it as not manual.
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    _ipaManuallyEdited = _ipaController.text != derived;
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
                    'New word',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- IPA / Romanization fields ---------------------------
                  // When romanization is enabled, the romanized form is the
                  // primary input — the IPA field is auto-populated via
                  // `deromanizeProvider` as the user types, and only needs
                  // manual entry when the pronunciation deviates from the
                  // orthography (e.g. irregular / loan words). The IPA field
                  // is labeled "IPA (override)" to signal this.
                  if (romanizationEnabled) ...[
                    // Romanization as primary input. The listener added in
                    // initState auto-derives IPA on every change, so we
                    // don't need an onChanged callback here beyond the
                    // implicit rebuild driven by the listener.
                    TextField(
                      controller: _romanizationController,
                      decoration: const InputDecoration(
                        labelText: 'Romanization *',
                        hintText: 'e.g. kala',
                        helperText: 'IPA is auto-derived from this',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    IpaTextField(
                      controller: _ipaController,
                      decoration: InputDecoration(
                        labelText: _ipaManuallyEdited
                            ? 'IPA (manual override)'
                            : 'IPA (auto-derived — edit to override)',
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
                            : const Text('New word'),
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
                // Treat a tapped candidate as a clean slate: neither field
                // is "manually edited" — both are consistent with whatever
                // the generator produced. Use the programmatic guard so
                // the listeners don't misclassify these writes as user
                // input and flip `_ipaManuallyEdited`.
                _updatingControllersProgrammatically = true;
                _ipaController.text = ipa;
                _ipaError = null;
                if (romanizationEnabled) {
                  final romanize = ref.read(romanizeProvider);
                  _romanizationController.text = romanize(ipa);
                }
                _ipaManuallyEdited = false;
                _updatingControllersProgrammatically = false;
              });
            },
          ),
        ),
      ],
    );
  }
}
