import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../morphology/data/morphology_providers.dart';
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

  @override
  void dispose() {
    _ipaController.dispose();
    _romanizationController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  void _startEditing(Lexeme lexeme) {
    _ipaController.text = lexeme.ipa;
    _romanizationController.text = lexeme.romanization ?? '';
    _meaningController.text = lexeme.meaning ?? '';
    _editPos = lexeme.partOfSpeech;
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
                      Text(
                        lexeme.ipa,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ] else
                      Text(
                        lexeme.ipa,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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

          // IPA field
          IpaTextField(
            controller: _ipaController,
            decoration: const InputDecoration(
              labelText: 'IPA *',
            ),
          ),
          const SizedBox(height: 12),

          // Romanization (only show when enabled)
          if (romanizationEnabled) ...[
            TextField(
              controller: _romanizationController,
              decoration: const InputDecoration(
                labelText: 'Romanization',
              ),
            ),
            const SizedBox(height: 12),
          ],

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
