import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../morphology/presentation/rules/rule_editor_dialog.dart';
import '../../../morphology/presentation/rules/rules_page.dart';
import '../../data/construction_rule_providers.dart';
import '../../domain/construction_rule.dart';
import '../../domain/rule_kind.dart';
import '../shared/migration_banner.dart';

/// Inflectional rules page — plan 04-05 real implementation, extended in
/// plan 10.1-03 to show construction rules alongside inflectional rules.
///
/// Mounts the shared MigrationBanner above a [RulesPage] filtered to
/// [RuleKind.inflectional], followed by a construction rules section for the
/// optionally scoped [posId].
///
/// When [posId] is provided the construction rules section is scoped to that
/// POS via [constructionRulesForPosProvider]. When null, a small CTA is shown
/// to direct users to select a POS.
class InflectionalRulesPage extends ConsumerWidget {
  const InflectionalRulesPage({super.key, this.posId});

  /// Optional POS scope — when set, construction rules for this POS are shown
  /// below the inflectional rules list.
  final int? posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Watch construction rules for the current POS.
    final constructionRulesAsync = posId != null
        ? ref.watch(constructionRulesForPosProvider(posId!))
        : null;
    final constructionRules =
        constructionRulesAsync?.asData?.value ?? const <ConstructionRule>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MigrationBanner(
          settingsKey: 'ui.migration_v8_banner_dismissed.inflectional',
        ),
        Expanded(
          child: RulesPage(
            kind: RuleKind.inflectional,
            posScopeFilter: posId,
          ),
        ),

        // Construction rules section — shown below inflectional rules.
        const Divider(height: 1),
        _ConstructionRulesSection(
          posId: posId,
          constructionRules: constructionRules,
          theme: theme,
          cs: cs,
        ),
      ],
    );
  }
}

/// Construction rules section shown below the inflectional rules list in
/// [InflectionalRulesPage].
class _ConstructionRulesSection extends StatelessWidget {
  const _ConstructionRulesSection({
    required this.posId,
    required this.constructionRules,
    required this.theme,
    required this.cs,
  });

  final int? posId;
  final List<ConstructionRule> constructionRules;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header row with "New Construction Rule" button.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'CONSTRUCTION RULES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Construction Rule'),
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => RuleEditorDialog(
                      kind: RuleKind.construction,
                      preFilledPosIds:
                          posId != null ? {posId!} : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Construction rule list or empty state.
        if (constructionRules.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'No construction rules for this POS. Click a paradigm cell or use New Rule.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          )
        else
          ...constructionRules.map(
            (rule) => _ConstructionRuleCard(
              rule: rule,
              posId: posId,
              theme: theme,
              cs: cs,
            ),
          ),
      ],
    );
  }
}

/// A single construction rule card in the list.
class _ConstructionRuleCard extends ConsumerWidget {
  const _ConstructionRuleCard({
    required this.rule,
    required this.posId,
    required this.theme,
    required this.cs,
  });

  final ConstructionRule rule;
  final int? posId;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Construction badge — account_tree icon (D-10)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 12,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              // Rule name
              Expanded(
                child: Text(
                  rule.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Edit icon — opens editor dialog
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 16, color: cs.onSurface.withValues(alpha: 0.45)),
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => RuleEditorDialog(
                      kind: RuleKind.construction,
                      existingConstructionRule: rule,
                      preFilledPosIds: posId != null ? {posId!} : null,
                    ),
                  );
                },
              ),
              // Delete icon — deletes immediately (no confirm)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: cs.error.withValues(alpha: 0.7)),
                onPressed: () async {
                  final dao = ref.read(constructionRuleDaoProvider);
                  await dao?.deleteRule(rule.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
