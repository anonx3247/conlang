import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import '../domain/construction_rule.dart';
import 'construction_rule_dao.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05 / Pitfall 6, riverpod_generator 3.x cannot resolve Drift part-file
// types at codegen time, so grammar-scoped providers that traffic in
// Drift-generated classes must be hand-written.

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// The [ConstructionRuleDao] scoped to the currently-open project database.
///
/// Returns null when no project is open.
final constructionRuleDaoProvider = Provider<ConstructionRuleDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return null;
  return db.constructionRuleDao;
});

// ---------------------------------------------------------------------------
// List providers
// ---------------------------------------------------------------------------

/// Watches all construction rules ordered by [ordering].
///
/// Emits an empty list when no project is open.
final constructionRuleListProvider =
    StreamProvider<List<ConstructionRuleRow>>((ref) {
  final dao = ref.watch(constructionRuleDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAll();
});

// ---------------------------------------------------------------------------
// Per-POS provider
// ---------------------------------------------------------------------------

/// Watches construction rules that apply to [posId], mapped to domain
/// [ConstructionRule] objects.
///
/// Emits an empty list when no project is open.
final constructionRulesForPosProvider =
    StreamProvider.family<List<ConstructionRule>, int>((ref, posId) {
  final dao = ref.watch(constructionRuleDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchForPos(posId).map(
        (rows) => rows.map((r) => ConstructionRule.fromDbRow(r)).toList(),
      );
});
