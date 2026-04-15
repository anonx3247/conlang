import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'scratchpad_dao.g.dart';

@DriftAccessor(tables: [ScratchpadPhrases])
class ScratchpadDao extends DatabaseAccessor<AppDatabase>
    with _$ScratchpadDaoMixin {
  ScratchpadDao(super.db);

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  /// Watches all phrases ordered newest-first.
  Stream<List<ScratchpadPhrase>> watchAllPhrases() {
    return (select(scratchpadPhrases)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Reads a single phrase by id.
  Future<ScratchpadPhrase?> getPhraseById(int id) {
    return (select(scratchpadPhrases)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Creates a new phrase with empty text and returns the auto-generated id.
  Future<int> createPhrase() {
    final now = DateTime.now();
    return into(scratchpadPhrases).insert(ScratchpadPhrasesCompanion.insert(
      originalText: const Value(''),
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Updates the original text of an existing phrase.
  Future<void> updateOriginalText(int id, String text) {
    return (update(scratchpadPhrases)..where((t) => t.id.equals(id))).write(
      ScratchpadPhrasesCompanion(
        originalText: Value(text),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Updates the free translation of an existing phrase.
  Future<void> updateFreeTranslation(int id, String? translation) {
    return (update(scratchpadPhrases)..where((t) => t.id.equals(id))).write(
      ScratchpadPhrasesCompanion(
        freeTranslation: Value(translation),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a phrase by id.
  Future<void> deletePhrase(int id) {
    return (delete(scratchpadPhrases)..where((t) => t.id.equals(id))).go();
  }
}
