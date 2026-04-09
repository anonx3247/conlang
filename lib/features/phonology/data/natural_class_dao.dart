import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'natural_class_dao.g.dart';

/// Drift DAO for CRUD operations on the [NaturalClasses] table.
///
/// Natural classes are named sets of phoneme IDs stored as a JSON array.
/// Example: `{"name": "stop", "phonemeIds": "[1,2,3]"}`.
@DriftAccessor(tables: [NaturalClasses])
class NaturalClassDao extends DatabaseAccessor<AppDatabase>
    with _$NaturalClassDaoMixin {
  NaturalClassDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Watches all natural classes ordered by name.
  Stream<List<NaturalClassesData>> watchAllClasses() =>
      (select(naturalClasses)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new natural class and returns its generated row ID.
  Future<int> insertClass(NaturalClassesCompanion companion) =>
      into(naturalClasses).insert(companion);

  /// Updates all fields of an existing natural class row.
  Future<bool> updateClass(NaturalClassesData naturalClass) =>
      update(naturalClasses).replace(naturalClass);

  /// Deletes the natural class with the given [id].
  Future<int> deleteClass(int id) =>
      (delete(naturalClasses)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------

  /// Looks up a natural class by [name] and decodes its phoneme ID list.
  ///
  /// Returns an empty list if no class with that name exists.
  Future<List<int>> resolveClass(String name) async {
    final row = await (select(naturalClasses)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();

    if (row == null) return [];

    final decoded = jsonDecode(row.phonemeIds);
    if (decoded is List) {
      return decoded.whereType<int>().toList();
    }
    return [];
  }
}
