import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../morphology/data/morphology_providers.dart';
import '../domain/coverage_matrix.dart';
import '../domain/dimension_level.dart';
import '../domain/inflectional_rule.dart';
import 'grammar_providers.dart';

/// D-91 — 04-17. Intrinsic-aware coverage matrix for a POS's paradigm.
///
/// Axes are the union of dimensions referenced by at least one active
/// inflectional rule's featureBindings for this POS — intrinsic and
/// non-intrinsic alike are included IF referenced. Unreferenced intrinsic
/// dims collapse out. Cells are the Cartesian product of (axis × levels).
/// A cell is covered iff at least one rule's binding map matches it: a
/// rule with no binding on a given axis covers ALL levels of that axis.
///
/// Returns a [CoverageMatrix] with [FeatureSetKey]-keyed cells so value
/// equality works (BLOCKER-3 — raw `Map<Map<int,int>, bool>` would
/// silently miss every lookup because Maps hash by reference).
///
/// Consumed by `CoverageMatrixPanel` (green / red dots) and any future
/// paradigm-table uncovered-cell highlighter.
final paradigmCoverageMatrixProvider =
    Provider.family<CoverageMatrix, int>((ref, posId) {
  final rulesAsync = ref.watch(inflectionalRulesForPosProvider(posId));
  final rules = rulesAsync.asData?.value ?? const <InflectionalRule>[];
  final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
  final dims = dimsAsync.asData?.value ?? const [];

  // Step 1 — union of dim ids referenced by at least one rule.
  final referencedDimensionIds = <int>{};
  for (final r in rules) {
    referencedDimensionIds.addAll(r.bindings.dims.keys);
  }

  // Step 2 — axes = dims whose id is referenced. Stable order by id.
  final axes = dims
      .where((d) => referencedDimensionIds.contains(d.id))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final axisIds = axes.map((d) => d.id).toList();

  // Edge case: no axes means no cells. Return an empty matrix without
  // seeding the product builder (which would otherwise start with a
  // single empty map and emit one degenerate cell).
  if (axes.isEmpty) {
    return const CoverageMatrix(axes: [], cells: {});
  }

  // Step 3 — Cartesian product of axis × levels. Raw Map<int,int>
  // accumulators here are fine: they're transient builder state, not
  // the final cell keys (which go through FeatureSetKey).
  List<Map<int, int>> product = [<int, int>{}];
  for (final axis in axes) {
    final levels = decodeLevelsJson(axis.levelsJson);
    if (levels.isEmpty) {
      // An axis with zero levels collapses the product to empty.
      product = const [];
      break;
    }
    final next = <Map<int, int>>[];
    for (final partial in product) {
      for (final lv in levels) {
        next.add({...partial, axis.id: lv.id});
      }
    }
    product = next;
  }

  // Step 4 — per-cell covered check. A rule with no binding on an axis
  // covers all levels of that axis.
  bool ruleCoversCell(InflectionalRule r, Map<int, int> cell) {
    for (final axisId in axisIds) {
      final ruleBinding = r.bindings.dims[axisId];
      if (ruleBinding == null) continue; // wildcard on this axis
      if (ruleBinding != cell[axisId]) return false;
    }
    return true;
  }

  final cells = <FeatureSetKey, bool>{};
  for (final cell in product) {
    final covered = rules.any((r) => ruleCoversCell(r, cell));
    // BLOCKER-3 — wrap in FeatureSetKey so lookups are value-equal.
    cells[FeatureSetKey(cell)] = covered;
  }

  return CoverageMatrix(axes: axisIds, cells: cells);
});
