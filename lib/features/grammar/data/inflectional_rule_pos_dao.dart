import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'inflectional_rule_pos_dao.g.dart';

/// Drift DAO for the `inflectional_rule_pos` junction table (Phase 4 gap D-55).
///
/// A single inflectional morphological rule can apply to multiple parts of
/// speech. This junction is the authoritative store of "which POS does this
/// inflectional rule apply to" in v9+; the legacy
/// [MorphologicalRules.inputPosId] column is no longer consulted for lookup
/// (it is kept as a convenience cache only).
///
/// See plan `.planning/phases/04-grammar-morphology-revised/04-11-PLAN.md`.
@DriftAccessor(tables: [InflectionalRulePOS])
class InflectionalRulePOSDao extends DatabaseAccessor<AppDatabase>
    with _$InflectionalRulePOSDaoMixin {
  InflectionalRulePOSDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive queries
  // ---------------------------------------------------------------------------

  /// Watches the POS set for a single [ruleId]. Emits an empty set when no
  /// junction rows exist for the rule.
  Stream<Set<int>> watchPosSetForRule(int ruleId) {
    return (select(inflectionalRulePOS)..where((t) => t.ruleId.equals(ruleId)))
        .watch()
        .map((rows) => rows.map((r) => r.posId).toSet());
  }

  /// Watches a map of every rule id -> its POS set. Used by `rules_page`
  /// grouping (D-56) to render inflectional rules grouped by their POS set
  /// without spawning one stream per rule.
  Stream<Map<int, Set<int>>> watchAllPosSetsByRuleId() {
    return select(inflectionalRulePOS).watch().map((rows) {
      final map = <int, Set<int>>{};
      for (final row in rows) {
        map.putIfAbsent(row.ruleId, () => <int>{}).add(row.posId);
      }
      return map;
    });
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Atomically replaces the POS set for [ruleId] with [posIds]. Existing
  /// junction rows for the rule are deleted first, then one row is inserted
  /// per pos id in [posIds]. An empty set clears all rows without inserting
  /// any.
  ///
  /// Wraps delete + inserts in a single transaction so listeners never see
  /// an intermediate "empty" state.
  Future<void> replaceForRule({
    required int ruleId,
    required Set<int> posIds,
  }) async {
    await transaction(() async {
      await (delete(inflectionalRulePOS)
            ..where((t) => t.ruleId.equals(ruleId)))
          .go();
      for (final posId in posIds) {
        await into(inflectionalRulePOS).insert(
          InflectionalRulePOSCompanion.insert(
            ruleId: ruleId,
            posId: posId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Deletes every junction row for [ruleId]. Normally unnecessary — the FK
  /// `ON DELETE CASCADE` on [MorphologicalRules] removes junction rows
  /// automatically when the parent rule is deleted. Kept for explicit cleanup
  /// scenarios (e.g. "detach all POS from this rule without deleting it").
  Future<int> deleteAllForRule(int ruleId) {
    return (delete(inflectionalRulePOS)
          ..where((t) => t.ruleId.equals(ruleId)))
        .go();
  }
}
