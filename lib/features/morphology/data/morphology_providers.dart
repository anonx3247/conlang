import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../grammar/domain/inflectional_rule.dart';
import '../../grammar/domain/rule_kind.dart';
import '../../project/data/project_providers.dart';
import 'morphology_dao.dart';

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// Provides the [MorphologyDao] for the current project database.
///
/// Returns null when no project is open.
///
/// Uses a plain [Provider] (not riverpod_generator) to avoid build_runner
/// type-traversal issues with Drift-generated types.
final morphologyDaoProvider = Provider<MorphologyDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return null;
  return db.morphologyDao;
});

// ---------------------------------------------------------------------------
// Rule providers
// ---------------------------------------------------------------------------

/// Streams all morphological rules for the current project, ordered by
/// [MorphologicalRule.ordering] ascending.
///
/// Emits an empty list when no project is open.
final morphologicalRuleListProvider =
    StreamProvider<List<MorphologicalRule>>((ref) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllRules();
});

// ---------------------------------------------------------------------------
// Parts of Speech providers
// ---------------------------------------------------------------------------

/// Streams all parts of speech for the current project, ordered by name.
///
/// Emits an empty list when no project is open.
final posListProvider = StreamProvider<List<PartsOfSpeechData>>((ref) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllPos();
});

// ---------------------------------------------------------------------------
// Exception providers
// ---------------------------------------------------------------------------

/// Streams exceptions for a specific morphological rule identified by [ruleId].
///
/// Emits an empty list when no project is open.
final morphRuleExceptionsProvider =
    StreamProvider.family<List<MorphologicalRuleException>, int>(
        (ref, ruleId) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchExceptionsForRule(ruleId);
});

// ---------------------------------------------------------------------------
// Kind-aware rule providers (Phase 4)
// ---------------------------------------------------------------------------

/// Streams morphological rules filtered by [RuleKind] (inflectional or
/// derivational). Backed by `MorphologyDao.watchRulesByKind`.
///
/// Emits an empty list when no project is open.
final rulesByKindProvider =
    StreamProvider.family<List<MorphologicalRule>, RuleKind>((ref, kind) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchRulesByKind(kind);
});

/// Streams ACTIVE inflectional rules that apply to the given POS, converted
/// to [InflectionalRule] view-models ready for the paradigm engine.
///
/// Inactive rules are filtered out here — the paradigm engine should never
/// evaluate them.
///
/// Emits an empty list when no project is open.
final inflectionalRulesForPosProvider =
    StreamProvider.family<List<InflectionalRule>, int>((ref, posId) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchInflectionalRulesForPos(posId).map(
        (rows) => rows
            .where((r) => r.isActive)
            .map(InflectionalRule.fromDbRow)
            .toList(),
      );
});
