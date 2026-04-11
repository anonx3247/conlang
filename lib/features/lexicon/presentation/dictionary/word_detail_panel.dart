import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../grammar/domain/pos_resolver.dart';
import '../../../grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/phonotactic_validation_provider.dart';
import '../../../phonology/data/romanization_providers.dart';
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
    _updatingControllersProgrammatically = false;
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit(Lexeme lexeme) async {
    final ipa = _ipaController.text.trim();
    if (ipa.isEmpty) return;
    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) return;

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

    // Phonotactic validation for this word's IPA
    final validate = ref.watch(phonotacticValidatorProvider);
    final validation = validate(word: lexeme.ipa);
    final hasViolations = !validation.isValid;

    // Visual flag: IPA is a manual override if it diverges from what
    // deromanize(romanization) would produce. When true, the IPA is
    // rendered in a distinct color so the user can spot irregular
    // pronunciations at a glance.
    final deromanize = ref.watch(deromanizeProvider);
    final ipaOverridden = isIpaManuallyOverridden(
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
                        lexeme.romanization != null &&
                        lexeme.romanization!.isNotEmpty) ...[
                      // Romanization as primary heading
                      Text(
                        lexeme.romanization!,
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
                          lexeme.ipa,
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
                          text: lexeme.ipa,
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
                          lexeme.ipa,
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
                          text: lexeme.ipa,
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

          // ---- Derivation tree -----------------------------------------
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: DerivationTreeWidget(
              rootIpa: lexeme.ipa,
              rootId: widget.lexemeId,
            ),
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
              onChanged: (val) => setState(() => _editPos = val),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
