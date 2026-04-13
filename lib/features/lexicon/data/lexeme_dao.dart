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

  // ---------------------------------------------------------------------------
  // Promoted derivation path (plan 04-12 — D-57, D-58)
  // ---------------------------------------------------------------------------

  /// D-57: promote a computed derivation to a full Lexeme row.
  ///
  /// Creates a new [Lexeme] row with:
  ///   - `meaning = gloss`
  ///   - `derivedFromLexemeId = parentId`
  ///   - `derivedViaRuleId = ruleId`
  ///   - `partOfSpeech = rule.outputPos.name` (resolved via the rule row)
  ///   - `romanization = null` — promoted rows' display form is computed
  ///     at render time via `promotedDerivedFormProvider` by applying the
  ///     rule to the parent's ipa. D-58's "computed by default, stored
  ///     if edited" model.
  ///   - `ipa = parent.ipa` — placeholder only; it is ignored by the
  ///     promoted-form provider, which re-applies the rule. We cannot
  ///     leave `ipa` null because the column is non-nullable.
  ///
  /// Returns the new lexeme id.
  Future<int> promoteDerivation({
    required int parentId,
    required int ruleId,
    required String gloss,
  }) async {
    // Resolve the rule's output POS to a free-text label for the new row.
    final rule = await (select(morphologicalRules)
          ..where((t) => t.id.equals(ruleId)))
        .getSingleOrNull();
    if (rule == null) {
      throw StateError(
          '[LexemeDao.promoteDerivation] expected exactly one rule for id=$ruleId, found none');
    }
    String? posText;
    if (rule.outputPosId != null) {
      final pos = await (select(partsOfSpeech)
            ..where((t) => t.id.equals(rule.outputPosId!)))
          .getSingleOrNull();
      posText = pos?.name;
    }

    // Resolve the parent to seed the non-nullable `ipa` placeholder.
    final parent = await (select(lexemes)
          ..where((t) => t.id.equals(parentId)))
        .getSingleOrNull();
    if (parent == null) {
      throw StateError(
          '[LexemeDao.promoteDerivation] expected exactly one lexeme for id=$parentId, found none');
    }

    return into(lexemes).insert(
      LexemesCompanion.insert(
        ipa: parent.ipa,
        meaning: Value(gloss),
        partOfSpeech: Value(posText),
        derivedFromLexemeId: Value(parentId),
        derivedViaRuleId: Value(ruleId),
        // `romanization` defaults to null — the promoted-form provider
        // computes it at render time from the rule + parent.
      ),
    );
  }

  /// D-57: remove a promoted derivation (revert to computed-only via
  /// `computedDerivedFormsProvider`).
  ///
  /// Returns `true` if a rule-linked row was deleted, `false` if the
  /// lexeme was not promoted (either does not exist or has
  /// `derivedViaRuleId = null` already). The non-delete branch is a
  /// silent no-op by design — callers may demote unconditionally.
  Future<bool> demoteDerivation({required int lexemeId}) async {
    final row = await (select(lexemes)
          ..where((t) => t.id.equals(lexemeId)))
        .getSingleOrNull();
    if (row == null) return false;
    if (row.derivedViaRuleId == null) return false;
    await (delete(lexemes)..where((t) => t.id.equals(lexemeId))).go();
    return true;
  }

  /// D-58: implicit detach gesture — editing rom or ipa on a promoted
  /// derived Lexeme writes the new values AND nulls `derivedViaRuleId`.
  ///
  /// The row becomes standalone (no longer reactively recomputed from
  /// the rule), but `derivedFromLexemeId` (the parent link) is
  /// PRESERVED — only the rule link is severed.
  ///
  /// This is the inverse of the 100-lexeme rule-edit constraint: when
  /// the user explicitly edits the form, reactive updates from rule
  /// changes STOP for this row (because `derivedViaRuleId` is null), so
  /// the hand-written form is stable.
  Future<void> detachFromRule({
    required int lexemeId,
    required String newIpa,
    String? newRom,
  }) {
    return (update(lexemes)..where((t) => t.id.equals(lexemeId))).write(
      LexemesCompanion(
        ipa: Value(newIpa),
        romanization: Value(newRom),
        derivedViaRuleId: const Value(null),
        // derivedFromLexemeId is not touched — parent link stays.
      ),
    );
  }
}
