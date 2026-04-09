import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phonotactic_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import 'sound_rules_shared.dart';

/// Widget for managing phonotactic constraint rules.
///
/// Displays all constraints with parse status, active toggle, edit and delete
/// controls. Constraint rules use `LHS -> RHS` notation
/// (e.g. "VN -> nasalised V", "[stop][stop] -> forbidden").
///
/// This covers phonotactic CONSTRAINTS only — what patterns are allowed or
/// forbidden in sound sequences. It is NOT a sound change engine.
class ConstraintEditor extends ConsumerWidget {
  const ConstraintEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allConstraintsAsync = ref.watch(allConstraintsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoundRulesSectionHeader(
          title: 'Phonotactic Constraints',
          helpText:
              'Define allowed or forbidden sound sequences. '
              'Use <segments> -> <label>, e.g. "VN -> nasalised V" or '
              '"[stop][stop] -> forbidden".',
          onAdd: () => _showAddDialog(context, ref),
        ),
        allConstraintsAsync.when(
          data: (constraints) => constraints.isEmpty
              ? const SoundRulesEmptyHint(
                  message:
                      'No constraints yet. Add one to flag invalid sequences.',
                )
              : Column(
                  children: constraints
                      .map((c) => _ConstraintRow(constraint: c))
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
      builder: (_) => _ConstraintEditDialog(
        initial: null,
        onSave: (pattern, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.insertConstraint(
            PhonotacticConstraintsCompanion.insert(
              pattern: pattern,
              description: Value(description.isEmpty ? null : description),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Constraint row
// ---------------------------------------------------------------------------

class _ConstraintRow extends ConsumerWidget {
  const _ConstraintRow({required this.constraint});

  final PhonotacticConstraint constraint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parsed = parseConstraintRule(constraint.pattern);
    final isValid = parsed.isValid;
    final isForbidden = parsed.rule?.isForbidden ?? false;

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
                ? (isForbidden ? 'Forbidden pattern' : 'Constraint rule')
                : (parsed.error ?? 'Invalid'),
            child: Icon(
              isValid
                  ? (isForbidden ? Icons.block_outlined : Icons.rule_outlined)
                  : Icons.error_outline,
              size: 16,
              color: isValid
                  ? (isForbidden ? cs.error : cs.primary)
                  : cs.error,
            ),
          ),
          const SizedBox(width: 8),

          // Pattern text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  constraint.pattern,
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
                if (constraint.description != null &&
                    constraint.description!.isNotEmpty)
                  Text(
                    constraint.description!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),

          // Active toggle
          Switch(
            value: constraint.isActive,
            onChanged: (v) {
              ref
                  .read(phonotacticDaoProvider)
                  ?.toggleConstraintActive(constraint.id, active: v);
            },
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit constraint',
            onPressed: () => _showEditDialog(context, ref),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
            tooltip: 'Delete constraint',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ConstraintEditDialog(
        initial: constraint,
        onSave: (pattern, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.updateConstraint(
            constraint.copyWith(
              pattern: pattern,
              description: Value(description.isEmpty ? null : description),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete constraint?'),
        content: Text('Remove "${constraint.pattern}"?'),
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
      ref.read(phonotacticDaoProvider)?.deleteConstraint(constraint.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Add / edit dialog
// ---------------------------------------------------------------------------

class _ConstraintEditDialog extends StatefulWidget {
  const _ConstraintEditDialog({
    required this.initial,
    required this.onSave,
  });

  final PhonotacticConstraint? initial;
  final Future<void> Function(String pattern, String description) onSave;

  @override
  State<_ConstraintEditDialog> createState() => _ConstraintEditDialogState();
}

class _ConstraintEditDialogState extends State<_ConstraintEditDialog> {
  late final TextEditingController _patternCtrl;
  late final TextEditingController _descCtrl;
  ParsedConstraint? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _patternCtrl = TextEditingController(
      text: widget.initial?.pattern ?? '',
    );
    _descCtrl = TextEditingController(
      text: widget.initial?.description ?? '',
    );
    _validate(_patternCtrl.text);
  }

  @override
  void dispose() {
    _patternCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _validate(String text) {
    setState(() {
      _parsed = text.isEmpty ? null : parseConstraintRule(text);
    });
  }

  Future<void> _save() async {
    if (_parsed == null || !_parsed!.isValid) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_patternCtrl.text.trim(), _descCtrl.text.trim());
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
    final isEmpty = _patternCtrl.text.isEmpty;

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add constraint' : 'Edit constraint',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pattern field with live parse validation
            TextField(
              controller: _patternCtrl,
              decoration: InputDecoration(
                labelText: 'Constraint pattern',
                hintText: 'VN -> nasalised V',
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

            // Optional description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Vowel before nasal is nasalised',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Syntax help text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'How to write constraints:\n\n'
                '  C = any consonant    V = any vowel\n'
                '  [name] = natural class (e.g. [stop], [nasal])\n\n'
                '  Pattern:  segments -> label\n\n'
                'Examples:\n'
                '  [stop][stop] -> forbidden     (no two stops in a row)\n'
                '  VN -> nasalised vowel         (vowel before nasal is nasalised)\n'
                '  V[fricative]V -> allowed      (fricatives between vowels)\n'
                '  CC -> forbidden               (no consonant clusters)',
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
