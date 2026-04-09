import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phoneme_providers.dart';
import '../shared/ipa_keyboard/ipa_text_field.dart';

// ---------------------------------------------------------------------------
// Consonant articulation options
// ---------------------------------------------------------------------------

const _mannerOptions = [
  'plosive',
  'nasal',
  'trill',
  'tap/flap',
  'fricative',
  'lateral fricative',
  'approximant',
  'lateral approximant',
  'click',
  'implosive',
  'ejective',
];

const _placeOptions = [
  'bilabial',
  'labiodental',
  'dental',
  'alveolar',
  'postalveolar',
  'retroflex',
  'palatal',
  'velar',
  'uvular',
  'pharyngeal',
  'glottal',
];

const _voicingOptions = ['voiced', 'voiceless'];

// ---------------------------------------------------------------------------
// Vowel articulation options
// ---------------------------------------------------------------------------

const _heightOptions = [
  'close',
  'near-close',
  'close-mid',
  'mid',
  'open-mid',
  'near-open',
  'open',
];

const _backnessOptions = ['front', 'near-front', 'central', 'near-back', 'back'];

/// Dialog for creating or editing a phoneme.
///
/// Pass [phoneme] to open in edit mode; leave null to open in create mode.
class PhonemeEditDialog extends ConsumerStatefulWidget {
  const PhonemeEditDialog({super.key, this.phoneme});

  /// When provided, the dialog opens in edit mode pre-filled with this phoneme.
  final Phoneme? phoneme;

  @override
  ConsumerState<PhonemeEditDialog> createState() => _PhonemeEditDialogState();
}

class _PhonemeEditDialogState extends ConsumerState<PhonemeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _symbolController;

  String _type = 'consonant';

  // Consonant properties
  String? _manner;
  String? _place;
  String? _voicing;

  // Vowel properties
  String? _height;
  String? _backness;
  bool _rounded = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.phoneme;
    _symbolController = TextEditingController(text: p?.symbol ?? '');
    if (p != null) {
      _type = p.type;
      _manner = p.manner;
      _place = p.place;
      _voicing = p.voicing;
      _height = p.height;
      _backness = p.backness;
      _rounded = p.rounded ?? false;
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.phoneme != null;

  Future<void> _save() async {
    if (_symbolController.text.trim().isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    final dao = ref.read(phonemeDaoProvider);
    if (dao == null) return;

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        final updated = widget.phoneme!.copyWith(
          symbol: _symbolController.text.trim(),
          type: _type,
          manner: Value(_type == 'consonant' ? _manner : null),
          place: Value(_type == 'consonant' ? _place : null),
          voicing: Value(_type == 'consonant' ? _voicing : null),
          height: Value(_type == 'vowel' ? _height : null),
          backness: Value(_type == 'vowel' ? _backness : null),
          rounded: Value(_type == 'vowel' ? _rounded : null),
        );
        await dao.updatePhoneme(updated);
      } else {
        final companion = PhonemesCompanion.insert(
          symbol: _symbolController.text.trim(),
          type: _type,
          manner: Value(_type == 'consonant' ? _manner : null),
          place: Value(_type == 'consonant' ? _place : null),
          voicing: Value(_type == 'consonant' ? _voicing : null),
          height: Value(_type == 'vowel' ? _height : null),
          backness: Value(_type == 'vowel' ? _backness : null),
          rounded: Value(_type == 'vowel' ? _rounded : null),
        );
        await dao.insertPhoneme(companion);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Phoneme' : 'Add Phoneme'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IPA symbol field
              IpaTextField(
                controller: _symbolController,
                decoration: const InputDecoration(
                  labelText: 'IPA Symbol',
                  hintText: 'e.g. p, b, ɸ, ʃ',
                ),
              ),
              const SizedBox(height: 16),

              // Type selector
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'consonant', child: Text('Consonant')),
                  DropdownMenuItem(value: 'vowel', child: Text('Vowel')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'consonant'),
              ),
              const SizedBox(height: 16),

              // Consonant fields
              if (_type == 'consonant') ...[
                DropdownButtonFormField<String>(
                  value: _manner,
                  decoration: const InputDecoration(
                    labelText: 'Manner of Articulation',
                  ),
                  items: _mannerOptions
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m[0].toUpperCase() + m.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _manner = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _place,
                  decoration: const InputDecoration(
                    labelText: 'Place of Articulation',
                  ),
                  items: _placeOptions
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p[0].toUpperCase() + p.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _place = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _voicing,
                  decoration: const InputDecoration(labelText: 'Voicing'),
                  items: _voicingOptions
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v[0].toUpperCase() + v.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _voicing = v),
                ),
              ],

              // Vowel fields
              if (_type == 'vowel') ...[
                DropdownButtonFormField<String>(
                  value: _height,
                  decoration: const InputDecoration(labelText: 'Vowel Height'),
                  items: _heightOptions
                      .map(
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(h[0].toUpperCase() + h.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _height = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _backness,
                  decoration: const InputDecoration(labelText: 'Backness'),
                  items: _backnessOptions
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(b[0].toUpperCase() + b.substring(1)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _backness = v),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Rounded'),
                  value: _rounded,
                  onChanged: (v) => setState(() => _rounded = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// Confirms deletion of a phoneme and deletes it from the DAO.
Future<void> confirmDeletePhoneme(
  BuildContext context,
  WidgetRef ref,
  Phoneme phoneme,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Phoneme'),
      content: Text(
        'Remove /${phoneme.symbol}/ from the inventory? '
        'Any natural classes referencing this phoneme will lose this member.',
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
    final dao = ref.read(phonemeDaoProvider);
    await dao?.deletePhoneme(phoneme.id);
  }
}
