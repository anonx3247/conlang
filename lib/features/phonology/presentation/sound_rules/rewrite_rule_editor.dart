import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phonotactic_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import '../shared/ipa_keyboard/ipa_text_field.dart';
import 'sound_rules_shared.dart';

/// Widget for managing phonological rewrite rules in SPE-style notation.
///
/// Displays all rewrite rules with real-time parse validation. Rules use
/// `A -> B / C_D` notation (e.g. "k -> x / V_V" for velar lenition between
/// vowels). This is distinct from phonotactic constraints — rewrite rules are
/// transformational (sound changes), not labeling patterns as allowed/forbidden.
class RewriteRuleEditor extends ConsumerWidget {
  const RewriteRuleEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rewriteRuleListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoundRulesSectionHeader(
          title: 'Rewrite Rules',
          helpText:
              'Sound changes in A \u2192 B / C_D notation '
              '(e.g. "k -> x / V_V" for velar lenition).',
          onAdd: () => _showAddDialog(context, ref),
        ),
        rulesAsync.when(
          data: (rules) => rules.isEmpty
              ? const SoundRulesEmptyHint(
                  message:
                      'No rewrite rules yet. Add one to define sound changes.',
                )
              : Column(
                  children: rules
                      .map((r) => _RewriteRuleRow(rule: r))
                      .toList(),
                ),
          loading: () => const SoundRulesLoadingRow(),
          error: (e, _) => SoundRulesErrorRow(message: e.toString()),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _RewriteRuleEditDialog(
        initial: null,
        onSave: (source) async {
          final dao = ref.read(rewriteRuleDaoProvider);
          if (dao == null) return;
          await dao.insertRule(RewriteRulesCompanion.insert(source: source));
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rewrite rule row
// ---------------------------------------------------------------------------

class _RewriteRuleRow extends ConsumerWidget {
  const _RewriteRuleRow({required this.rule});

  final RewriteRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parsed = parseRewriteRule(rule.source);
    final isValid = parsed.isValid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Parse status icon
          Tooltip(
            message: isValid
                ? 'Rewrite rule'
                : (parsed.error ?? 'Invalid rule'),
            child: Icon(
              isValid ? Icons.swap_horiz_outlined : Icons.error_outline,
              size: 16,
              color: isValid ? cs.primary : cs.error,
            ),
          ),
          const SizedBox(width: 8),

          // Source text (monospace)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.source,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: isValid
                        ? cs.onSurface
                        : cs.error.withValues(alpha: 0.8),
                  ),
                ),
                if (!isValid)
                  Text(
                    parsed.error ?? 'Parse error',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit rule',
            onPressed: () => _showEditDialog(context, ref),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
            tooltip: 'Delete rule',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _RewriteRuleEditDialog(
        initial: rule,
        onSave: (source) async {
          final dao = ref.read(rewriteRuleDaoProvider);
          if (dao == null) return;
          await dao.updateRule(rule.copyWith(source: source));
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rewrite rule?'),
        content: Text('Remove "${rule.source}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(rewriteRuleDaoProvider)?.deleteRule(rule.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Add / edit dialog
// ---------------------------------------------------------------------------

class _RewriteRuleEditDialog extends StatefulWidget {
  const _RewriteRuleEditDialog({
    required this.initial,
    required this.onSave,
  });

  final RewriteRule? initial;
  final Future<void> Function(String source) onSave;

  @override
  State<_RewriteRuleEditDialog> createState() => _RewriteRuleEditDialogState();
}

class _RewriteRuleEditDialogState extends State<_RewriteRuleEditDialog> {
  late final TextEditingController _sourceCtrl;
  ParsedRewriteRule? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sourceCtrl = TextEditingController(
      text: widget.initial?.source ?? '',
    );
    _validate(_sourceCtrl.text);
  }

  @override
  void dispose() {
    _sourceCtrl.dispose();
    super.dispose();
  }

  void _validate(String text) {
    setState(() {
      _parsed = text.isEmpty ? null : parseRewriteRule(text);
    });
  }

  Future<void> _save() async {
    if (_parsed == null || !_parsed!.isValid) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_sourceCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isValid = _parsed?.isValid ?? false;
    final isEmpty = _sourceCtrl.text.isEmpty;

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add rewrite rule' : 'Edit rewrite rule',
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rule field with live parse validation
            IpaTextField(
              controller: _sourceCtrl,
              decoration: InputDecoration(
                labelText: 'Rewrite rule',
                hintText: 'k -> x / V_V',
                border: const OutlineInputBorder(),
                suffixIcon: isEmpty
                    ? null
                    : Icon(
                        isValid
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isValid ? Colors.green : cs.error,
                        size: 18,
                      ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: _validate,
            ),

            // Parse error message
            if (_parsed != null && !_parsed!.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _parsed!.error!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.error),
                ),
              ),

            const SizedBox(height: 12),

            // Syntax help section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Syntax: input -> output / left_right\n\n'
                'Examples:\n'
                '  k -> x / V_V        velar lenition between vowels\n'
                '  a -> e / [stop]_    vowel raising after stops\n'
                '  t -> \u0294 / _#         glottalization at word end\n'
                '  V -> [+nasal] / _N  nasalization before nasals\n\n'
                '_ marks the target position. # marks word boundary.\n'
                'Left or right context can be omitted: k -> x / V_',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_saving || !isValid || isEmpty) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
