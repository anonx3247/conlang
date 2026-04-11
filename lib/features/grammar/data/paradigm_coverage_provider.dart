import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../morphology/data/morphology_providers.dart';
import '../domain/dimension_level.dart';
import 'grammar_providers.dart';

/// Coverage matrix for a POS's paradigm (D-14 uncovered cells + D-15
/// coverage visibility).
///
/// Key: `(dimensionId, levelId)` — every `(dim, level)` pair owned by the
/// POS shows up exactly once.
/// Value: `true` iff there is at least one ACTIVE inflectional rule for
/// this POS whose [FeatureBindings.dims] contains an exactly-matching
/// `(dimensionId, levelId)` entry.
///
/// Used by `CoverageMatrixPanel` (green / red dots) and by the paradigm
/// table's uncovered-cell highlighter.
///
/// `inflectionalRulesForPosProvider` already:
///   - Filters by `kind == 'inflectional'`
///   - Drops inactive rules
///   - Wraps each row in an `InflectionalRule` view-model
/// so we read `r.bindings.dims.entries` directly.
final paradigmCoverageMatrixProvider =
    Provider.family<Map<(int, int), bool>, int>((ref, posId) {
  final rulesAsync = ref.watch(inflectionalRulesForPosProvider(posId));
  final rules = rulesAsync.asData?.value ?? const [];

  final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
  final dims = dimsAsync.asData?.value ?? const [];

  final coverage = <(int, int), bool>{};
  // Seed every (dim, level) pair as uncovered.
  for (final d in dims) {
    final levels = decodeLevelsJson(d.levelsJson);
    for (final l in levels) {
      coverage[(d.id, l.id)] = false;
    }
  }
  // Mark pairs covered by at least one rule's bindings.
  for (final r in rules) {
    for (final e in r.bindings.dims.entries) {
      coverage[(e.key, e.value)] = true;
    }
  }
  return coverage;
});
