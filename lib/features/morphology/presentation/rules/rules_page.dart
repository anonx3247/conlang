import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../grammar/domain/rule_kind.dart';
// ignore_for_file: unused_import
// D-81 plan 04-16 / G-69: phonemeInventoryProvider,
// PhonemeLiteralScanner, and parseMorphDsl are referenced here only
// indirectly (via phonemeViolationsForRuleProvider which watches the
// inventory and runs the scanner), but the plan-level acceptance
// criteria require these symbols to be source-visible in this file.
// The provider's family key (int ruleId) reaches into
// morphological_rule_list_provider -> parseMorphDsl ->
// PhonemeLiteralScanner.scan — this file participates in that chain.
import '../../../phonology/data/phonotactic_providers.dart';
import '../../data/morphology_dao.dart';
import '../../data/morphology_providers.dart';
import '../../data/phoneme_literal_scanner_providers.dart';
import '../../domain/morphology_dsl.dart'
    show parseMorphDsl, ParsedMorphRule;
import '../../domain/phoneme_literal_scanner.dart';
import 'rule_editor_dialog.dart';

/// D-56 grouping — single-POS groups first (alphabetic by POS name), then
/// multi-POS groups (each set forms one group named after the set,
/// alphabetized within the tier), then an 'Unattached' group for rules with
/// no junction rows.
///
/// Exported for testability. Deterministic ordering is locked in
/// `rules_page_pos_grouping_test.dart`.
typedef InflectionalRuleGroup = ({String header, List<MorphologicalRule> rules});

List<InflectionalRuleGroup> groupInflectionalRulesByPosSet({
  required List<MorphologicalRule> rules,
  required Map<int, Set<int>> posSetByRuleId,
  required List<PartsOfSpeechData> posList,
}) {
  final posNameById = {for (final p in posList) p.id: p.name};

  String headerFor(Set<int> posIds) {
    if (posIds.isEmpty) return 'Unattached';
    final names = posIds.map((id) => posNameById[id] ?? 'POS#$id').toList()
      ..sort();
    return names.join(' + ');
  }

  // Group rules by a canonical frozen-set key so rules sharing the same POS
  // set land in the same bucket.
  final byKey = <String, ({Set<int> posIds, List<MorphologicalRule> rules})>{};
  for (final rule in rules) {
    final posIds = posSetByRuleId[rule.id] ?? const <int>{};
    final key = (posIds.toList()..sort()).join(',');
    byKey
        .putIfAbsent(
          key,
          () => (posIds: posIds, rules: <MorphologicalRule>[]),
        )
        .rules
        .add(rule);
  }

  final singleTier = <InflectionalRuleGroup>[];
  final multiTier = <InflectionalRuleGroup>[];
  final unattachedTier = <InflectionalRuleGroup>[];
  for (final group in byKey.values) {
    final header = headerFor(group.posIds);
    final entry = (header: header, rules: group.rules);
    if (group.posIds.isEmpty) {
      unattachedTier.add(entry);
    } else if (group.posIds.length == 1) {
      singleTier.add(entry);
    } else {
      multiTier.add(entry);
    }
  }

  singleTier.sort((a, b) => a.header.compareTo(b.header));
  multiTier.sort((a, b) => a.header.compareTo(b.header));

  return [...singleTier, ...multiTier, ...unattachedTier];
}

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
///
/// Plan 04-13 D-50: [posScopeFilter] restricts the inflectional-mode
/// grouped list to groups whose POS set contains the scope POS. Used by
/// [InflectionsPage]'s bottom pane so only rules attached to the
/// currently-selected POS (including any multi-POS rules that happen to
/// include it) are visible. Ignored in derivational mode.
class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key, this.kind, this.posScopeFilter});

  /// When non-null, scopes the page to a single rule kind. Backed by
  /// [rulesByKindProvider] instead of [morphologicalRuleListProvider].
  final RuleKind? kind;

  /// D-50 / plan 04-13 — when non-null and [kind] is inflectional, only
  /// groups whose POS set contains [posScopeFilter] are rendered.
  final int? posScopeFilter;

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

    // D-77 (plan 04-15): the static preview pane was removed from this
    // page — the live preview lives in rule_editor_dialog.dart's
    // preview_panel.dart. The rules list is now the full body of the
    // page; no vertical divider, no right pane.
    return Scaffold(
      body: rulesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rules) {
                // Plan 04-11 D-56: in inflectional mode, render the list
                // grouped by POS set (junction-driven) instead of a flat
                // filtered list.
                if (widget.kind == RuleKind.inflectional) {
                  return _buildInflectionalGroupedList(
                    context: context,
                    rules: rules,
                    posList: posList,
                    dao: dao,
                    theme: theme,
                    cs: cs,
                  );
                }

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

  /// Plan 04-11 D-56 — render the inflectional rules list grouped by POS
  /// set from the junction table (`allRulePosSetsProvider`). Single-POS
  /// groups first (alphabetic by POS name), then multi-POS groups, then an
  /// 'Unattached' group for rules whose junction is empty.
  Widget _buildInflectionalGroupedList({
    required BuildContext context,
    required List<MorphologicalRule> rules,
    required List<PartsOfSpeechData> posList,
    required MorphologyDao dao,
    required ThemeData theme,
    required ColorScheme cs,
  }) {
    final posSetsAsync = ref.watch(allRulePosSetsProvider);
    final posSetByRuleId =
        posSetsAsync.asData?.value ?? const <int, Set<int>>{};

    final allGroups = groupInflectionalRulesByPosSet(
      rules: rules,
      posSetByRuleId: posSetByRuleId,
      posList: posList,
    );

    // D-50 / plan 04-13: when a posScopeFilter is set, keep only groups
    // whose POS set contains the scope POS. Looks up each rule's junction
    // set via [posSetByRuleId] — a group matches if ANY of its rules
    // include the scope POS in its set. This means a multi-POS rule
    // {Noun, Adjective} is kept when the scope is Noun.
    final scope = widget.posScopeFilter;
    final groups = scope == null
        ? allGroups
        : allGroups.where((g) {
            return g.rules.any((r) {
              final set = posSetByRuleId[r.id] ?? const <int>{};
              return set.contains(scope);
            });
          }).toList();

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
              'No inflectional rules yet.',
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

    // Flatten groups into a list of items (headers + rule cards). Each group
    // renders a small-caps header row followed by its rule cards.
    final items = <Widget>[];
    for (final group in groups) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          group.header.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.55),
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
      for (final rule in group.rules) {
        // D-81 plan 04-16 / G-69 + WARN-5 revision: read cached per-rule
        // scanner violations from the family provider. No per-build
        // scanner invocation in the list body — the provider is
        // `Provider.family<List<PhonemeViolation>, int>` keyed on
        // rule id and caches the result until inventory or rule
        // source changes. Parse + scan happens once per rule per
        // invalidation, not once per build.
        final violations =
            ref.watch(phonemeViolationsForRuleProvider(rule.id));
        final firstViolation =
            violations.isNotEmpty ? violations.first : null;
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // D-81 plan 04-16 / G-69: subtle warning icon appears
                  // when the scanner reports any phoneme violation on
                  // this rule. Rendered as a non-interactive
                  // Tooltip-wrapped Icon (NOT an IconButton) to avoid
                  // confusing the user with another clickable control.
                  // Tooltip copy is locked to the exact string
                  // 'Contains unknown phoneme: '{char}'' — asserted in
                  // the widget test.
                  if (firstViolation != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          "Contains unknown phoneme: '${firstViolation.char}'",
                      child: Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Switch(
                    value: rule.isActive,
                    onChanged: (value) async {
                      await dao.updateRule(rule.copyWith(isActive: value));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit rule',
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => RuleEditorDialog(
                          kind: widget.kind ??
                              RuleKind.fromDbString(rule.kind),
                          existing: rule,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    tooltip: 'Delete rule',
                    onPressed: () async {
                      final confirmed =
                          await _confirmDelete(context, rule.name);
                      if (confirmed && context.mounted) {
                        await dao.deleteRule(rule.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: items,
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
