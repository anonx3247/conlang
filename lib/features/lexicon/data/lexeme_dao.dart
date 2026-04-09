import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'lexeme_dao.g.dart';

/// Drift DAO for CRUD operations on [Lexemes] and [MorphologicalRuleExceptions]
/// tables as they pertain to lexicon management.
///
/// Obtain via `db.lexemeDao` or the Riverpod [lexemeDaoProvider].
@DriftAccessor(tables: [Lexemes, MorphologicalRuleExceptions])
class LexemeDao extends DatabaseAccessor<AppDatabase> with _$LexemeDaoMixin {
  LexemeDao(super.db);

  // ---------------------------------------------------------------------------
  // Roots — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all root lexemes (where [rootId] IS NULL), ordered by [ipa] ASC.
  Stream<List<Lexeme>> watchRoots() =>
      (select(lexemes)
            ..where((t) => t.rootId.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.ipa)]))
          .watch();

  /// Watches all lexemes (roots + derived) — used for derived-word search.
  Stream<List<Lexeme>> watchAllLexemes() => select(lexemes).watch();

  // ---------------------------------------------------------------------------
  // Derived forms — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all derived forms (lexemes whose [rootId] equals the given value).
  Stream<List<Lexeme>> watchDerivedForms(String rootId) =>
      (select(lexemes)..where((t) => t.rootId.equals(rootId))).watch();

  // ---------------------------------------------------------------------------
  // Lexemes — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new lexeme and returns its auto-incremented row ID.
  Future<int> insertLexeme(LexemesCompanion c) => into(lexemes).insert(c);

  /// Replaces all fields of an existing lexeme row.
  Future<bool> updateLexeme(Lexeme l) => update(lexemes).replace(l);

  /// Deletes the lexeme with the given [id].
  Future<int> deleteLexeme(int id) =>
      (delete(lexemes)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Exceptions — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches morphological rule exceptions for a specific [lexemeId].
  Stream<List<MorphologicalRuleException>> watchExceptionsForLexeme(
          int lexemeId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.lexemeId.equals(lexemeId)))
          .watch();

  // ---------------------------------------------------------------------------
  // Exceptions — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a morphological rule exception and returns its row ID.
  Future<int> insertException(MorphologicalRuleExceptionsCompanion c) =>
      into(morphologicalRuleExceptions).insert(c);

  /// Deletes the morphological rule exception with the given [id].
  Future<int> deleteException(int id) =>
      (delete(morphologicalRuleExceptions)..where((t) => t.id.equals(id))).go();
}
