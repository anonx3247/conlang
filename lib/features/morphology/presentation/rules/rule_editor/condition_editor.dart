// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import '../../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../../domain/morphology_dsl.dart';
import 'form_state_models.dart';
import 'operation_editor.dart' show PhonemeViolationRow;

// ---------------------------------------------------------------------------
// Condition section — extracted from rule_editor_dialog.dart (D-14)
// ---------------------------------------------------------------------------

/// Renders the conditions section of a single branch: position dropdown,
/// pattern field with phoneme-violation warning, add/remove condition buttons.
///
/// Calls [onChanged] whenever the user edits any condition so the parent
/// can trigger a rebuild (for live preview updates).
class ConditionEditor extends StatelessWidget {
  const ConditionEditor({
    super.key,
    required this.branch,
    required this.onChanged,
  });

  final BranchState branch;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions:',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),

        // One row per condition
        ...List.generate(branch.conditions.length, (ci) {
          final cond = branch.conditions[ci];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Position dropdown
                DropdownButton<CondPosition>(
                  value: cond.position,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: CondPosition.startsWith,
                      child: Text('starts with'),
                    ),
                    DropdownMenuItem(
                      value: CondPosition.endsWith,
                      child: Text('ends with'),
                    ),
                    DropdownMenuItem(
                      value: CondPosition.contains,
                      child: Text('contains'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    cond.position = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: 8),
                // Pattern field + inline phoneme-violation warning
                // (D-81 plan 04-16 / G-69, 'cond' scope skips V/C/F
                // and bracketed class-refs).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: cond.patternCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. [nasal]V, CV, Vk(l)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                      PhonemeViolationRow(
                          text: cond.patternCtrl.text, scope: 'cond'),
                    ],
                  ),
                ),
                if (branch.conditions.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 14,
                        color: cs.error.withValues(alpha: 0.7)),
                    tooltip: 'Remove condition',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      branch.conditions[ci].dispose();
                      branch.conditions.removeAt(ci);
                      onChanged();
                    },
                  ),
                ],
              ],
            ),
          );
        }),

        // Add condition button
        TextButton.icon(
          onPressed: () {
            branch.conditions.add(CondState());
            onChanged();
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add condition (AND)'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
          ),
        ),

        // Syntax help text
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Pattern: [class]  C  V  literal  (optional)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
