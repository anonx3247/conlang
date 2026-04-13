// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import 'condition_editor.dart';
import 'form_state_models.dart';
import 'operation_editor.dart';

// ---------------------------------------------------------------------------
// Branch editor — extracted from rule_editor_dialog.dart (D-14)
// ---------------------------------------------------------------------------

/// Renders the list of branch cards for the rule editor.
///
/// Each branch card has a header, a [ConditionEditor], one [OperationRow]
/// per operation, and an "Add operation" button. An "Add branch" button
/// appears below the card list.
///
/// [onChanged] is called whenever the user edits any field so the parent
/// can trigger a rebuild (live preview, etc.).
class BranchEditor extends StatelessWidget {
  const BranchEditor({
    super.key,
    required this.branches,
    required this.onChanged,
  });

  final List<BranchState> branches;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branch cards
        ...List.generate(branches.length, (bi) {
          final branch = branches[bi];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch header row
                  Row(
                    children: [
                      Text(
                        'Branch ${bi + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      if (branches.length > 1)
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: cs.error),
                          tooltip: 'Remove branch',
                          onPressed: () {
                            branches[bi].dispose();
                            branches.removeAt(bi);
                            onChanged();
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Condition section
                  ConditionEditor(branch: branch, onChanged: onChanged),

                  const SizedBox(height: 10),

                  // Operations
                  ...List.generate(branch.ops.length, (oi) {
                    return OperationRow(
                      op: branch.ops[oi],
                      branchOpCount: branch.ops.length,
                      onChanged: onChanged,
                      onRemove: () {
                        branch.ops[oi].dispose();
                        branch.ops.removeAt(oi);
                        onChanged();
                      },
                    );
                  }),

                  const SizedBox(height: 4),

                  // Add operation button
                  TextButton.icon(
                    onPressed: () {
                      branch.ops.add(OpState());
                      onChanged();
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add operation'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // Add branch button
        OutlinedButton.icon(
          onPressed: () {
            branches.add(BranchState());
            onChanged();
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add branch'),
        ),
      ],
    );
  }
}
