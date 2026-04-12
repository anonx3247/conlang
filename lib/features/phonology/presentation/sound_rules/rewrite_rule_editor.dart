import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phonotactic_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import '../shared/ipa_keyboard/ipa_text_field.dart';
import 'sound_rules_shared.dart';

/// Widget for managing phonological rewrite rules.
///
/// Displays all rewrite rules with real-time parse validation. Rules use
/// fill-in-the-blank UI: [input] -> [output] / [left]_[right].
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
              'Sound changes: what becomes what, and in which context.',
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
// Add / edit dialog — fill-in-the-blank UI
// ---------------------------------------------------------------------------

/// Parses a source string like "k -> x / V_V" into its 4 parts.
({String input, String output, String left, String right}) _parseParts(
    String source) {
  var input = '', output = '', left = '', right = '';
  final arrowIdx = source.indexOf(' -> ');
  if (arrowIdx < 0) {
    input = source.trim();
    return (input: input, output: output, left: left, right: right);
  }
  input = source.substring(0, arrowIdx).trim();
  final afterArrow = source.substring(arrowIdx + 4).trim();

  final slashIdx = afterArrow.indexOf(' / ');
  if (slashIdx < 0) {
    output = afterArrow;
    return (input: input, output: output, left: left, right: right);
  }
  output = afterArrow.substring(0, slashIdx).trim();
  final context = afterArrow.substring(slashIdx + 3).trim();

  final underIdx = context.indexOf('_');
  if (underIdx < 0) {
    left = context;
  } else {
    left = context.substring(0, underIdx);
    right = context.substring(underIdx + 1);
  }
  return (input: input, output: output, left: left, right: right);
}

/// Assembles the 4 parts back into a source string.
String _buildSource(String input, String output, String left, String right) {
  final buf = StringBuffer();
  buf.write(input.trim());
  buf.write(' -> ');
  buf.write(output.trim());
  if (left.trim().isNotEmpty || right.trim().isNotEmpty) {
    buf.write(' / ');
    buf.write(left.trim());
    buf.write('_');
    buf.write(right.trim());
  }
  return buf.toString();
}

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
  late final TextEditingController _inputCtrl;
  late final TextEditingController _outputCtrl;
  late final TextEditingController _leftCtrl;
  late final TextEditingController _rightCtrl;
  ParsedRewriteRule? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.initial != null
        ? _parseParts(widget.initial!.source)
        : (input: '', output: '', left: '', right: '');
    _inputCtrl = TextEditingController(text: parts.input);
    _outputCtrl = TextEditingController(text: parts.output);
    _leftCtrl = TextEditingController(text: parts.left);
    _rightCtrl = TextEditingController(text: parts.right);
    _validate();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  String get _source => _buildSource(
        _inputCtrl.text,
        _outputCtrl.text,
        _leftCtrl.text,
        _rightCtrl.text,
      );

  void _validate() {
    setState(() {
      final src = _source;
      _parsed = (_inputCtrl.text.trim().isEmpty || _outputCtrl.text.trim().isEmpty)
          ? null
          : parseRewriteRule(src);
    });
  }

  Future<void> _save() async {
    if (_parsed == null || !_parsed!.isValid) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_source);
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
    final isEmpty =
        _inputCtrl.text.trim().isEmpty || _outputCtrl.text.trim().isEmpty;

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.55),
    );
    final arrowStyle = theme.textTheme.titleLarge?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.4),
      fontFamily: 'monospace',
    );

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add rewrite rule' : 'Edit rewrite rule',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row: [input] -> [output]
            //
            // D-76 (plan 04-15): asymmetric labels. The input side is the
            // phonemic match pattern (operates on phoneme inventory); the
            // output side is the phonetic replacement (surface IPA, may
            // contain allophones or diacritics outside the inventory).
            // The rewrite pipeline applies this rule AFTER morphology,
            // taking phonemic input and producing phonetic output —
            // romanization contract (D-73) only applies to the input side.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _RuleField(
                    controller: _inputCtrl,
                    label: 'Pattern (phonemic)',
                    hint: 'k',
                    onChanged: _validate,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                  child: Text('\u2192', style: arrowStyle),
                ),
                Expanded(
                  child: _RuleField(
                    controller: _outputCtrl,
                    label: 'Replacement (phonetic)',
                    hint: 'x',
                    onChanged: _validate,
                  ),
                ),
              ],
            ),

            // D-76: surface the asymmetry to the user inline, not just via
            // labels. The replacement field accepts surface IPA (allophones,
            // diacritics allowed) and is NEVER subject to rom↔phonemic
            // conversion regardless of the romanization toggle.
            const SizedBox(height: 6),
            Text(
              'Pattern matches phonemic input; replacement is surface phonetic '
              '(allophones, diacritics allowed).',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: 16),

            // Context row: [left] _ [right]
            // D-76: phonemic (context side of the rule, not the replacement).
            Text('Context (optional)', style: labelStyle),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  // D-76: phonemic (context side of the rule, not the replacement)
                  child: _RuleField(
                    controller: _leftCtrl,
                    label: 'Before',
                    hint: 'V',
                    onChanged: _validate,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                  child: Text('_', style: arrowStyle),
                ),
                Expanded(
                  // D-76: phonemic (context side of the rule, not the replacement)
                  child: _RuleField(
                    controller: _rightCtrl,
                    label: 'After',
                    hint: 'V',
                    onChanged: _validate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Validation status
            if (_parsed != null)
              Row(
                children: [
                  Icon(
                    isValid
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 16,
                    color: isValid ? Colors.green : cs.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isValid
                          ? _source
                          : (_parsed!.error ?? 'Invalid rule'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: isValid
                            ? cs.onSurface.withValues(alpha: 0.6)
                            : cs.error,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Help
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Use IPA symbols, C (consonant), V (vowel), '
                'or [class] (e.g. [stop]).\n'
                '# = word boundary. Context is optional.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
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

/// A single field in the rewrite rule dialog with IPA keyboard support.
class _RuleField extends StatelessWidget {
  const _RuleField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return IpaTextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: const TextStyle(fontFamily: 'monospace'),
      onChanged: (_) => onChanged(),
    );
  }
}
