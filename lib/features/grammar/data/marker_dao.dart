import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/feature_bindings.dart';
import '../domain/marker.dart';

part 'marker_dao.g.dart';

/// Drift DAO for the Phase 4 gap `Markers` table (v9, D-44).
///
/// Parallel in spirit to `GrammarDao` (dimensions) and `MorphologyDao`
/// (rules): a thin accessor over a single table. Markers carry only a
/// feature-binding set and the POS they belong to — no DSL, no name, no
/// ordering — so CRUD is minimal.
///
/// The row class Drift generates for the `Markers` table is `Marker`
/// (Drift's default singularisation). This DAO returns the domain value
/// type [MarkerDecl] instead so downstream code (paradigm engine,
/// widgets) is decoupled from the Drift row shape.
@DriftAccessor(tables: [Markers])
class MarkerDao extends DatabaseAccessor<AppDatabase> with _$MarkerDaoMixin {
  MarkerDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Streams every marker bound to [posId], newest-first (by id desc so
  /// UI insertions surface at the top of a list without an explicit
  /// `ordering` column).
  Stream<List<MarkerDecl>> watchMarkersForPos(int posId) {
    return (select(markers)
          ..where((t) => t.posId.equals(posId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => MarkerDecl(
                  id: r.id,
                  posId: r.posId,
                  bindings: r.featureBindings,
                ),
              )
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new marker with the given [bindings] on [posId]. Returns
  /// the generated row id.
  Future<int> insertMarker({
    required int posId,
    required FeatureBindings bindings,
  }) {
    return into(markers).insert(
      MarkersCompanion.insert(
        posId: posId,
        featureBindings: Value(bindings),
      ),
    );
  }

  /// Replaces the feature-binding set on an existing marker row.
  Future<void> updateMarker(int id, FeatureBindings bindings) async {
    await (update(markers)..where((t) => t.id.equals(id))).write(
      MarkersCompanion(featureBindings: Value(bindings)),
    );
  }

  /// Deletes the marker with the given [id]. Returns the number of rows
  /// removed (0 or 1).
  Future<int> deleteMarker(int id) =>
      (delete(markers)..where((t) => t.id.equals(id))).go();
}
