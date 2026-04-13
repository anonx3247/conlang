// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import '../../../domain/morphology_dsl.dart';

// ---------------------------------------------------------------------------
// Form state models — extracted from rule_editor_dialog.dart (D-13)
// ---------------------------------------------------------------------------

/// Operation types the editor supports (matches MorphOperation sealed class).
enum OpType {
  prefix('Prefix (add to start)'),
  suffix('Suffix (add to end)'),
  infix('Infix (insert inside)'),
  ablaut('Replace'),
  template('Root template'),
  reduplication('Reduplication (copy)'),
  suppletive('Whole-word override (irregular)');

  const OpType(this.label);
  final String label;
}

/// Mutable state for a single operation row in the form.
class OpState {
  OpType type;
  // Shared/specific field controllers
  final TextEditingController affixCtrl = TextEditingController(); // prefix/suffix/infix
  final TextEditingController posCtrl = TextEditingController(text: '1'); // infix position
  final TextEditingController ablautFromCtrl = TextEditingController();
  final TextEditingController ablautToCtrl = TextEditingController();
  final TextEditingController templateCtrl = TextEditingController();
  String redupScope; // 'full' | 'CV' | 'C'
  String redupPosition; // 'prefix' | 'suffix'
  final TextEditingController suppletiveCtrl = TextEditingController();
  // Ablaut direction and count
  AblautDirection ablautDirection;
  int? ablautCount; // null = all

  // D-73 (plan 04-15): RAW phonemic values stashed at load time. Used by
  // the build-time rom hydration pass to re-populate the controllers once
  // the romanizationMappingsProvider stream has resolved.
  String? rawAffix;
  String? rawAblautFrom;
  String? rawAblautTo;
  String? rawSuppletive;

  OpState()
      : type = OpType.suffix,
        redupScope = 'CV',
        redupPosition = 'prefix',
        ablautDirection = AblautDirection.fromStart,
        ablautCount = null;

  void dispose() {
    affixCtrl.dispose();
    posCtrl.dispose();
    ablautFromCtrl.dispose();
    ablautToCtrl.dispose();
    templateCtrl.dispose();
    suppletiveCtrl.dispose();
  }

  /// Convert to domain [MorphOperation]. Returns null if fields are incomplete.
  ///
  /// D-73 (plan 04-15): when [literalTransform] is non-null, it is applied to
  /// every SINGLE-TOKEN literal-phoneme field (affix, ablaut from/to,
  /// suppletive) before the MorphOperation is constructed. Used by save to
  /// route field values through `deromanize` when rom mode is active so the
  /// stored MorphologicalRules.source is always phonemic.
  ///
  /// WARN-1 / D-73 partial: template literal runs are NOT transformed — the
  /// template pattern uses structural digit/char semantics and in the 04-15
  /// deferred scope we store the template as-typed. See must_haves.truths.
  MorphOperation? toOperation({String Function(String)? literalTransform}) {
    String t(String s) =>
        literalTransform == null ? s : literalTransform(s);
    return switch (type) {
      OpType.prefix => affixCtrl.text.trim().isNotEmpty
          ? PrefixOp(t(affixCtrl.text.trim()))
          : null,
      OpType.suffix => affixCtrl.text.trim().isNotEmpty
          ? SuffixOp(t(affixCtrl.text.trim()))
          : null,
      OpType.infix => () {
          final affix = affixCtrl.text.trim();
          final pos = int.tryParse(posCtrl.text.trim()) ?? 1;
          return affix.isNotEmpty
              ? InfixOp(affix: t(affix), position: pos)
              : null;
        }(),
      OpType.ablaut => () {
          final from = ablautFromCtrl.text.trim();
          final to = ablautToCtrl.text.trim();
          return (from.isNotEmpty && to.isNotEmpty)
              ? AblautOp(
                  from: t(from),
                  to: t(to),
                  count: ablautCount,
                  direction: ablautDirection,
                )
              : null;
        }(),
      OpType.template => templateCtrl.text.trim().isNotEmpty
          // D-73 partial deferred: template literal runs NOT transformed.
          ? TemplateOp(templateCtrl.text.trim())
          : null,
      OpType.reduplication =>
        RedupOp(scope: redupScope, position: redupPosition),
      OpType.suppletive => suppletiveCtrl.text.trim().isNotEmpty
          ? SuppleteOp(t(suppletiveCtrl.text.trim()))
          : null,
    };
  }
}

/// Mutable state for a single condition in a branch.
class CondState {
  CondPosition position;
  final TextEditingController patternCtrl;

  CondState({this.position = CondPosition.contains, String pattern = ''})
      : patternCtrl = TextEditingController(text: pattern);

  void dispose() {
    patternCtrl.dispose();
  }
}

/// Mutable state for a single branch in the form.
class BranchState {
  List<CondState> conditions;
  final List<OpState> ops;

  BranchState({List<OpState>? ops})
      : conditions = [CondState()],
        ops = ops ?? [OpState()];

  void dispose() {
    for (final c in conditions) {
      c.dispose();
    }
    for (final op in ops) {
      op.dispose();
    }
  }

  /// Convert to domain [MorphBranch]. Returns null if all operations are incomplete.
  ///
  /// D-73 (plan 04-15): see [toOperation] — [literalTransform] is forwarded
  /// to every op's literal-token fields. Condition patterns are NOT
  /// transformed (WARN-1 deferred).
  MorphBranch? toBranch({String Function(String)? literalTransform}) {
    final operations = ops
        .map((o) => o.toOperation(literalTransform: literalTransform))
        .whereType<MorphOperation>()
        .toList();
    if (operations.isEmpty) return null;

    final conds = conditions
        .where((c) => c.patternCtrl.text.trim().isNotEmpty)
        .map((c) => PatternCond(
              // WARN-1 / D-73 partial: condition patterns are NOT
              // transformed in 04-15 — structural literal-run wrapping is
              // deferred to a follow-up plan.
              c.patternCtrl.text.trim(),
              position: c.position,
            ) as MorphCondition)
        .toList();

    return MorphBranch(conditions: conds, operations: operations);
  }
}
