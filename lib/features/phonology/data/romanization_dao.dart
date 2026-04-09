import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'romanization_dao.g.dart';

/// Drift DAO for CRUD operations on the [RomanizationMappings] table.
///
/// Accessed via [AppDatabase.romanizationDao] (registered in the @DriftDatabase
/// daos list). All methods operate on the current project's database connection.
@DriftAccessor(tables: [RomanizationMappings])
class RomanizationDao extends DatabaseAccessor<AppDatabase>
    with _$RomanizationDaoMixin {
  RomanizationDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive queries
  // ---------------------------------------------------------------------------

  /// Returns a stream of all romanization mappings, updated on every change.
  ///
  /// Consumers watch this to rebuild UI when mappings are added, edited, or
  /// deleted.
  Stream<List<RomanizationMapping>> watchAllMappings() =>
      select(romanizationMappings).watch();

  // ---------------------------------------------------------------------------
  // One-shot queries
  // ---------------------------------------------------------------------------

  /// Fetches all mappings as a single future (non-reactive).
  ///
  /// Used by the romanize conversion function to build the replacement map
  /// on demand.
  Future<List<RomanizationMapping>> getAllMappings() =>
      select(romanizationMappings).get();

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Inserts a new mapping. Returns the new row's auto-generated ID.
  Future<int> insertMapping(RomanizationMappingsCompanion companion) =>
      into(romanizationMappings).insert(companion);

  /// Updates an existing mapping in place.
  ///
  /// Matches by primary key (id). Returns true if the row was updated.
  Future<bool> updateMapping(RomanizationMapping mapping) =>
      update(romanizationMappings).replace(mapping);

  /// Deletes the mapping with the given [id].
  Future<int> deleteMapping(int id) =>
      (delete(romanizationMappings)..where((t) => t.id.equals(id))).go();
}
