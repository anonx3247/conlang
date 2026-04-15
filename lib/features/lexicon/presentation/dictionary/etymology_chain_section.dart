import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../grammar/data/grammar_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/lexeme_providers.dart';
import '../../domain/ancestry_node.dart';
import 'searchable_parent_selector.dart';

/// Visual etymology tree for a [Lexeme] (Phase 11 LEX-09).
///
/// Layout: ancestor levels render top-to-bottom with same-depth nodes in a
/// single row, connected by thin lines. The current word is highlighted.
/// Immediate children appear below the current word.
///
/// Hidden for isolated root words (no parents, no children, not derived).
class EtymologyChainSection extends ConsumerStatefulWidget {
  const EtymologyChainSection({
    super.key,
    required this.lexeme,
    this.onNavigateToWord,
  });

  final Lexeme lexeme;
  final ValueChanged<int>? onNavigateToWord;

  @override
  ConsumerState<EtymologyChainSection> createState() =>
      _EtymologyChainSectionState();
}

class _EtymologyChainSectionState
    extends ConsumerState<EtymologyChainSection> {
  bool _addingParent = false;

  // ---------------------------------------------------------------------------
  // Tree flattening
  // ---------------------------------------------------------------------------

  /// Flattens the ancestry DAG into depth-ordered levels.
  ///
  /// Returns `[ [deepest ancestors], …, [direct parents] ]` so callers render
  /// from index 0 (top) downward to the current word. Each lexeme appears at
  /// most once (first-encounter depth wins for shared ancestors).
  static List<List<AncestryNode>> _flattenAncestry(AncestryNode node) {
    final Map<int, List<AncestryNode>> byDepth = {};
    final seen = <int>{};
    _traverse(node.parents, 1, byDepth, seen);
    if (byDepth.isEmpty) return [];
    final maxD = byDepth.keys.reduce(max);
    return [for (int d = maxD; d >= 1; d--) byDepth[d] ?? []];
  }

  static void _traverse(
    List<AncestryNode> nodes,
    int depth,
    Map<int, List<AncestryNode>> out,
    Set<int> seen,
  ) {
    for (final n in nodes) {
      if (seen.contains(n.lexemeId)) continue;
      seen.add(n.lexemeId);
      out.putIfAbsent(depth, () => []).add(n);
      if (n.parents.isNotEmpty) {
        _traverse(n.parents, depth + 1, out, seen);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final ancestryNode = ref.watch(ancestryChainProvider(widget.lexeme.id));

    final manualChildren =
        ref.watch(childrenForLexemeProvider(widget.lexeme.id))
                .asData
                ?.value ??
            const <LexemeParentRow>[];

    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];

    final ruleDerivedChildren = allLexemes
        .where((lx) => lx.derivedFromLexemeId == widget.lexeme.id)
        .toList();

    final hasAncestors =
        ancestryNode != null && ancestryNode.parents.isNotEmpty;
    final hasChildren =
        manualChildren.isNotEmpty || ruleDerivedChildren.isNotEmpty;
    final isDerived = widget.lexeme.derivedFromLexemeId != null;

    if (!hasAncestors && !hasChildren && !isDerived) {
      return const SizedBox.shrink();
    }

    final ancestryLevels =
        ancestryNode != null ? _flattenAncestry(ancestryNode) : <List<AncestryNode>>[];

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Etymology Chain',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Ancestor levels — deepest first (top of tree)
          for (final level in ancestryLevels) ...[
            _levelRow(context, level),
            _connector(context, nodeCount: level.length),
          ],

          // Current word (highlighted)
          _currentWordRow(context),

          // Children
          if (hasChildren) ...[
            _connector(context, nodeCount: 1, inverted: true),
            _childrenRow(
                context, ruleDerivedChildren, manualChildren, allLexemes),
          ],

          // Inline parent management
          const SizedBox(height: 10),
          _buildAddParentSection(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Level rows
  // ---------------------------------------------------------------------------

  Widget _levelRow(BuildContext context, List<AncestryNode> nodes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _ancestorChip(context, nodes[i]),
        ],
      ],
    );
  }

  Widget _childrenRow(
    BuildContext context,
    List<Lexeme> ruleDerived,
    List<LexemeParentRow> manual,
    List<Lexeme> allLexemes,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final rules = rulesAsync.asData?.value ?? const [];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < ruleDerived.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _childLexemeChip(context, ruleDerived[i], rules, cs),
        ],
        for (int i = 0; i < manual.length; i++) ...[
          if (i > 0 || ruleDerived.isNotEmpty) const SizedBox(width: 6),
          _childManualChip(context, manual[i], allLexemes, cs),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Chips
  // ---------------------------------------------------------------------------

  Widget _ancestorChip(BuildContext context, AncestryNode node) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (node.isTruncated) {
      return Text(
        '↑ more ancestors',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
        textAlign: TextAlign.center,
      );
    }

    if (node.isCycle) {
      return Chip(
        backgroundColor: Colors.amber.shade100,
        avatar: const Icon(Icons.warning_rounded, size: 12),
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
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _pill(
            context,
            cs: cs,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  forms.rom,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (node.lexeme?.meaning != null &&
                    node.lexeme!.meaning!.isNotEmpty)
                  Text(
                    node.lexeme!.meaning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (node.edgeLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              node.edgeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: cs.primary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _currentWordRow(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final promoted =
        ref.watch(promotedDerivedFormProvider(widget.lexeme.id));
    final forms = resolveDisplayForms(widget.lexeme, promoted);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.primary, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                forms.rom,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.lexeme.meaning != null &&
                  widget.lexeme.meaning!.isNotEmpty)
                Text(
                  widget.lexeme.meaning!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _childLexemeChip(
      BuildContext context,
      Lexeme child,
      List<MorphologicalRule> rules,
      ColorScheme cs) {
    final theme = Theme.of(context);
    final promoted = ref.watch(promotedDerivedFormProvider(child.id));
    final forms = resolveDisplayForms(child, promoted);
    final ruleId = child.derivedViaRuleId;
    final rule = ruleId != null
        ? rules.where((r) => r.id == ruleId).firstOrNull
        : null;
    final edgeLabel = rule != null ? 'via ${rule.name}' : 'rule-derived';

    return InkWell(
      onTap: widget.onNavigateToWord != null
          ? () => widget.onNavigateToWord!(child.id)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _pill(
            context,
            cs: cs,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  forms.rom,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                if (child.meaning != null && child.meaning!.isNotEmpty)
                  Text(
                    child.meaning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            edgeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _childManualChip(
      BuildContext context,
      LexemeParentRow row,
      List<Lexeme> allLexemes,
      ColorScheme cs) {
    final theme = Theme.of(context);
    final child =
        allLexemes.where((l) => l.id == row.childLexemeId).firstOrNull;
    if (child == null) return const SizedBox.shrink();

    final promoted = ref.watch(promotedDerivedFormProvider(child.id));
    final forms = resolveDisplayForms(child, promoted);
    final edgeLabel =
        row.relationship?.isNotEmpty == true ? row.relationship! : 'parent';

    return InkWell(
      onTap: widget.onNavigateToWord != null
          ? () => widget.onNavigateToWord!(child.id)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _pill(
            context,
            cs: cs,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  forms.rom,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                if (child.meaning != null && child.meaning!.isNotEmpty)
                  Text(
                    child.meaning!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            edgeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Shared pill wrapper
  Widget _pill(BuildContext context,
      {required ColorScheme cs, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Connectors
  // ---------------------------------------------------------------------------

  /// Draws a connecting line between the row above (with [nodeCount] nodes)
  /// and the row below (single node).
  ///
  /// [inverted] flips the fan direction so it works below the current word
  /// when connecting down to children.
  Widget _connector(BuildContext context,
      {required int nodeCount, bool inverted = false}) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 18,
      child: CustomPaint(
        size: const Size(double.infinity, 18),
        painter: _ConnectorPainter(
          nodeCount: nodeCount,
          color: cs.outlineVariant,
          inverted: inverted,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline parent management
  // ---------------------------------------------------------------------------

  Widget _buildAddParentSection(BuildContext context) {
    if (!_addingParent) {
      return Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _addingParent = true),
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add parent', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
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
            for (final id in newIds.difference(manualParentIds)) {
              dao.insertParent(
                  childLexemeId: widget.lexeme.id, parentLexemeId: id);
            }
            for (final id in manualParentIds.difference(newIds)) {
              dao.deleteParent(
                  childLexemeId: widget.lexeme.id, parentLexemeId: id);
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

// ---------------------------------------------------------------------------
// Connector painter
// ---------------------------------------------------------------------------

/// Paints a vertical tree connector between two rows.
///
/// - [nodeCount] = 1 → straight vertical line through the center.
/// - [nodeCount] > 1 → a "fan" shape: vertical lines rise from the top corners
///   of the connector to a horizontal bar, which drops a single line to the
///   center bottom. This represents multiple nodes above connecting to one
///   node below.
/// - [inverted] flips the fan so it fans OUT going downward (one node above →
///   multiple nodes below).
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.nodeCount,
    required this.color,
    this.inverted = false,
  });

  final int nodeCount;
  final Color color;
  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final h = size.height;

    if (nodeCount <= 1) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, h), paint);
      return;
    }

    // Fan: spread percentage depends on count
    final spread = (nodeCount == 2 ? 0.30 : 0.45).clamp(0.0, 0.48);
    final leftX = size.width * (0.5 - spread);
    final rightX = size.width * (0.5 + spread);

    final barY = inverted ? h * 0.6 : h * 0.4;

    if (!inverted) {
      // Multiple nodes above, single node below
      // ─ Vertical lines from top to bar
      canvas.drawLine(Offset(leftX, 0), Offset(leftX, barY), paint);
      canvas.drawLine(Offset(rightX, 0), Offset(rightX, barY), paint);
      if (nodeCount >= 3) {
        canvas.drawLine(Offset(cx, 0), Offset(cx, barY), paint);
      }
      // ─ Horizontal bar
      canvas.drawLine(Offset(leftX, barY), Offset(rightX, barY), paint);
      // ─ Single drop to bottom
      canvas.drawLine(Offset(cx, barY), Offset(cx, h), paint);
    } else {
      // Single node above, multiple nodes below
      canvas.drawLine(Offset(cx, 0), Offset(cx, barY), paint);
      canvas.drawLine(Offset(leftX, barY), Offset(rightX, barY), paint);
      canvas.drawLine(Offset(leftX, barY), Offset(leftX, h), paint);
      canvas.drawLine(Offset(rightX, barY), Offset(rightX, h), paint);
      if (nodeCount >= 3) {
        canvas.drawLine(Offset(cx, barY), Offset(cx, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.nodeCount != nodeCount ||
      old.color != color ||
      old.inverted != inverted;
}
