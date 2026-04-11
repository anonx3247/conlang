import 'feature_bindings.dart';

/// An unmarked-cell declaration for an inflectional paradigm
/// (Phase 4 gap D-43 / D-44).
///
/// A marker asserts that a feature-binding set produces NO form change at
/// the cell(s) it matches — the root IS the form. Parallel in shape to
/// [InflectionalRule] but:
///   - No DSL / no form output
///   - Always inflectional-scoped (no kind discriminator)
///   - Resolution: D-45 order is override -> rule -> marker -> uncovered
///   - Specificity: D-10 algorithm (`bindings.dims.length`). On exact ties
///     with a rule, the rule wins (D-46) — rules carry an explicit form,
///     markers assert absence.
///
/// Named [MarkerDecl] rather than `Marker` to avoid colliding with the
/// Drift-generated row class `Marker` produced for the `Markers` table in
/// `app_database.dart`. Both live in the `lib/features/grammar/` subtree and
/// must be importable side-by-side without a type alias dance.
class MarkerDecl {
  const MarkerDecl({
    required this.id,
    required this.posId,
    required this.bindings,
  });

  final int id;
  final int posId;
  final FeatureBindings bindings;

  /// D-10 step 3 — specificity for the marker-vs-rule contest in the
  /// paradigm engine. Mirrors [InflectionalRule.specificity].
  int get specificity => bindings.specificity;

  /// True iff this marker's feature bindings are a subset of [target].
  ///
  /// An unbound marker (empty `bindings.dims`) never fires — this matches
  /// the `_isSubset` guard in [computeParadigmCell] and the D-13 rule that
  /// unbound rules never participate in inflection.
  bool matches(Map<int, int> target) {
    if (bindings.dims.isEmpty) return false;
    for (final entry in bindings.dims.entries) {
      if (target[entry.key] != entry.value) return false;
    }
    return true;
  }
}
