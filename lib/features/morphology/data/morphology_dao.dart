import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'morphology_dao.g.dart';

/// Drift DAO for CRUD operations on [MorphologicalRules] and
/// [MorphologicalRuleExceptions] tables.
///
/// Obtain via `currentDatabase.morphologyDao` or the Riverpod
/// [morphologyDaoProvider] which derives it from the active project database.
@DriftAccessor(tables: [MorphologicalRules, MorphologicalRuleExceptions])
class MorphologyDao extends DatabaseAccessor<AppDatabase>
    with _$MorphologyDaoMixin {
  MorphologyDao(super.db);

  // ---------------------------------------------------------------------------
  // Rules — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all morphological rules, ordered by [ordering] ascending.
  Stream<List<MorphologicalRule>> watchAllRules() =>
      (select(morphologicalRules)
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  // ---------------------------------------------------------------------------
  // Rules — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new morphological rule and returns its generated row ID.
  Future<int> insertRule(MorphologicalRulesCompanion c) =>
      into(morphologicalRules).insert(c);

  /// Replaces all fields of an existing morphological rule row.
  Future<bool> updateRule(MorphologicalRule r) =>
      update(morphologicalRules).replace(r);

  /// Deletes the morphological rule with the given [id].
  Future<int> deleteRule(int id) =>
      (delete(morphologicalRules)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Exceptions — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches exceptions associated with a specific [ruleId].
  Stream<List<MorphologicalRuleException>> watchExceptionsForRule(int ruleId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.ruleId.equals(ruleId)))
          .watch();

  /// Watches exceptions associated with a specific [lexemeId].
  Stream<List<MorphologicalRuleException>> watchExceptionsForLexeme(
          int lexemeId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.lexemeId.equals(lexemeId)))
          .watch();

  // ---------------------------------------------------------------------------
  // Exceptions — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new morphological rule exception and returns its generated row ID.
  Future<int> insertException(MorphologicalRuleExceptionsCompanion c) =>
      into(morphologicalRuleExceptions).insert(c);

  /// Deletes the morphological rule exception with the given [id].
  Future<int> deleteException(int id) =>
      (delete(morphologicalRuleExceptions)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Stale exception detection
  // ---------------------------------------------------------------------------

  /// Returns exceptions for [ruleId] whose [ruleSourceSnapshot] no longer
  /// matches [currentSource] — i.e. the rule was edited after the exception
  /// was created and may need review.
  Future<List<MorphologicalRuleException>> findStaleExceptions(
      int ruleId, String currentSource) async {
    final all = await (select(morphologicalRuleExceptions)
          ..where((t) => t.ruleId.equals(ruleId)))
        .get();
    return all
        .where((e) => e.ruleSourceSnapshot != currentSource)
        .toList();
  }
}
