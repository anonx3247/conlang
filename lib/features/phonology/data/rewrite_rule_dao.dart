import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'rewrite_rule_dao.g.dart';

/// Drift DAO for CRUD operations on the [RewriteRules] table.
///
/// Obtain via `currentDatabase.rewriteRuleDao` or the Riverpod
/// [rewriteRuleDaoProvider] which derives it from the active project database.
@DriftAccessor(tables: [RewriteRules])
class RewriteRuleDao extends DatabaseAccessor<AppDatabase>
    with _$RewriteRuleDaoMixin {
  RewriteRuleDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all rewrite rules, ordered by [ordering] then [id].
  Stream<List<RewriteRule>> watchAll() =>
      (select(rewriteRules)
            ..orderBy([
              (t) => OrderingTerm.asc(t.ordering),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new rewrite rule and returns its generated row ID.
  Future<int> insertRule(RewriteRulesCompanion companion) =>
      into(rewriteRules).insert(companion);

  /// Updates all fields of an existing rewrite rule row.
  Future<bool> updateRule(RewriteRule rule) =>
      update(rewriteRules).replace(rule);

  /// Deletes the rewrite rule with the given [id].
  Future<int> deleteRule(int id) =>
      (delete(rewriteRules)..where((t) => t.id.equals(id))).go();
}
