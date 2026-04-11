import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../grammar/domain/rule_kind.dart';
import '../../data/morphology_providers.dart';
import 'morphology_preview_panel.dart';
import 'rule_editor_dialog.dart';

/// Main rules list page for morphological rules.
///
/// Shows all rules with CRUD actions on the left, and a live morphology preview
/// panel on the right (modeled on the phonology word generator panel).
///
/// Watches [morphologicalRuleListProvider] for reactive updates from Drift.
///
/// Plan 04-05: optionally parameterized with a [RuleKind] filter. When
/// [kind] is non-null only rules of that kind are shown and newly-created
/// rules inherit that kind (via [RuleEditorDialog]'s required `kind`
/// parameter). When [kind] is null the page shows all rules and defaults
/// new rules to [RuleKind.derivational] for backward-compat.
class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key, this.kind});

  /// When non-null, scopes the page to a single rule kind. Backed by
  /// [rulesByKindProvider] instead of [morphologicalRuleListProvider].
  final RuleKind? kind;

  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage> {
  /// The currently selected POS id for filtering, or null for "All".
  int? _selectedPosId;
  bool _didFixOrdering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dao = ref.watch(morphologyDaoProvider);
    final hasProject = dao != null;

    // Fix duplicate ordering on first build with a valid DAO.
    if (hasProject && !_didFixOrdering) {
      _didFixOrdering = true;
      dao.fixDuplicateOrdering();
    }

    if (!hasProject) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule_outlined,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
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

    // Plan 04-05: when widget.kind is non-null, filter to that kind via
    // rulesByKindProvider. When null, show all rules (backward-compat).
    final rulesAsync = widget.kind == null
        ? ref.watch(morphologicalRuleListProvider)
        : ref.watch(rulesByKindProvider(widget.kind!));
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Left: rules list -------------------------------------------
          SizedBox(
            width: 420,
            child: rulesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rules) {
                // Apply POS filter using posIds text column
                final filtered = _selectedPosId == null
                    ? rules
                    : rules.where((r) {
                        if (r.posIds.isEmpty) return true; // applies to all
                        final ids = r.posIds
                            .split(',')
                            .map((s) => int.tryParse(s.trim()))
                            .whereType<int>()
                            .toSet();
                        return ids.contains(_selectedPosId);
                      }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // POS filter bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            'Filter by POS:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<int?>(
                            value: _selectedPosId,
                            underline: const SizedBox.shrink(),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All'),
                              ),
                              ...posList.map(
                                (pos) => DropdownMenuItem<int?>(
                                  value: pos.id,
                                  child: Text(pos.name),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedPosId = v),
                          ),
                        ],
                      ),
                    ),

                    // Rules list
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_fix_high_outlined,
                                    size: 64,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    rules.isEmpty
                                        ? 'No morphological rules yet.'
                                        : 'No rules match the selected POS.',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (rules.isEmpty)
                                    Text(
                                      'Add one to get started.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final rule = filtered[i];
                                final origIndex = rules.indexOf(rule);
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        // Name only (no DSL source)
                                        Expanded(
                                          child: Text(
                                            rule.name,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        // Reorder up
                                        Opacity(
                                          opacity:
                                              origIndex == 0 ? 0.2 : 1.0,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.arrow_upward,
                                              size: 18,
                                            ),
                                            tooltip: 'Move up',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints:
                                                const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed: origIndex == 0
                                                ? null
                                                : () => dao.swapOrdering(
                                                      rules[origIndex].id,
                                                      rules[origIndex - 1]
                                                          .id,
                                                    ),
                                          ),
                                        ),

                                        // Reorder down
                                        Opacity(
                                          opacity:
                                              origIndex == rules.length - 1
                                                  ? 0.2
                                                  : 1.0,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.arrow_downward,
                                              size: 18,
                                            ),
                                            tooltip: 'Move down',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints:
                                                const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed: origIndex ==
                                                    rules.length - 1
                                                ? null
                                                : () => dao.swapOrdering(
                                                      rules[origIndex].id,
                                                      rules[origIndex + 1]
                                                          .id,
                                                    ),
                                          ),
                                        ),

                                        // Active toggle
                                        Switch(
                                          value: rule.isActive,
                                          onChanged: (value) async {
                                            await dao.updateRule(
                                              rule.copyWith(isActive: value),
                                            );
                                          },
                                        ),

                                        // Edit button
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_outlined),
                                          tooltip: 'Edit rule',
                                          onPressed: () async {
                                            await showDialog<void>(
                                              context: context,
                                              builder: (_) => RuleEditorDialog(
                                                kind: widget.kind ??
                                                    RuleKind.fromDbString(
                                                        rule.kind),
                                                existing: rule,
                                              ),
                                            );
                                          },
                                        ),

                                        // Delete button
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: cs.error,
                                          ),
                                          tooltip: 'Delete rule',
                                          onPressed: () async {
                                            final confirmed =
                                                await _confirmDelete(
                                              context,
                                              rule.name,
                                            );
                                            if (confirmed &&
                                                context.mounted) {
                                              await dao
                                                  .deleteRule(rule.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ---- Vertical divider -------------------------------------------
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: cs.outlineVariant,
          ),

          // ---- Right: morphology preview panel ----------------------------
          const Expanded(
            child: MorphologyPreviewPanel(),
          ),
        ],
      ),
      floatingActionButton: hasProject
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => RuleEditorDialog(
                    kind: widget.kind ?? RuleKind.derivational,
                  ),
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
