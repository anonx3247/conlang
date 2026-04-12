import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../grammar/data/intrinsic_levels_codec.dart';
import '../../../grammar/data/standard_form_validation_provider.dart';
import '../../../grammar/domain/dimension_level.dart';
import '../../../grammar/domain/pos_resolver.dart';
import '../../../grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/phonotactic_validation_provider.dart';
import '../../../phonology/data/phonotactic_providers.dart'
    show applyRewritePipelineProvider;
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/word_generator.dart' show ValidationResult;
import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../data/lexeme_providers.dart';
import 'derivation_tree_widget.dart';

/// Detail panel shown on the right side of the Dictionary master-detail layout.
///
/// Displays the word's IPA, romanization (if enabled), meaning, POS, derivation
/// tree (computed on-the-fly via MorphologyEngine), and exception management UI.
///
/// Supports inline editing and delete with confirmation (per D-04, D-20, D-21).
class WordDetailPanel extends ConsumerStatefulWidget {
  const WordDetailPanel({
    super.key,
    required this.lexemeId,
    required this.onDeleted,
  });

  final int lexemeId;
  final VoidCallback onDeleted;

  @override
  ConsumerState<WordDetailPanel> createState() => _WordDetailPanelState();
}

class _WordDetailPanelState extends ConsumerState<WordDetailPanel> {
  bool _isEditing = false;

  // Edit-mode controllers
  final _ipaController = TextEditingController();
  final _romanizationController = TextEditingController();
  final _meaningController = TextEditingController();
  String? _editPos;

  /// D-92 / D-93 (plan 04-17 Task 7) — per-intrinsic-dim level selection
  /// for the currently-selected POS. Key = dimension id, value = selected
  /// level id (null until the user picks one). On POS change, we preserve
  /// entries whose dim ids overlap the new POS's intrinsic dims via
  /// [IntrinsicLevelsCodec.decode] of the stored lexeme json; dim ids
  /// absent from the new POS are silently dropped at save time because
  /// they are not keys in this map.
  final Map<int, int?> _intrinsicLevelSelections = <int, int?>{};

  /// D-92 — per-dim validation error keyed by dimension id. Non-null
  /// entries are rendered as red helper text under the dropdown and
  /// block save.
  final Map<int, String?> _intrinsicLevelErrors = <int, String?>{};

  /// D-93 — snapshot of the lexeme's decoded intrinsic levels at the time
  /// editing started. Used by the Builder sub-form to seed overlap
  /// preservation when the user changes POS: any dim id present in both
  /// the old json and the new POS's intrinsic set is pre-filled.
  Map<int, int> _storedIntrinsicLevels = const {};

  /// D-93 — set to true whenever the user changes POS via the dropdown in
  /// edit mode. The Builder sub-form uses this flag to auto-populate
  /// `_intrinsicLevelSelections` from [_storedIntrinsicLevels] on the
  /// first render after the POS change, then resets the flag.
  bool _posJustChanged = false;

  /// Mirrors [WordCreationForm]: true when the user has manually edited the
  /// IPA field since the last programmatic sync. Initialized by
  /// [_startEditing] from whether the loaded lexeme's stored IPA diverges
  /// from what `deromanize(romanization)` would produce.
  bool _ipaManuallyEdited = false;

  /// Reentrancy guard for programmatic multi-field updates.
  bool _updatingControllersProgrammatically = false;

  @override
  void initState() {
    super.initState();
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

  void _onRomanizationChanged() {
    if (!_isEditing) return;
    if (_updatingControllersProgrammatically) return;
    if (_ipaManuallyEdited) return;
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    if (_ipaController.text == derived) return;
    _updatingControllersProgrammatically = true;
    _ipaController.text = derived;
    _updatingControllersProgrammatically = false;
  }

  void _onIpaChanged() {
    if (!_isEditing) return;
    if (_updatingControllersProgrammatically) return;
    final deromanize = ref.read(deromanizeProvider);
    final derived = deromanize(_romanizationController.text);
    _ipaManuallyEdited = _ipaController.text != derived;
    // Rebuild so the IPA field label updates to reflect override state.
    if (mounted) setState(() {});
  }

  void _startEditing(Lexeme lexeme) {
    _updatingControllersProgrammatically = true;
    _ipaController.text = lexeme.ipa;
    _romanizationController.text = lexeme.romanization ?? '';
    _meaningController.text = lexeme.meaning ?? '';
    _editPos = lexeme.partOfSpeech;
    // Seed the manual-edit flag from whether the stored IPA diverges from
    // the orthography-derived form. A word loaded with a manual override
    // should stay overridden unless the user explicitly re-derives it.
    final deromanize = ref.read(deromanizeProvider);
    _ipaManuallyEdited = isIpaManuallyOverridden(
      lexeme.ipa,
      lexeme.romanization,
      deromanize,
    );
    // D-92 / D-93 — decode the stored intrinsic levels json into our
    // state map AND store a snapshot for overlap preservation.
    _storedIntrinsicLevels =
        IntrinsicLevelsCodec.decode(lexeme.intrinsicLevelsJson);
    _intrinsicLevelSelections
      ..clear()
      ..addAll(_storedIntrinsicLevels
          .map<int, int?>((k, v) => MapEntry(k, v)));
    _intrinsicLevelErrors.clear();
    _posJustChanged = false;
    _updatingControllersProgrammatically = false;
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit(Lexeme lexeme) async {
    final ipa = _ipaController.text.trim();
    if (ipa.isEmpty) return;
    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) return;

    // D-92 / D-93 (plan 04-17 Task 7) — resolve the currently-selected
    // POS, look up its intrinsic dims, and block save if any required
    // intrinsic dim has a null selection. The validator copy lives next
    // to the dropdown (`Required — every {posName} must have a fixed
    // {dim.name}.`) but we rebuild the error map here so a direct Save
    // tap also surfaces the same state.
    final posList =
        ref.read(posListProvider).asData?.value ?? const <PartsOfSpeechData>[];
    PartsOfSpeechData? selectedPos;
    if (_editPos != null) {
      for (final p in posList) {
        if (p.name == _editPos) {
          selectedPos = p;
          break;
        }
      }
    }
    Map<int, int> encodedLevels = const {};
    if (selectedPos != null) {
      // Use the synchronously-cached .asData (the Builder sub-form is
      // already watching this provider, so the stream has resolved).
      final dims = ref
              .read(dimensionsForPosProvider(selectedPos.id))
              .asData
              ?.value ??
          const <Dimension>[];
      final intrinsicDims = dims.where((d) => d.intrinsic).toList();
      _intrinsicLevelErrors.clear();
      var anyMissing = false;
      for (final dim in intrinsicDims) {
        final current = _intrinsicLevelSelections[dim.id];
        if (current == null) {
          _intrinsicLevelErrors[dim.id] =
              'Required — every ${selectedPos.name} must have a '
              'fixed ${dim.name}.';
          anyMissing = true;
        }
      }
      if (anyMissing) {
        setState(() {});
        return;
      }
      // Build the encoded map — only entries whose dim id is in the
      // current POS's intrinsic dim set, so old-POS-only entries are
      // silently dropped per D-93.
      encodedLevels = {
        for (final dim in intrinsicDims)
          dim.id: _intrinsicLevelSelections[dim.id]!,
      };
    }
    final encoded = IntrinsicLevelsCodec.encode(encodedLevels);

    await dao.updateLexeme(
      lexeme.copyWith(
        ipa: ipa,
        romanization: Value(_romanizationController.text.trim().isEmpty
            ? null
            : _romanizationController.text.trim()),
        meaning: Value(_meaningController.text.trim().isEmpty
            ? null
            : _meaningController.text.trim()),
        partOfSpeech: Value(_editPos),
        intrinsicLevelsJson: Value(encoded),
      ),
    );
    setState(() => _isEditing = false);
  }

  Future<void> _confirmDelete(BuildContext context, Lexeme lexeme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete word?'),
        content: Text(
          'Delete "${lexeme.ipa}"? This will also remove all derived forms '
          'cached from this root. This cannot be undone.',
        ),
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
    );

    if (confirmed == true) {
      final dao = ref.read(lexemeDaoProvider);
      await dao?.deleteLexeme(lexeme.id);
      widget.onDeleted();
    }
  }

  Future<void> _addException(
      BuildContext context, int lexemeId, Lexeme lexeme) async {
    final rulesAsync = ref.read(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? [];
    if (rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No morphological rules defined yet.')),
      );
      return;
    }

    int? selectedRuleId = rules.first.id;
    String selectedRuleSource = rules.first.source;
    final overrideController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add exception'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedRuleId,
                decoration: const InputDecoration(labelText: 'Rule'),
                items: rules.map((r) {
                  return DropdownMenuItem<int>(
                    value: r.id,
                    child: Text(r.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedRuleId = val;
                    selectedRuleSource =
                        rules.firstWhere((r) => r.id == val).source;
                  });
                },
              ),
              const SizedBox(height: 12),
              IpaTextField(
                controller: overrideController,
                decoration: const InputDecoration(
                  labelText: 'Override form',
                  hintText: 'Irregular form (IPA)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final override = overrideController.text.trim();
                if (override.isEmpty || selectedRuleId == null) return;
                final dao = ref.read(lexemeDaoProvider);
                await dao?.insertException(
                  MorphologicalRuleExceptionsCompanion(
                    lexemeId: Value(lexemeId),
                    ruleId: Value(selectedRuleId!),
                    overrideForm: Value(override),
                    ruleSourceSnapshot: Value(selectedRuleSource),
                  ),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    overrideController.dispose();
  }

  Future<void> _confirmDeleteException(
      BuildContext context, MorphologicalRuleException exception) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove exception?'),
        content: const Text(
          'Remove this exception? The rule will apply to this word again.',
        ),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dao = ref.read(lexemeDaoProvider);
      await dao?.deleteException(exception.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final lexemeAsync = ref.watch(lexemeByIdProvider(widget.lexemeId));

    return lexemeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (lexeme) {
        if (lexeme == null) {
          return Center(
            child: Text(
              'Word not found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        if (_isEditing) {
          return _buildEditMode(context, theme, cs, lexeme);
        }

        return _buildViewMode(context, theme, cs, lexeme);
      },
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Lexeme lexeme,
  ) {
    final romanizationEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? false;
    final exceptionsAsync =
        ref.watch(exceptionsForLexemeProvider(widget.lexemeId));
    final exceptions = exceptionsAsync.asData?.value ?? [];
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? [];

    // Build rule name map for exception display
    final ruleNameMap = {for (final r in rules) r.id: r.name};

    // G-68 (wave 3a-bis): for promoted derivations the stored ipa is a
    // placeholder equal to the parent's ipa — resolve the real displayed
    // rom/ipa via `promotedDerivedFormProvider`. All header widgets and
    // phonotactic validation below go through `display.ipa` / `display.rom`.
    final promoted = ref.watch(promotedDerivedFormProvider(lexeme.id));
    final display = resolveDisplayForms(lexeme, promoted);

    // Phonotactic validation against the displayed form (derived for promoted
    // rows, stored otherwise) so violations match what the user actually sees.
    // D-99 -- 04-17: combine phonotactic + standard-form violations.
    final validate = ref.watch(phonotacticValidatorProvider);
    final phonoValidation = validate(word: display.ipa);
    final sfViolations = ref.watch(standardFormViolationsProvider(lexeme.id)).asData?.value ?? const [];
    final validation = ValidationResult(violations: [
      ...phonoValidation.violations,
      ...sfViolations,
    ]);
    final hasViolations = !validation.isValid;

    // Visual flag: IPA is a manual override if it diverges from what
    // deromanize(romanization) would produce. When true, the IPA is
    // rendered in a distinct color so the user can spot irregular
    // pronunciations at a glance. Promoted rows never trigger this — their
    // stored fields are placeholders, not user overrides.
    final deromanize = ref.watch(deromanizeProvider);
    final ipaOverridden = promoted == null &&
        isIpaManuallyOverridden(
          lexeme.ipa,
          lexeme.romanization,
          deromanize,
        );
    final ipaOverrideColor = Colors.orange.shade300;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header: IPA / romanization + actions ----------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (romanizationEnabled &&
                        (promoted != null ||
                            (lexeme.romanization != null &&
                                lexeme.romanization!.isNotEmpty))) ...[
                      // Romanization as primary heading (G-68: derived form
                      // for promoted rows, stored rom otherwise)
                      Text(
                        display.rom,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // IPA sub-label with violation highlighting (unless
                      // exception). When the IPA is a manual override, tint
                      // it in `ipaOverrideColor` and italicize so the user
                      // can spot irregular pronunciations at a glance.
                      if (lexeme.isPhonologicalException)
                        Text(
                          display.ipa,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: ipaOverridden
                                ? ipaOverrideColor
                                : cs.onSurface.withValues(alpha: 0.65),
                            fontStyle: ipaOverridden
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        )
                      else
                        ViolationText(
                          text: display.ipa,
                          violations: validation.violations,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: ipaOverridden
                                ? ipaOverrideColor
                                : cs.onSurface.withValues(alpha: 0.65),
                            fontStyle: ipaOverridden
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                    ] else ...[
                      // IPA as primary heading with violation highlighting (unless exception)
                      if (lexeme.isPhonologicalException)
                        Text(
                          display.ipa,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ipaOverridden ? ipaOverrideColor : null,
                            fontStyle: ipaOverridden
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        )
                      else
                        ViolationText(
                          text: display.ipa,
                          violations: validation.violations,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ipaOverridden ? ipaOverrideColor : null,
                            fontStyle: ipaOverridden
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                    ],
                    // ---- Phonotactic exception status row ----------------
                    if (lexeme.isPhonologicalException)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Phonotactic exception',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                textStyle:
                                    theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                              onPressed: () async {
                                final dao = ref.read(lexemeDaoProvider);
                                await dao?.updateLexeme(lexeme.copyWith(
                                    isPhonologicalException: false));
                              },
                              child: const Text('Remove exception'),
                            ),
                          ],
                        ),
                      )
                    else if (hasViolations)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          icon: Icon(
                            Icons.warning_amber_outlined,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                          label: const Text('Mark as exception'),
                          onPressed: () async {
                            final dao = ref.read(lexemeDaoProvider);
                            await dao?.updateLexeme(lexeme.copyWith(
                                isPhonologicalException: true));
                          },
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit word',
                onPressed: () => _startEditing(lexeme),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete word',
                color: cs.error,
                onPressed: () => _confirmDelete(context, lexeme),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ---- Meaning -------------------------------------------------
          if (lexeme.meaning != null && lexeme.meaning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                lexeme.meaning!,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ),

          // ---- POS badge -----------------------------------------------
          if (lexeme.partOfSpeech != null && lexeme.partOfSpeech!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Chip(
                label: Text(
                  lexeme.partOfSpeech!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),

          const Divider(height: 24),

          // ---- Plan 04-14 D-62: Parents / Etymology --------------------
          WordDetailParentsSection(lexeme: lexeme),

          // ---- Derivation tree -----------------------------------------
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DerivationTreeWidget(
              rootIpa: lexeme.ipa,
              rootId: widget.lexemeId,
            ),
          ),

          // ---- Plan 04-14 D-60: Suggestions chips ----------------------
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: WordDetailSuggestionsSection(lexeme: lexeme),
          ),

          // ---- Paradigm section (Phase 4 plan 04-07) -------------------
          //
          // Read-only reflection of the Grammar → Paradigm Viewer's axis
          // config (D-27). Only renders when the lexeme's partOfSpeech
          // resolves to a POS row AND that POS has ≥1 dimension. Wired
          // through an extracted public widget so widget tests can mount
          // it directly without pumping the whole WordDetailPanel stack.
          WordDetailParadigmSection(word: lexeme),

          const Divider(height: 1),
          const SizedBox(height: 16),

          // ---- Exceptions section --------------------------------------
          Row(
            children: [
              Text(
                'Exceptions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add exception'),
                onPressed: () =>
                    _addException(context, widget.lexemeId, lexeme),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (exceptions.isEmpty)
            Text(
              'No exceptions. This word follows all active rules.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            ...exceptions.map((ex) {
              final ruleName = ruleNameMap[ex.ruleId] ?? 'Rule #${ex.ruleId}';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  ex.overrideForm,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'via $ruleName',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: cs.error,
                  tooltip: 'Remove exception',
                  onPressed: () => _confirmDeleteException(context, ex),
                ),
              );
            }),

          const SizedBox(height: 32),

          // ---- Delete action -------------------------------------------
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => _confirmDelete(context, lexeme),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Lexeme lexeme,
  ) {
    final romanizationEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? false;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit word',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // When romanization is enabled, it becomes the primary input and
          // IPA is auto-derived (override-only). Mirrors WordCreationForm.
          if (romanizationEnabled) ...[
            TextField(
              controller: _romanizationController,
              decoration: const InputDecoration(
                labelText: 'Romanization *',
                helperText: 'IPA is auto-derived from this',
              ),
            ),
            const SizedBox(height: 12),
            IpaTextField(
              controller: _ipaController,
              decoration: InputDecoration(
                labelText: _ipaManuallyEdited
                    ? 'IPA (manual override)'
                    : 'IPA (auto-derived — edit to override)',
              ),
            ),
            // D-113 (plan 04-17): surface-phonetic preview line.
            // Shows rewritePipeline(phonemic) when rewrite rules are
            // configured and produce a different form. Hidden when no
            // rules exist or none fire on the current phonemic.
            Builder(builder: (context) {
              final applyRewrite = ref.watch(applyRewritePipelineProvider);
              final phonemic = _ipaController.text;
              if (phonemic.isEmpty) return const SizedBox.shrink();
              final phonetic = applyRewrite(phonemic);
              if (phonetic == phonemic) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Surface: [$phonetic]',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                ),
              );
            }),
          ] else ...[
            IpaTextField(
              controller: _ipaController,
              decoration: const InputDecoration(
                labelText: 'IPA *',
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Meaning
          TextField(
            controller: _meaningController,
            decoration: const InputDecoration(
              labelText: 'Meaning',
            ),
          ),
          const SizedBox(height: 12),

          // POS dropdown
          if (posList.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _editPos,
              decoration: const InputDecoration(labelText: 'Part of speech'),
              hint: const Text('— none —'),
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
              onChanged: (val) {
                // D-93 — synchronously set the POS and clear the
                // intrinsic selections. The Builder sub-form below
                // watches dimensionsForPosProvider for the new POS and
                // uses [_posJustChanged] + [_storedIntrinsicLevels] to
                // auto-populate overlap-preserved values on its first
                // render after the POS switch. This avoids an `await`
                // on `.future` (which would hang if the stream hasn't
                // started yet).
                setState(() {
                  _editPos = val;
                  _intrinsicLevelSelections.clear();
                  _intrinsicLevelErrors.clear();
                  _posJustChanged = true;
                });
              },
            ),

          // D-92 / D-93 (plan 04-17 Task 7) — dynamic intrinsic sub-form
          // rendered directly beneath the POS dropdown. Watches
          // dimensionsForPosProvider for the currently-selected POS and
          // filters to intrinsic dims only. Hides entirely when the POS
          // has none. Each dim renders a required DropdownButtonFormField
          // with its own per-dim validation error copy.
          if (_editPos != null)
            Builder(
              builder: (ctx) {
                final currentPosId = () {
                  for (final p in posList) {
                    if (p.name == _editPos) return p.id;
                  }
                  return null;
                }();
                if (currentPosId == null) return const SizedBox.shrink();
                final dimsAsync =
                    ref.watch(dimensionsForPosProvider(currentPosId));
                final dims =
                    dimsAsync.asData?.value ?? const <Dimension>[];
                final intrinsicDims =
                    dims.where((d) => d.intrinsic).toList();
                if (intrinsicDims.isEmpty) return const SizedBox.shrink();
                // D-93 overlap preservation: on POS change, pre-fill
                // selections from the stored lexeme json snapshot for
                // any dim id that overlaps the new POS's intrinsic set.
                if (_posJustChanged) {
                  _posJustChanged = false;
                  for (final d in intrinsicDims) {
                    _intrinsicLevelSelections[d.id] =
                        _storedIntrinsicLevels[d.id]; // may be null
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final dim in intrinsicDims)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('intrinsicDim_${dim.id}'),
                            value: _intrinsicLevelSelections[dim.id],
                            decoration: InputDecoration(
                              labelText: dim.name,
                              helperText:
                                  'Intrinsic — fixed for every $_editPos',
                              errorText: _intrinsicLevelErrors[dim.id],
                            ),
                            items: [
                              for (final lv
                                  in decodeLevelsJson(dim.levelsJson))
                                DropdownMenuItem<int>(
                                  value: lv.id,
                                  child: Text('${lv.name} (${lv.abbr})'),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              _intrinsicLevelSelections[dim.id] = v;
                              _intrinsicLevelErrors[dim.id] = null;
                            }),
                            validator: (v) => v == null
                                ? 'Required — every $_editPos must have '
                                    'a fixed ${dim.name}.'
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              FilledButton(
                onPressed: () => _saveEdit(lexeme),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phase 4 plan 04-07 — read-only paradigm embed mounted in the word
/// detail panel below the derivation tree.
///
/// Renders only when `posForLexeme(word, posList)` returns a non-null
/// [PartsOfSpeechData] AND that POS has at least one dimension. In all
/// other cases (null partOfSpeech, unmatched text, POS with zero
/// dimensions) the widget collapses to `SizedBox.shrink()` so the
/// detail panel does not show an empty Paradigm card.
///
/// Per D-27 the embed is strictly read-only: no AxisConfigBar (the axis
/// config is set in Grammar → Paradigm Viewer and this widget reflects
/// it) and no CoverageMatrixPanel (the coverage matrix belongs only to
/// the Grammar tab). Only [ParadigmTableWidget] is mounted.
///
/// Extracted as a public widget so widget tests can pump it in
/// isolation without standing up the rest of WordDetailPanel's provider
/// graph (romanization, phonotactic, morphology, etc.).
class WordDetailParadigmSection extends ConsumerWidget {
  const WordDetailParadigmSection({super.key, required this.word});

  final Lexeme word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final posListAsync = ref.watch(posListProvider);
    final posList =
        posListAsync.asData?.value ?? const <PartsOfSpeechData>[];
    final pos = posForLexeme(word, posList);
    if (pos == null) return const SizedBox.shrink();

    final dimsAsync = ref.watch(dimensionsForPosProvider(pos.id));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    if (dims.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paradigm',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Fixed height so the inner tabs/table can lay out inside
              // the outer SingleChildScrollView of WordDetailPanel.
              // Read-only: no AxisConfigBar, no CoverageMatrixPanel (D-27).
              SizedBox(
                height: 320,
                child: ParadigmTableWidget(
                  lexemeId: word.id,
                  posId: pos.id,
                  // D-54 / plan 04-13: Lexicon word-detail host routes cell
                  // clicks to CellOverrideDialog for per-word rom/ipa
                  // overrides. The Grammar > Inflections host uses the
                  // default ruleEditor mode instead.
                  clickMode: ParadigmClickMode.wordOverride,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan 04-14 — D-60 Suggestions + D-62 Parents / Etymology sections
// ---------------------------------------------------------------------------

/// D-60 / G-19 Suggestions chips section.
///
/// Renders one [ActionChip] per derivational rule that:
///   - has `isActive = true`
///   - has `kind = 'derivational'`
///   - has `autoApply = false` (auto-apply rules are already promoted)
///   - has `inputPosId == lexeme.pos.id` (strict POS match per D-61)
///   - does NOT already have a promoted Lexeme row for the (parent, rule)
///     pair — once the user clicks a chip the matching row exists and the
///     chip is hidden on the next rebuild (applied-suggestion filter).
///
/// Clicking a chip calls `LexemeDao.promoteDerivation` with an empty
/// gloss — the user fills in the meaning via the derivation tree row's
/// meaning field (Task 2 flow).
///
/// Extracted as a public widget so widget tests can pump it without
/// standing up the full WordDetailPanel provider graph.
class WordDetailSuggestionsSection extends ConsumerWidget {
  const WordDetailSuggestionsSection({super.key, required this.lexeme});

  final Lexeme lexeme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final posListAsync = ref.watch(posListProvider);
    final posList =
        posListAsync.asData?.value ?? const <PartsOfSpeechData>[];
    final pos = posForLexeme(lexeme, posList);
    if (pos == null) return const SizedBox.shrink();

    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? const [];

    // Collect already-applied (parent, rule) pairs so the chip for an
    // applied rule disappears (D-60 "applied suggestions disappear").
    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];
    final appliedRuleIds = <int>{};
    for (final lx in allLexemes) {
      if (lx.derivedFromLexemeId == lexeme.id &&
          lx.derivedViaRuleId != null) {
        appliedRuleIds.add(lx.derivedViaRuleId!);
      }
    }

    // Filter down to dormant suggestions.
    final suggestions = [
      for (final r in rules)
        if (r.isActive &&
            r.kind == 'derivational' &&
            !r.autoApply &&
            r.inputPosId != null &&
            r.inputPosId == pos.id &&
            !appliedRuleIds.contains(r.id))
          r,
    ];

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final rule in suggestions)
                ActionChip(
                  label: Text(rule.name),
                  tooltip: rule.source,
                  onPressed: () async {
                    final dao = ref.read(lexemeDaoProvider);
                    if (dao == null) return;
                    // D-60: empty gloss — the user types the meaning via
                    // the derivation tree row's meaning field.
                    await dao.promoteDerivation(
                      parentId: lexeme.id,
                      ruleId: rule.id,
                      gloss: '',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// D-62 / G-17 Parents / Etymology section.
///
/// Lists every [LexemeParentRow] for this child lexeme, resolved against
/// the parent Lexemes list to display romanization + gloss. When a row
/// has a non-null `relationship` label the label is appended to the
/// parent's display string.
///
/// Hidden entirely when the child has zero parent rows (avoids an empty
/// "Parents" header polluting the detail panel).
///
/// Extracted as a public widget so widget tests can pump it in isolation.
class WordDetailParentsSection extends ConsumerWidget {
  const WordDetailParentsSection({super.key, required this.lexeme});

  final Lexeme lexeme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final parentsAsync = ref.watch(parentsForLexemeProvider(lexeme.id));
    final parents =
        parentsAsync.asData?.value ?? const <LexemeParentRow>[];
    if (parents.isEmpty) return const SizedBox.shrink();

    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];
    final lexemeById = {for (final lx in allLexemes) lx.id: lx};

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parents',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in parents) _buildParentRow(context, row, lexemeById),
        ],
      ),
    );
  }

  Widget _buildParentRow(
    BuildContext context,
    LexemeParentRow row,
    Map<int, Lexeme> lexemeById,
  ) {
    final parent = lexemeById[row.parentLexemeId];
    if (parent == null) return const SizedBox.shrink();
    final label = (parent.romanization != null &&
            parent.romanization!.isNotEmpty)
        ? parent.romanization!
        : parent.ipa;
    final meaning = parent.meaning ?? '';
    final relationship = row.relationship;
    final text = relationship != null && relationship.isNotEmpty
        ? '$label ($meaning) — $relationship'
        : '$label ($meaning)';
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
