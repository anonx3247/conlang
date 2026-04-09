import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/morphology_providers.dart';
import 'rule_editor_dialog.dart';

/// Main rules list page for morphological rules.
///
/// Shows all rules with CRUD actions. Watches [morphologicalRuleListProvider]
/// for reactive updates from the Drift database.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dao = ref.watch(morphologyDaoProvider);
    final hasProject = dao != null;

    if (!hasProject) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or open a project to manage morphological rules.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    final rulesAsync = ref.watch(morphologicalRuleListProvider);

    return Scaffold(
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_fix_high_outlined,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No morphological rules yet.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add one to get started.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, i) {
              final rule = rules[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Name + DSL source
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rule.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rule.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Active toggle
                      Switch(
                        value: rule.isActive,
                        onChanged: (value) async {
                          await dao.updateRule(rule.copyWith(isActive: value));
                        },
                      ),

                      // Edit button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit rule',
                        onPressed: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => RuleEditorDialog(existing: rule),
                          );
                        },
                      ),

                      // Delete button
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        tooltip: 'Delete rule',
                        onPressed: () async {
                          final confirmed = await _confirmDelete(context, rule.name);
                          if (confirmed && context.mounted) {
                            await dao.deleteRule(rule.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: hasProject
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const RuleEditorDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Rule'),
            )
          : null,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String ruleName) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete rule?'),
            content: Text('Delete "$ruleName"? This cannot be undone.'),
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
        ) ??
        false;
  }
}
