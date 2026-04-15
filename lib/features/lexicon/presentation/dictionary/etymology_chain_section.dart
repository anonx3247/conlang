import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/lexeme_providers.dart';
import '../../domain/ancestry_node.dart';
import 'searchable_parent_selector.dart';

/// Displays the full derivational ancestry chain of a [Lexeme] as an
/// indented tree with connector lines (Phase 11 LEX-09).
///
/// The section renders:
/// - **Ancestry tree** — ancestors above the current word, indented by level
/// - **Current word node** — highlighted with a primary left border
/// - **Immediate children** — rule-derived and manual children one level below
/// - **Inline parent management** — toggle to add/remove manual parent links
///
/// Hidden entirely when the word has no parents, no children, and no
/// derivedFromLexemeId (isolated root words do not need an etymology section).
class EtymologyChainSection extends ConsumerStatefulWidget {
  const EtymologyChainSection({
    super.key,
    required this.lexeme,
    this.onNavigateToWord,
  });

  final Lexeme lexeme;

  /// Called when the user taps an ancestor or child node to navigate to it.
  final ValueChanged<int>? onNavigateToWord;

  @override
  ConsumerState<EtymologyChainSection> createState() =>
      _EtymologyChainSectionState();
}

class _EtymologyChainSectionState extends ConsumerState<EtymologyChainSection> {
  bool _addingParent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ancestryNode =
        ref.watch(ancestryChainProvider(widget.lexeme.id));

    // Manual children (this lexeme is listed as a parent in LexemeParents).
    final manualChildrenAsync =
        ref.watch(childrenForLexemeProvider(widget.lexeme.id));
    final manualChildren =
        manualChildrenAsync.asData?.value ?? const <LexemeParentRow>[];

    // Rule-derived children: stored lexemes whose derivedFromLexemeId points
    // here. Computed-only (non-stored) derivations are shown by DerivationTreeWidget.
    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];
    final ruleDerivedChildren = allLexemes
        .where((lx) => lx.derivedFromLexemeId == widget.lexeme.id)
        .toList();

    // Hide for isolated root words (no ancestry, no children, not derived).
    final hasAncestors =
        ancestryNode != null && ancestryNode.parents.isNotEmpty;
    final hasChildren =
        manualChildren.isNotEmpty || ruleDerivedChildren.isNotEmpty;
    final isDerived = widget.lexeme.derivedFromLexemeId != null;

    if (!hasAncestors && !hasChildren && !isDerived) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Etymology Chain',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Ancestry tree (ancestors above current word)
          if (hasAncestors)
            for (final parent in ancestryNode.parents)
              _buildAncestryRow(context, parent, 0),

          // Current word node (highlighted)
          _buildCurrentWordNode(context),

          // Rule-derived children
          for (final child in ruleDerivedChildren)
            _buildRuleDerivedChildRow(context, child),

          // Manual children
          for (final row in manualChildren)
            _buildManualChildRow(context, row, allLexemes),

          // Inline parent management
          const SizedBox(height: 8),
          _buildAddParentSection(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ancestry tree rendering
  // ---------------------------------------------------------------------------

  Widget _buildAncestryRow(
      BuildContext context, AncestryNode node, int level) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Truncation hint at the top of a branch that was cut short.
    if (node.isTruncated) {
      return Padding(
        padding: EdgeInsets.only(left: level * 20.0, top: 2, bottom: 2),
        child: Text(
          '\u2191 more ancestors',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Render this node's own parents first (tree grows upward).
        for (final parent in node.parents)
          _buildAncestryRow(context, parent, level + 1),

        // Then render this node itself.
        Padding(
          padding: EdgeInsets.only(left: level * 20.0, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (level > 0 || node.parents.isNotEmpty)
                Container(
                  width: 12,
                  height: 1,
                  color: cs.outlineVariant,
                  margin: const EdgeInsets.only(right: 4, top: 10),
                ),
              Flexible(
                child: _buildNodeChip(context, node, isAncestor: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Node chip (ancestor / child)
  // ---------------------------------------------------------------------------

  Widget _buildNodeChip(
    BuildContext context,
    AncestryNode node, {
    required bool isAncestor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Cycle sentinel — show a warning chip instead of recursing.
    if (node.isCycle) {
      return Chip(
        backgroundColor: Colors.amber.shade100,
        avatar: const Icon(Icons.warning_rounded, size: 14),
        label: const Text('cycle', style: TextStyle(fontSize: 11)),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }

    final promoted = ref.watch(promotedDerivedFormProvider(node.lexemeId));
    final forms = node.lexeme != null
        ? resolveDisplayForms(node.lexeme!, promoted)
        : (rom: '?', ipa: '?');

    return InkWell(
      onTap: widget.onNavigateToWord != null
          ? () => widget.onNavigateToWord!(node.lexemeId)
          : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAncestor ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: cs.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    forms.rom,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (node.lexeme?.meaning != null &&
                node.lexeme!.meaning!.isNotEmpty)
              Text(
                node.lexeme!.meaning!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            if (node.edgeLabel.isNotEmpty)
              Text(
                node.edgeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Current word node (highlighted, non-tappable)
  // ---------------------------------------------------------------------------

  Widget _buildCurrentWordNode(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final promoted =
        ref.watch(promotedDerivedFormProvider(widget.lexeme.id));
    final forms = resolveDisplayForms(widget.lexeme, promoted);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: cs.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            forms.rom,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.lexeme.meaning != null &&
              widget.lexeme.meaning!.isNotEmpty)
            Text(
              widget.lexeme.meaning!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Children rows
  // ---------------------------------------------------------------------------

  Widget _buildRuleDerivedChildRow(BuildContext context, Lexeme child) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final promoted = ref.watch(promotedDerivedFormProvider(child.id));
    final forms = resolveDisplayForms(child, promoted);

    // Look up rule name for the edge label.
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? const [];
    final rule = rules
        .where((r) => r.id == child.derivedViaRuleId)
        .firstOrNull;
    final edgeLabel =
        rule != null ? 'via ${rule.name}' : 'rule-derived';

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 1,
            color: cs.outlineVariant,
            margin: const EdgeInsets.only(right: 4, top: 10),
          ),
          Flexible(
            child: InkWell(
              onTap: widget.onNavigateToWord != null
                  ? () => widget.onNavigateToWord!(child.id)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            forms.rom,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (child.meaning != null && child.meaning!.isNotEmpty)
                      Text(
                        child.meaning!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    Text(
                      edgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualChildRow(
      BuildContext context, LexemeParentRow row, List<Lexeme> allLexemes) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final child =
        allLexemes.where((l) => l.id == row.childLexemeId).firstOrNull;
    if (child == null) return const SizedBox.shrink();

    final promoted = ref.watch(promotedDerivedFormProvider(child.id));
    final forms = resolveDisplayForms(child, promoted);
    final edgeLabel = row.relationship?.isNotEmpty == true
        ? row.relationship!
        : 'parent';

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 1,
            color: cs.outlineVariant,
            margin: const EdgeInsets.only(right: 4, top: 10),
          ),
          Flexible(
            child: InkWell(
              onTap: widget.onNavigateToWord != null
                  ? () => widget.onNavigateToWord!(child.id)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            forms.rom,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (child.meaning != null && child.meaning!.isNotEmpty)
                      Text(
                        child.meaning!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    Text(
                      edgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline parent management
  // ---------------------------------------------------------------------------

  Widget _buildAddParentSection(BuildContext context) {
    if (!_addingParent) {
      return TextButton.icon(
        onPressed: () => setState(() => _addingParent = true),
        icon: const Icon(Icons.add, size: 16),
        label:
            const Text('Add parent', style: TextStyle(fontSize: 12)),
      );
    }

    final manualParentRows =
        ref.watch(parentsForLexemeProvider(widget.lexeme.id)).asData?.value ??
            const <LexemeParentRow>[];
    final manualParentIds =
        manualParentRows.map((r) => r.parentLexemeId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchableParentSelector(
          selectedIds: manualParentIds,
          onChanged: (newIds) {
            final dao = ref.read(lexemeParentsDaoProvider);
            if (dao == null) return;
            // Add new parents
            for (final id in newIds.difference(manualParentIds)) {
              dao.insertParent(
                  childLexemeId: widget.lexeme.id,
                  parentLexemeId: id);
            }
            // Remove deleted parents
            for (final id in manualParentIds.difference(newIds)) {
              dao.deleteParent(
                  childLexemeId: widget.lexeme.id,
                  parentLexemeId: id);
            }
          },
          excludeId: widget.lexeme.id,
        ),
        TextButton(
          onPressed: () => setState(() => _addingParent = false),
          child: const Text('Done', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
