import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/dimension_level.dart';

part 'grammar_dao.g.dart';

/// Drift DAO for the Phase 4 `Dimensions` table.
///
/// This is a THIN grammar-side DAO separate from `MorphologyDao`. Per D-41,
/// rule CRUD still lives in `MorphologyDao`. This DAO only owns the
/// Dimensions table because that table is Grammar-scoped.
///
/// Obtain via `currentDatabase.grammarDao` or the Riverpod
/// `grammarDaoProvider` which derives it from the active project database.
@DriftAccessor(tables: [Dimensions])
class GrammarDao extends DatabaseAccessor<AppDatabase> with _$GrammarDaoMixin {
  GrammarDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Watches all dimensions for a POS, ordered by `ordering` ascending.
  Stream<List<Dimension>> watchDimensionsForPos(int posId) {
    return (select(dimensions)
          ..where((t) => t.posId.equals(posId))
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .watch();
  }

  /// Returns the next `ordering` value to use when inserting a new dimension
  /// on [posId] (max(ordering) + 1, or 0 if none exist).
  Future<int> nextDimensionOrdering(int posId) async {
    final existing = await (select(dimensions)
          ..where((t) => t.posId.equals(posId)))
        .get();
    if (existing.isEmpty) return 0;
    return existing.map((d) => d.ordering).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Returns the next level id for a dimension — `max(level.id) + 1` across
  /// the dimension's existing `levelsJson`, or `1` if the list is empty.
  ///
  /// Uses the [decodeLevelsJson] helper so malformed JSON is treated as an
  /// empty list (returns 1).
  Future<int> nextLevelId(int dimensionId) async {
    final row = await (select(dimensions)
          ..where((t) => t.id.equals(dimensionId)))
        .getSingle();
    final levels = decodeLevelsJson(row.levelsJson);
    if (levels.isEmpty) return 1;
    return levels.map((l) => l.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new dimension and returns its generated row id.
  Future<int> insertDimension(DimensionsCompanion c) =>
      into(dimensions).insert(c);

  /// Replaces all fields of an existing dimension row.
  Future<bool> updateDimension(Dimension d) => update(dimensions).replace(d);

  /// Convenience: encodes [levels] and writes them to the dimension's
  /// `levels_json` column. Returns the number of rows affected (1 on success).
  Future<int> updateDimensionLevels(
    int dimensionId,
    List<DimensionLevel> levels,
  ) {
    return (update(dimensions)..where((t) => t.id.equals(dimensionId))).write(
      DimensionsCompanion(levelsJson: Value(encodeLevelsJson(levels))),
    );
  }

  /// Deletes the dimension with the given [id]. Returns the number of rows
  /// deleted (1 on success, 0 if the row did not exist).
  Future<int> deleteDimension(int id) =>
      (delete(dimensions)..where((t) => t.id.equals(id))).go();
}
