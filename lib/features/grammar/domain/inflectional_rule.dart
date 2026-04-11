import '../../../db/app_database.dart' as db;
import 'feature_bindings.dart';

/// View-model wrapping a Drift [db.MorphologicalRule] row with its
/// [FeatureBindings] already parsed, suitable for paradigm engine use.
///
/// This type is non-Drift-dependent at call sites — the paradigm engine
/// consumes `List<InflectionalRule>` without touching SQL.
///
/// Only construct via [InflectionalRule.fromDbRow] after verifying the
/// source row has `kind == 'inflectional'`. Passing a derivational row is
/// an assertion failure in debug builds.
class InflectionalRule {
  const InflectionalRule({
    required this.id,
    required this.name,
    required this.source,
    required this.isActive,
    required this.bindings,
  });

  final int id;
  final String name;

  /// DSL source string (e.g. `"-s"`, `"+un-"`, `"C1a-C2i-C3u"`).
  final String source;
  final bool isActive;
  final FeatureBindings bindings;

  factory InflectionalRule.fromDbRow(db.MorphologicalRule row) {
    assert(
      row.kind == 'inflectional',
      'InflectionalRule.fromDbRow called on non-inflectional row '
      '(id=${row.id}, kind=${row.kind})',
    );
    return InflectionalRule(
      id: row.id,
      name: row.name,
      source: row.source,
      isActive: row.isActive,
      bindings: row.featureBindings,
    );
  }

  /// D-10 step 3 — specificity for the "most specific rule wins" picker in
  /// the paradigm engine.
  int get specificity => bindings.specificity;
}
