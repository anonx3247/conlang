import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/ipa_data.dart';
import '../../data/phoneme_providers.dart';
import '../../data/romanization_bijection.dart';
import '../../data/romanization_dao.dart';
import '../../data/romanization_providers.dart';
import '../shared/ipa_keyboard/ipa_text_field.dart';

/// Two-column editable table for defining Latin letter → IPA romanization mappings.
///
/// Each row shows one mapping with inline edit and delete controls. An "Add
/// letter" button at the bottom lets users create new entries.
///
/// Columns are Latin-first: the Latin letter (romanization key) appears in the
/// first column, and the associated IPA sound in the second. This matches the
/// mental model of "I write 'sh', which sounds like /ʃ/".
///
/// Mappings are project-scoped and persisted in the project SQLite database via
/// [RomanizationDao]. The section is self-contained — it can be dropped into
/// any scrollable parent.
class RomanizationSection extends ConsumerStatefulWidget {
  const RomanizationSection({super.key});

  @override
  ConsumerState<RomanizationSection> createState() =>
      _RomanizationSectionState();
}

class _RomanizationSectionState extends ConsumerState<RomanizationSection> {
  // Row-level state: which row is being edited (by mapping id, or -1 for new).
  int? _editingId;

  // Controllers for the inline editing fields.
  final _ipaController = TextEditingController();
  final _latinController = TextEditingController();

  @override
  void dispose() {
    _ipaController.dispose();
    _latinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RomanizationDao? get _dao => ref.read(romanizationDaoProvider);

  void _startEdit(RomanizationMapping mapping) {
    setState(() {
      _editingId = mapping.id;
      _latinController.text = mapping.latinMapping;
      _ipaController.text = mapping.ipaSymbol;
    });
  }

  void _startAdd() {
    setState(() {
      _editingId = -1; // sentinel: new row
      _latinController.clear();
      _ipaController.clear();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _latinController.clear();
      _ipaController.clear();
    });
  }

  Future<void> _saveEdit(RomanizationMapping? existing) async {
    final ipa = _ipaController.text.trim();
    final latin = _latinController.text.trim();
    if (ipa.isEmpty || latin.isEmpty) return;

    final dao = _dao;
    if (dao == null) return;

    // Plan 04-15 D-72 dry-run bijection check: build the PROPOSED mapping
    // set (current rows with the edit applied) and validate it before
    // touching the database. If any violation involves the proposed row
    // (by content — the staged row has no id yet when inserting), block
    // the save and surface the violation detail via a SnackBar.
    final currentRows = await dao.getAllMappings();
    final proposedRows = <RomanizationMapping>[];
    if (existing == null) {
      proposedRows
        ..addAll(currentRows)
        ..add(RomanizationMapping(
          id: -1, // sentinel: new row
          ipaSymbol: ipa,
          latinMapping: latin,
        ));
    } else {
      for (final row in currentRows) {
        if (row.id == existing.id) {
          proposedRows.add(
              row.copyWith(ipaSymbol: ipa, latinMapping: latin));
        } else {
          proposedRows.add(row);
        }
      }
    }
    final violations = validateMappingsBijection(proposedRows);
    if (violations.isNotEmpty) {
      final blocker = violations.first;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Romanization bijection conflict: ${blocker.detail}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (existing == null) {
      // Insert new mapping.
      await dao.insertMapping(
        RomanizationMappingsCompanion.insert(
          ipaSymbol: ipa,
          latinMapping: latin,
        ),
      );

      // Auto-create the phoneme if not already in inventory.
      await _autoCreatePhoneme(ipa);
    } else {
      // Update existing mapping.
      await dao.updateMapping(
        existing.copyWith(ipaSymbol: ipa, latinMapping: latin),
      );
    }

    _cancelEdit();
  }

  /// Auto-creates a phoneme for [ipaSymbol] if not already in the inventory.
  ///
  /// Looks up [IpaSound] static data for feature pre-filling. Shows a SnackBar
  /// to inform the user when a phoneme is created.
  Future<void> _autoCreatePhoneme(String ipaSymbol) async {
    // Check if phoneme already exists.
    final existingPhonemes = ref.read(allPhonemesProvider).asData?.value ?? [];
    if (existingPhonemes.any((p) => p.symbol == ipaSymbol)) return;

    final phonemeDao = ref.read(phonemeDaoProvider);
    if (phonemeDao == null) return;

    // Look up IPA sound data to pre-fill features.
    final allConsonants = [
      ...IpaSound.pulmonicConsonants,
      ...IpaSound.nonPulmonicConsonants,
    ];

    final consonantMatch =
        allConsonants.where((s) => s.symbol == ipaSymbol).firstOrNull;
    final vowelMatch =
        IpaSound.vowels.where((s) => s.symbol == ipaSymbol).firstOrNull;

    PhonemesCompanion companion;

    if (consonantMatch != null) {
      final s = consonantMatch;
      final manner = _mannerToString(s.manner);
      final place = _placeToString(s.place);
      final voicing = s.voiced == true
          ? 'voiced'
          : (s.voiced == false ? 'voiceless' : null);
      companion = PhonemesCompanion.insert(
        symbol: ipaSymbol,
        type: 'consonant',
        manner: Value(manner),
        place: Value(place),
        voicing: Value(voicing),
      );
    } else if (vowelMatch != null) {
      final s = vowelMatch;
      companion = PhonemesCompanion.insert(
        symbol: ipaSymbol,
        type: 'vowel',
        height: Value(_heightToString(s.height)),
        backness: Value(_backnessToString(s.backness)),
        rounded: Value(s.rounded),
      );
    } else {
      // Unknown symbol: create with consonant type, null features.
      companion = PhonemesCompanion.insert(
        symbol: ipaSymbol,
        type: 'consonant',
      );
    }

    await phonemeDao.insertPhoneme(companion);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phoneme /$ipaSymbol/ added to inventory')),
      );
    }
  }

  static String? _mannerToString(Manner? manner) => switch (manner) {
        Manner.plosive => 'plosive',
        Manner.nasal => 'nasal',
        Manner.trill => 'trill',
        Manner.tapOrFlap => 'tap/flap',
        Manner.fricative => 'fricative',
        Manner.lateralFricative => 'lateral fricative',
        Manner.approximant => 'approximant',
        Manner.lateralApproximant => 'lateral approximant',
        Manner.click => 'click',
        Manner.implosive => 'implosive',
        Manner.ejective => 'ejective',
        null => null,
      };

  static String? _placeToString(Place? place) => switch (place) {
        Place.bilabial => 'bilabial',
        Place.labiodental => 'labiodental',
        Place.dental => 'dental',
        Place.alveolar => 'alveolar',
        Place.postalveolar => 'postalveolar',
        Place.retroflex => 'retroflex',
        Place.palatal => 'palatal',
        Place.velar => 'velar',
        Place.uvular => 'uvular',
        Place.pharyngeal => 'pharyngeal',
        Place.glottal => 'glottal',
        Place.palatoalveolar => 'postalveolar',
        Place.alveolarlateral => 'alveolar',
        null => null,
      };

  static String? _heightToString(VowelHeight? height) => switch (height) {
        VowelHeight.close => 'close',
        VowelHeight.nearClose => 'near-close',
        VowelHeight.closeMid => 'close-mid',
        VowelHeight.mid => 'mid',
        VowelHeight.openMid => 'open-mid',
        VowelHeight.nearOpen => 'near-open',
        VowelHeight.open => 'open',
        null => null,
      };

  static String? _backnessToString(VowelBackness? backness) => switch (backness) {
        VowelBackness.front => 'front',
        VowelBackness.nearFront => 'near-front',
        VowelBackness.central => 'central',
        VowelBackness.nearBack => 'near-back',
        VowelBackness.back => 'back',
        null => null,
      };

  Future<void> _deleteMapping(int id) async {
    await _dao?.deleteMapping(id);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final enabledAsync = ref.watch(romanizationEnabledProvider);
    final mappingsAsync = ref.watch(romanizationMappingsProvider);

    final enabled = enabledAsync.asData?.value ?? true;

    return mappingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (mappings) =>
          _buildContent(context, theme, colorScheme, mappings, enabled),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
    bool enabled,
  ) {
    // Plan 04-15 D-72: non-dismissible banner when the active mapping set
    // has bijection violations. Rule DSL editing must be treated as locked
    // until the user fixes the conflict. The banner lives inside this
    // section because the section already owns the mapping list and is
    // the natural place for the user to resolve the issue.
    final bijectionAsync = ref.watch(bijectionStatusProvider);
    final violations = bijectionAsync.asData?.value ?? const <BijectionViolation>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (violations.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              border: Border.all(color: colorScheme.error),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Romanization bijection conflict '
                        '(${violations.length} issue${violations.length == 1 ? '' : 's'})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final v in violations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${v.detail}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Rule DSL editing is blocked until these conflicts are resolved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        // Section header with toggle.
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Romanization',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Latin letters \u2192 IPA sounds)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              Text(
                'Enabled',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: enabled,
                onChanged: (val) => setRomanizationEnabled(ref, val),
              ),
            ],
          ),
        ),

        // Content: hidden when disabled.
        if (!enabled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Romanization is disabled for this project.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          // Table.
          if (mappings.isEmpty && _editingId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No romanization letters defined yet. Add a Latin letter and associate its default IPA sound.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            _buildTable(context, theme, colorScheme, mappings),

          const SizedBox(height: 8),

          // Add letter button.
          if (_editingId == null)
            TextButton.icon(
              onPressed: _startAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add letter'),
            ),
        ],
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<RomanizationMapping> mappings,
  ) {
    return Column(
      children: [
        // Header row.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  'Latin letter',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'IPA sound (default)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 80), // Space for action buttons.
            ],
          ),
        ),

        // Existing mapping rows.
        ...mappings.map((mapping) => _buildMappingRow(
              context,
              theme,
              colorScheme,
              mapping,
            )),

        // New mapping row (when adding).
        if (_editingId == -1)
          _buildEditRow(context, theme, colorScheme, null),
      ],
    );
  }

  Widget _buildMappingRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RomanizationMapping mapping,
  ) {
    final isEditing = _editingId == mapping.id;

    if (isEditing) {
      return _buildEditRow(context, theme, colorScheme, mapping);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _startEdit(mapping),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Latin letter — normal font (first column)
              SizedBox(
                width: 160,
                child: Text(
                  mapping.latinMapping,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              // IPA sound — monospace with primary color (second column)
              Expanded(
                child: Text(
                  mapping.ipaSymbol,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
              ),
              // Edit / Delete buttons.
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit',
                      onPressed: () => _startEdit(mapping),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _deleteMapping(mapping.id),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RomanizationMapping? existing,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Latin letter input (first column — plain TextField, no IPA keyboard).
          SizedBox(
            width: 152,
            child: TextField(
              controller: _latinController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'sh',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodyMedium,
              onSubmitted: (_) => _saveEdit(existing),
            ),
          ),

          const SizedBox(width: 8),

          // IPA sound input (second column — IpaTextField with IPA keyboard).
          Expanded(
            child: IpaTextField(
              controller: _ipaController,
              decoration: const InputDecoration(
                hintText: '/ʃ/',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              onSubmitted: (_) => _saveEdit(existing),
            ),
          ),

          const SizedBox(width: 8),

          // Save / Cancel.
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.check,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Save',
                  onPressed: () => _saveEdit(existing),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Cancel',
                  onPressed: _cancelEdit,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
