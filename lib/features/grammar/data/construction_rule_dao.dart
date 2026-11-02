import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'construction_rule_dao.g.dart';

/// DAO for [ConstructionRules] and [ConstructionRulePOS] CRUD + reactive
/// streams.
///
/// Phase 10.1 — provides full CRUD for construction rules and manages the
/// POS junction table that restricts which parts of speech each rule applies
/// to. Mirrors the [InflectionalRulePOSDao] pattern for POS junction
/// management.
///
/// NOTE: hand-written DAO (no codegen @riverpod) — per STATE 01-05 / Pitfall 6,
/// riverpod_generator cannot resolve Drift part-file types at codegen time.
@DriftAccessor(
  tables: [
    ConstructionRules,
    ConstructionRulePOS,
    PhraseConstructions,
    ConstructionSlots,
  ],
)
class ConstructionRuleDao extends DatabaseAccessor<AppDatabase>
    with _$ConstructionRuleDaoMixin {
  ConstructionRuleDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch streams
  // ---------------------------------------------------------------------------

  /// Watches all construction rules ordered by [ordering].
  ///
  /// Emits a new list whenever any row in [ConstructionRules] changes.
  Stream<List<ConstructionRuleRow>> watchAll() =>
      (select(constructionRules)
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  /// Watches all construction rules that apply to [posId], ordered by
  /// [ordering].
  ///
  /// Joins [ConstructionRules] with [ConstructionRulePOS] to filter by POS.
  /// Emits a new list whenever any relevant row changes.
  Stream<List<ConstructionRuleRow>> watchForPos(int posId) {
    final query = select(constructionRules).join([
      innerJoin(
        constructionRulePOS,
        constructionRulePOS.ruleId.equalsExp(constructionRules.id),
      ),
    ])
      ..where(constructionRulePOS.posId.equals(posId))
      ..orderBy([OrderingTerm.asc(constructionRules.ordering)]);

    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(constructionRules)).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new construction rule row. Returns the new row's id.
  Future<int> insertRule(ConstructionRulesCompanion c) =>
      into(constructionRules).insert(c);

  /// Replaces an existing construction rule row. Returns true if a row was
  /// updated.
  Future<bool> updateRule(ConstructionRuleRow r) =>
      update(constructionRules).replace(r);

  /// Deletes the construction rule with [id]. Returns the number of rows
  /// deleted (0 or 1). CASCADE on [ConstructionRulePOS] handles junction
  /// cleanup automatically.
  Future<int> deleteRule(int id) =>
      (delete(constructionRules)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // POS junction management
  // ---------------------------------------------------------------------------

  /// Inserts a single POS link for [ruleId] → [posId].
  ///
  /// Uses [InsertMode.insertOrIgnore] to be idempotent — inserting a link
  /// that already exists is a no-op.
  Future<void> insertPosLink(int ruleId, int posId) =>
      into(constructionRulePOS).insert(
        ConstructionRulePOSRow(ruleId: ruleId, posId: posId),
        mode: InsertMode.insertOrIgnore,
      );

  /// Deletes all POS links for [ruleId].
  Future<void> deletePosLinks(int ruleId) =>
      (delete(constructionRulePOS)
            ..where((t) => t.ruleId.equals(ruleId)))
          .go();

  /// Returns all POS ids linked to [ruleId].
  Future<List<int>> getPosIdsForRule(int ruleId) async {
    final rows = await (select(constructionRulePOS)
          ..where((t) => t.ruleId.equals(ruleId)))
        .get();
    return rows.map((r) => r.posId).toList();
  }

  /// Atomically replaces all POS links for [ruleId] with [posIds].
  ///
  /// Deletes all existing links then inserts one row per entry in [posIds].
  /// Performed in a single [transaction] for atomicity — mirrors the
  /// [InflectionalRulePOSDao.setPosLinks] pattern.
  Future<void> setPosLinks(int ruleId, Set<int> posIds) async {
    await transaction(() async {
      await deletePosLinks(ruleId);
      for (final posId in posIds) {
        await insertPosLink(ruleId, posId);
      }
    });
  }
}
