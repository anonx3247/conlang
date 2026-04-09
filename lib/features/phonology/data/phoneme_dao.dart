import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'phoneme_dao.g.dart';

/// Drift DAO for CRUD operations on the [Phonemes] table.
///
/// Obtain an instance via `currentDatabase.phonemeDao` or the Riverpod
/// [phonemeDaoProvider] which derives it from the active project database.
@DriftAccessor(tables: [Phonemes, NaturalClasses])
class PhonemeDao extends DatabaseAccessor<AppDatabase>
    with _$PhonemeDaoMixin {
  PhonemeDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Watches all phonemes in the project, ordered by type then symbol.
  Stream<List<Phoneme>> watchAllPhonemes() =>
      (select(phonemes)..orderBy([(t) => OrderingTerm.asc(t.symbol)])).watch();

  /// Watches only consonant phonemes.
  Stream<List<Phoneme>> watchConsonants() => (select(phonemes)
        ..where((t) => t.type.equals('consonant'))
        ..orderBy([(t) => OrderingTerm.asc(t.symbol)]))
      .watch();

  /// Watches only vowel phonemes.
  Stream<List<Phoneme>> watchVowels() => (select(phonemes)
        ..where((t) => t.type.equals('vowel'))
        ..orderBy([(t) => OrderingTerm.asc(t.symbol)]))
      .watch();

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new phoneme and returns its generated row ID.
  Future<int> insertPhoneme(PhonemesCompanion companion) =>
      into(phonemes).insert(companion);

  /// Updates all fields of an existing phoneme row.
  Future<bool> updatePhoneme(Phoneme phoneme) =>
      update(phonemes).replace(phoneme);

  /// Deletes the phoneme with the given [id] and removes its ID from all
  /// natural classes' phonemeIds JSON arrays.
  Future<int> deletePhoneme(int id) async {
    // Remove from natural classes first (cascading cleanup).
    final allClasses = await select(naturalClasses).get();
    for (final cls in allClasses) {
      try {
        final decoded = jsonDecode(cls.phonemeIds);
        if (decoded is List && decoded.contains(id)) {
          final updated = decoded.where((e) => e != id).toList();
          await (update(naturalClasses)
                ..where((t) => t.id.equals(cls.id)))
              .write(NaturalClassesCompanion(
                  phonemeIds: Value(jsonEncode(updated))));
        }
      } catch (_) {
        // Skip malformed JSON
      }
    }
    return (delete(phonemes)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Returns phonemes whose IDs are in [ids]. Used for natural class resolution.
  Future<List<Phoneme>> getPhonemesByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(phonemes)..where((t) => t.id.isIn(ids))).get();
  }
}
