import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phonotactic_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import 'sound_rules_shared.dart';

/// Widget for managing syllable structure templates.
///
/// Displays all templates with parse status, active toggle, edit and delete
/// controls. An "Add template" button opens an inline editor dialog.
class TemplateEditor extends ConsumerWidget {
  const TemplateEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTemplatesAsync = ref.watch(allTemplatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoundRulesSectionHeader(
          title: 'Syllable Templates',
          helpText:
              'Define the sound structure of syllables. '
              'C = consonant, V = vowel, [name] = natural class, (X) = optional.',
          onAdd: () => _showAddDialog(context, ref),
        ),
        allTemplatesAsync.when(
          data: (templates) => templates.isEmpty
              ? const SoundRulesEmptyHint(
                  message:
                      'No templates yet. Add one to start generating words.',
                )
              : Column(
                  children: templates
                      .map((t) => _TemplateRow(template: t))
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
      builder: (_) => _TemplateEditDialog(
        initial: null,
        onSave: (pattern, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.insertTemplate(
            PhonotacticTemplatesCompanion.insert(
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
// Template row
// ---------------------------------------------------------------------------

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.template});

  final PhonotacticTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parsed = parseSyllableTemplate(template.pattern);
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
            message: isValid ? 'Valid template' : (parsed.error ?? 'Invalid'),
            child: Icon(
              isValid ? Icons.check_circle_outline : Icons.error_outline,
              size: 16,
              color: isValid ? Colors.green : cs.error,
            ),
          ),
          const SizedBox(width: 8),

          // Pattern text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.pattern,
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
                if (template.description != null &&
                    template.description!.isNotEmpty)
                  Text(
                    template.description!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),

          // Active toggle
          Switch(
            value: template.isActive,
            onChanged: (v) {
              ref
                  .read(phonotacticDaoProvider)
                  ?.toggleTemplateActive(template.id, active: v);
            },
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit template',
            onPressed: () => _showEditDialog(context, ref),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
            tooltip: 'Delete template',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _TemplateEditDialog(
        initial: template,
        onSave: (pattern, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.updateTemplate(
            template.copyWith(
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
        title: const Text('Delete template?'),
        content: Text('Remove "${template.pattern}"?'),
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
      ref.read(phonotacticDaoProvider)?.deleteTemplate(template.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Add / edit dialog
// ---------------------------------------------------------------------------

class _TemplateEditDialog extends StatefulWidget {
  const _TemplateEditDialog({
    required this.initial,
    required this.onSave,
  });

  final PhonotacticTemplate? initial;
  final Future<void> Function(String pattern, String description) onSave;

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  late final TextEditingController _patternCtrl;
  late final TextEditingController _descCtrl;
  ParsedTemplate? _parsed;
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
      _parsed = text.isEmpty ? null : parseSyllableTemplate(text);
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
      title: Text(widget.initial == null ? 'Add template' : 'Edit template'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pattern field with live parse validation.
            // Uses plain TextField — DSL patterns use C/V/[]/() syntax,
            // not IPA symbols, so the IPA keyboard is not appropriate here.
            TextField(
              controller: _patternCtrl,
              decoration: InputDecoration(
                labelText: 'Template pattern',
                hintText: '(C)(C)V(C)',
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
                hintText: 'e.g. Open syllable',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // DSL help text
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Syntax: C = consonant  V = vowel  [name] = natural class  (X) = optional',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
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
