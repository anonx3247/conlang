// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/data/grammar_providers.dart';
import '../../../../grammar/domain/feature_bindings.dart';
import '../../../../grammar/domain/rule_kind.dart';
import '../../../../phonology/data/romanization_providers.dart';
import '../../../application/derivation_promotion_service.dart';
import '../../../data/morphology_providers.dart';
import '../../../domain/morphology_dsl.dart';
import 'form_state_models.dart';

// ---------------------------------------------------------------------------
// Save actions — extracted from rule_editor_body.dart to stay under 500 lines.
// Contains the _save and _saveMarker logic as free async functions.
// ---------------------------------------------------------------------------

/// Result returned by [saveRule] so the caller can update its own state.
class SaveResult {
  const SaveResult({this.validationError, this.saveBlockedReason, this.done = false});
  final String? validationError;
  final String? saveBlockedReason;
  /// True when the save succeeded and the dialog should be popped.
  final bool done;
}

/// Saves an inflectional or derivational morphological rule.
///
/// Returns a [SaveResult] describing what happened. When [SaveResult.done] is
/// true the caller should pop the dialog.
Future<SaveResult> saveRule({
  required WidgetRef ref,
  required BuildContext context,
  required RuleKind kind,
  required String name,
  required List<BranchState> branches,
  required Set<int> inflectionalPosSet,
  required Map<int, int> featureBindings,
  required int? inputPosId,
  required int? outputPosId,
  required Map<int, int> outputIntrinsicLevels,
  required bool autoApply,
  required db.MorphologicalRule? existing,
}) async {
  if (name.isEmpty) {
    return const SaveResult(validationError: 'Rule name is required.');
  }
  if (kind == RuleKind.inflectional && inflectionalPosSet.isEmpty) {
    return const SaveResult(
        validationError:
            'At least one POS must be selected for inflectional rules.');
  }
  if (kind == RuleKind.inflectional && featureBindings.isEmpty) {
    return const SaveResult(
        validationError: 'Inflectional rules must bind at least one feature. '
            'Select at least one level chip above.');
  }
  final romEnabled = ref.read(romanizationEnabledProvider).asData?.value ?? true;
  final deromanize = ref.read(deromanizeProvider);
  final String Function(String)? literalTransform = romEnabled ? deromanize : null;
  final builtBranches = branches
      .map((b) => b.toBranch(literalTransform: literalTransform))
      .whereType<MorphBranch>()
      .toList();
  if (builtBranches.isEmpty) {
    return const SaveResult(
        validationError:
            'At least one branch with one operation is required.');
  }
  final tempRule =
      MorphologicalRule(id: 0, name: name, branches: builtBranches, source: '');
  final source = serializeMorphRule(tempRule);
  final dao = ref.read(morphologyDaoProvider);
  if (dao == null) return const SaveResult();

  final List<int> boundPos;
  final Map<int, int> boundDims;
  if (kind == RuleKind.inflectional) {
    boundPos = inflectionalPosSet.toList()..sort();
    boundDims = Map<int, int>.from(featureBindings);
  } else {
    boundPos = inputPosId == null ? const <int>[] : <int>[inputPosId];
    boundDims = const <int, int>{};
  }
  final builtBindings = FeatureBindings(
    pos: boundPos,
    dims: boundDims,
    outputIntrinsic: kind == RuleKind.derivational
        ? Map<int, int>.from(outputIntrinsicLevels)
        : const <int, int>{},
  );

  // D-90: block sole-intrinsic-binding rules.
  if (kind == RuleKind.inflectional &&
      builtBindings.dims.isNotEmpty && builtBindings.pos.isNotEmpty) {
    var anyPosHasNonIntrinsicAxis = false;
    for (final posId in builtBindings.pos) {
      final dims = await ref.read(dimensionsForPosProvider(posId).future);
      final intrinsicFlags = {for (final d in dims) d.id: d.intrinsic};
      final nonIntrinsicAxes = builtBindings.dims.keys
          .where((id) =>
              intrinsicFlags.containsKey(id) && intrinsicFlags[id] == false)
          .toList();
      if (nonIntrinsicAxes.isNotEmpty) {
        anyPosHasNonIntrinsicAxis = true;
        break;
      }
    }
    if (!anyPosHasNonIntrinsicAxis) {
      // ignore: lines_longer_than_80_chars
      const errorCopy =
          'Rule has no non-intrinsic axes — it would produce no paradigm variation. Intrinsic-only behavior belongs in standard-form patterns at word creation, not inflection rules.';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(errorCopy), duration: Duration(seconds: 6)));
      }
      return const SaveResult(saveBlockedReason: errorCopy);
    }
  }

  final posIdsStr =
      boundPos.isEmpty ? '' : boundPos.map((p) => '$p').join(',');
  final firstInflPosId =
      kind == RuleKind.inflectional && inflectionalPosSet.isNotEmpty
          ? inflectionalPosSet.first
          : null;
  final companionInputPos = kind == RuleKind.derivational
      ? Value<int?>(inputPosId)
      : Value<int?>(firstInflPosId);
  final companionOutputPos = kind == RuleKind.derivational
      ? Value<int?>(outputPosId)
      : const Value<int?>.absent();
  final junctionDao = ref.read(inflectionalRulePOSDaoProvider);

  int ruleIdForJunction;
  if (existing != null) {
    ruleIdForJunction = existing.id;
    await dao.updateRule(existing.copyWith(
      name: name,
      source: source,
      posIds: posIdsStr,
      kind: kind.dbString,
      featureBindings: builtBindings,
      inputPosId: kind == RuleKind.derivational
          ? Value<int?>(inputPosId)
          : Value<int?>(firstInflPosId),
      outputPosId: kind == RuleKind.derivational
          ? Value<int?>(outputPosId)
          : const Value<int?>(null),
      autoApply: kind == RuleKind.derivational ? autoApply : false,
    ));
  } else {
    final ordering = await dao.nextOrdering();
    ruleIdForJunction = await dao.insertRuleWithKind(
      db.MorphologicalRulesCompanion(
        name: Value(name),
        source: Value(source),
        ordering: Value(ordering),
        posIds: Value(posIdsStr),
        featureBindings: Value(builtBindings),
        inputPosId: companionInputPos,
        outputPosId: companionOutputPos,
        autoApply: Value(kind == RuleKind.derivational ? autoApply : false),
      ),
      kind,
    );
  }
  if (kind == RuleKind.inflectional && junctionDao != null) {
    await junctionDao.replaceForRule(
        ruleId: ruleIdForJunction, posIds: Set<int>.from(inflectionalPosSet));
  }
  if (kind == RuleKind.derivational && autoApply) {
    await ref.read(derivationPromotionServiceProvider).reconcile();
  }
  return const SaveResult(done: true);
}

/// Saves a marker (zero-form / unmarked cell indicator).
///
/// Returns a [SaveResult]. When [SaveResult.done] is true the caller should
/// pop the dialog.
Future<SaveResult> saveMarker({
  required WidgetRef ref,
  required Map<int, int> featureBindings,
  required Set<int> inflectionalPosSet,
  required String name,
  required int? markerId,
}) async {
  if (featureBindings.isEmpty) {
    return const SaveResult(
        validationError:
            'Select at least one dimension + level to mark as unmarked.');
  }
  if (inflectionalPosSet.isEmpty) {
    return const SaveResult(
        validationError: 'Select at least one POS to attach this marker to.');
  }
  final dao = ref.read(markerDaoProvider);
  if (dao == null) return const SaveResult();
  final bindings = FeatureBindings(
    pos: [inflectionalPosSet.first],
    dims: Map<int, int>.from(featureBindings),
  );
  final posId = inflectionalPosSet.first;
  final markerName = name.isEmpty ? 'Unmarked' : name;
  if (markerId != null) {
    await dao.updateMarker(markerId, bindings, markerName);
  } else {
    await dao.insertMarker(posId: posId, bindings: bindings, name: markerName);
  }
  return const SaveResult(done: true);
}
