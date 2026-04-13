import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/allophone_providers.dart';
import '../../data/ipa_data.dart';
import '../../data/phoneme_providers.dart';
import '../../data/romanization_providers.dart';
import '../../domain/allophone_computer.dart';
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
  'affricate',
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
  'labial-velar',
  'labial-palatal',
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

// ---------------------------------------------------------------------------
// IPA symbol derivation from features
// ---------------------------------------------------------------------------

/// Maps manner string to [Manner] enum.
final _mannerMap = {
  'plosive': Manner.plosive,
  'nasal': Manner.nasal,
  'trill': Manner.trill,
  'tap/flap': Manner.tapOrFlap,
  'fricative': Manner.fricative,
  'lateral fricative': Manner.lateralFricative,
  'approximant': Manner.approximant,
  'lateral approximant': Manner.lateralApproximant,
  'affricate': Manner.affricate,
  'click': Manner.click,
  'implosive': Manner.implosive,
  'ejective': Manner.ejective,
};

/// Maps place string to [Place] enum.
final _placeMap = {
  'bilabial': Place.bilabial,
  'labiodental': Place.labiodental,
  'dental': Place.dental,
  'alveolar': Place.alveolar,
  'postalveolar': Place.postalveolar,
  'retroflex': Place.retroflex,
  'palatal': Place.palatal,
  'velar': Place.velar,
  'uvular': Place.uvular,
  'pharyngeal': Place.pharyngeal,
  'glottal': Place.glottal,
  'labial-velar': Place.labialVelar,
  'labial-palatal': Place.labialPalatal,
};

/// Maps height string to [VowelHeight] enum.
final _heightMap = {
  'close': VowelHeight.close,
  'near-close': VowelHeight.nearClose,
  'close-mid': VowelHeight.closeMid,
  'mid': VowelHeight.mid,
  'open-mid': VowelHeight.openMid,
  'near-open': VowelHeight.nearOpen,
  'open': VowelHeight.open,
};

/// Maps backness string to [VowelBackness] enum.
final _backnessMap = {
  'front': VowelBackness.front,
  'near-front': VowelBackness.nearFront,
  'central': VowelBackness.central,
  'near-back': VowelBackness.nearBack,
  'back': VowelBackness.back,
};

/// Reverse lookup: IPA symbol string -> (type, features).
///
/// Built once at startup from [IpaSound] static data.
final _symbolToFeatures = <
    String,
    ({
      String type,
      String? manner,
      String? place,
      String? voicing,
      String? height,
      String? backness,
      bool? rounded,
    })>{
  for (final s in [
    ...IpaSound.pulmonicConsonants,
    ...IpaSound.nonPulmonicConsonants,
  ])
    s.symbol: (
      type: 'consonant',
      manner: _mannerMap.entries
          .where((e) => e.value == s.manner)
          .firstOrNull
          ?.key,
      place:
          _placeMap.entries.where((e) => e.value == s.place).firstOrNull?.key,
      voicing: s.voiced == true
          ? 'voiced'
          : (s.voiced == false ? 'voiceless' : null),
      height: null,
      backness: null,
      rounded: null,
    ),
  for (final s in IpaSound.vowels)
    s.symbol: (
      type: 'vowel',
      manner: null,
      place: null,
      voicing: null,
      height: _heightMap.entries
          .where((e) => e.value == s.height)
          .firstOrNull
          ?.key,
      backness: _backnessMap.entries
          .where((e) => e.value == s.backness)
          .firstOrNull
          ?.key,
      rounded: s.rounded,
    ),
};

/// Derives the IPA symbol from selected consonant features.
///
/// Returns null if the combination doesn't match any known IPA sound.
String? _deriveConsonantSymbol({
  required String? manner,
  required String? place,
  required String? voicing,
}) {
  if (manner == null || place == null || voicing == null) return null;

  final m = _mannerMap[manner];
  final p = _placeMap[place];
  final voiced = voicing == 'voiced';

  if (m == null || p == null) return null;

  final allConsonants = [
    ...IpaSound.pulmonicConsonants,
    ...IpaSound.nonPulmonicConsonants,
  ];

  for (final sound in allConsonants) {
    if (sound.manner == m && sound.place == p && sound.voiced == voiced) {
      return sound.symbol;
    }
  }
  return null;
}

/// Derives the IPA symbol from selected vowel features.
///
/// Returns null if the combination doesn't match any known IPA sound.
String? _deriveVowelSymbol({
  required String? height,
  required String? backness,
  required bool rounded,
}) {
  if (height == null || backness == null) return null;

  final h = _heightMap[height];
  final b = _backnessMap[backness];

  if (h == null || b == null) return null;

  for (final sound in IpaSound.vowels) {
    if (sound.height == h && sound.backness == b && sound.rounded == rounded) {
      return sound.symbol;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------

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

  // Custom symbol controller (shown when derived symbol is null)
  late TextEditingController _customSymbolController;

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
    _customSymbolController = TextEditingController();
    if (p != null) {
      _type = p.type;
      _manner = p.manner;
      _place = p.place;
      _voicing = p.voicing;
      _height = p.height;
      _backness = p.backness;
      _rounded = p.rounded ?? false;

      // If editing, pre-fill the custom symbol field in case derived fails.
      _customSymbolController.text = p.symbol;
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _customSymbolController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.phoneme != null;

  /// Returns the derived IPA symbol based on current feature selections.
  String? get _derivedSymbol {
    if (_type == 'consonant') {
      return _deriveConsonantSymbol(
        manner: _manner,
        place: _place,
        voicing: _voicing,
      );
    } else {
      return _deriveVowelSymbol(
        height: _height,
        backness: _backness,
        rounded: _rounded,
      );
    }
  }

  /// The effective IPA symbol to save: derived (if known) or custom.
  String get _effectiveSymbol {
    // User-typed symbol takes priority — this preserves diacritics like ʰ, ː, ʷ
    // that the feature-based derivation cannot produce (e.g. pʰ vs p).
    final typed = _symbolController.text.trim();
    if (typed.isNotEmpty) return typed;
    final derived = _derivedSymbol;
    if (derived != null) return derived;
    return _customSymbolController.text.trim();
  }

  Future<void> _save() async {
    final symbol = _effectiveSymbol;
    if (symbol.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    final dao = ref.read(phonemeDaoProvider);
    if (dao == null) return;

    // Sync the internal symbol controller with effective symbol.
    _symbolController.text = symbol;

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        final updated = widget.phoneme!.copyWith(
          symbol: symbol,
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
          symbol: symbol,
          type: _type,
          manner: Value(_type == 'consonant' ? _manner : null),
          place: Value(_type == 'consonant' ? _place : null),
          voicing: Value(_type == 'consonant' ? _voicing : null),
          height: Value(_type == 'vowel' ? _height : null),
          backness: Value(_type == 'vowel' ? _backness : null),
          rounded: Value(_type == 'vowel' ? _rounded : null),
        );
        await dao.insertPhoneme(companion);

        // Prompt for romanization for new phonemes only.
        if (mounted) {
          await _promptRomanization(symbol);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Shows a dialog prompting the user to add a romanization for [symbol].
  ///
  /// Only shown when romanization is enabled and no mapping yet exists for the
  /// symbol. The user can skip or enter a Latin mapping and tap Add.
  Future<void> _promptRomanization(String symbol) async {
    // Check romanization enabled.
    final enabled = ref.read(romanizationEnabledProvider).asData?.value ?? true;
    if (!enabled) return;

    // Check if mapping already exists.
    final romanizationDao = ref.read(romanizationDaoProvider);
    if (romanizationDao == null) return;
    final existing = await romanizationDao.getAllMappings();
    if (existing.any((m) => m.ipaSymbol == symbol)) return;

    if (!mounted) return;

    final latinController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add romanization for /$symbol/?'),
        content: TextField(
          controller: latinController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Latin representation',
            hintText: 'e.g. sh, zh, ng',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final latin = latinController.text.trim();
      if (latin.isNotEmpty) {
        await romanizationDao.insertMapping(
          RomanizationMappingsCompanion.insert(
            ipaSymbol: symbol,
            latinMapping: latin,
          ),
        );
      }
    }

    latinController.dispose();
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    if (widget.phoneme == null) return;
    final navigator = Navigator.of(context);
    await confirmDeletePhoneme(context, ref, widget.phoneme!);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final derived = _derivedSymbol;

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
              // IPA symbol input — optional shortcut: typing a known symbol
              // auto-fills all feature dropdowns via reverse lookup.
              IpaTextField(
                controller: _symbolController,
                showIpaKeyboard: true,
                decoration: const InputDecoration(
                  labelText: 'IPA Symbol (optional)',
                  hintText: 'Type or paste, e.g. b, ʃ, ɑ',
                  helperText: 'Auto-fills features if recognized',
                ),
                onChanged: _onSymbolTyped,
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

              const SizedBox(height: 16),

              // Derived IPA symbol display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'IPA Symbol',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      derived ?? (derived == null && _featuresComplete ? '?' : '—'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: derived != null
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (derived == null && _featuresComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Unknown combination',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Custom symbol field — shown only when features are complete but
              // the combination isn't in the standard IPA set.
              if (derived == null && _featuresComplete) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customSymbolController,
                  decoration: const InputDecoration(
                    labelText: 'Custom IPA symbol',
                    hintText: 'Enter symbol manually',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],

              const SizedBox(height: 16),

              // Romanization info (read-only)
              _RomanizationInfo(
                phonemeSymbol: _effectiveSymbol.isNotEmpty
                    ? _effectiveSymbol
                    : (widget.phoneme?.symbol),
              ),

              // Phase 3.2 D-14 — computed allophones (empty when no rules).
              const SizedBox(height: 12),
              _AllophoneSection(
                phonemeSymbol: _effectiveSymbol.isNotEmpty
                    ? _effectiveSymbol
                    : (widget.phoneme?.symbol ?? ''),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _saving ? null : () => _confirmAndDelete(context),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        if (_isEditing) const Spacer(),
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

  /// True when all required feature dropdowns have been selected.
  bool get _featuresComplete {
    if (_type == 'consonant') {
      return _manner != null && _place != null && _voicing != null;
    } else {
      return _height != null && _backness != null;
    }
  }

  /// Called when the user types/pastes into the IPA symbol input field.
  ///
  /// If the trimmed value matches a known IPA sound, auto-fills the feature
  /// dropdowns via reverse lookup.
  void _onSymbolTyped(String value) {
    final trimmed = value.trim();
    // Try exact match first (e.g. 'ʃ'), then try base character for
    // diacritic-modified symbols (e.g. 'pʰ' → look up 'p' for features).
    var features = _symbolToFeatures[trimmed];
    if (features == null && trimmed.length > 1) {
      features = _symbolToFeatures[trimmed.characters.first];
    }
    if (features != null) {
      setState(() {
        _type = features!.type;
        _manner = features.manner;
        _place = features.place;
        _voicing = features.voicing;
        _height = features.height;
        _backness = features.backness;
        _rounded = features.rounded ?? false;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Romanization info widget
// ---------------------------------------------------------------------------

/// Shows the existing romanization mapping for a phoneme symbol (read-only).
class _RomanizationInfo extends ConsumerWidget {
  const _RomanizationInfo({required this.phonemeSymbol});

  final String? phonemeSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final symbol = phonemeSymbol;

    if (symbol == null || symbol.isEmpty) return const SizedBox.shrink();

    final mappingsAsync = ref.watch(romanizationMappingsProvider);

    return mappingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (mappings) {
        final match = mappings.where((m) => m.ipaSymbol == symbol).firstOrNull;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Romanization: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (match != null)
                Text(
                  match.latinMapping,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                )
              else
                Text(
                  'No romanization defined',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Confirm delete helper
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Allophone section — Phase 3.2 D-14
// ---------------------------------------------------------------------------

/// Test-only access to the private [_AllophoneSection] widget.
@visibleForTesting
Widget buildAllophoneSectionForTesting(String symbol) =>
    _AllophoneSection(phonemeSymbol: symbol);

/// Displays the computed allophone realizations for [phonemeSymbol] in D-19
/// format (`/underlying/ → [r1, r2, ...]`).
///
/// Watches [allophoneMapProvider] so the section updates live whenever
/// rewrite rules, the phoneme inventory, or natural class definitions
/// change. Renders nothing when the phoneme has no matching rules
/// (D-18 empty state).
class _AllophoneSection extends ConsumerWidget {
  const _AllophoneSection({required this.phonemeSymbol});

  final String phonemeSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (phonemeSymbol.isEmpty) return const SizedBox.shrink();

    final allophoneMap = ref.watch(allophoneMapProvider);
    final realizations =
        allophoneMap[phonemeSymbol] ?? const <AllophoneRealization>[];

    // D-18 — empty state renders nothing.
    if (realizations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // D-19 format: /underlying/ → [r1, r2, ...] (comma + space separator).
    final realizationText = realizations.map((r) => r.output).join(', ');

    return Container(
      key: const ValueKey('allophone-section'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Allophones: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Text(
              '/$phonemeSymbol/ → [$realizationText]',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
