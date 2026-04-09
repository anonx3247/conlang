import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
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
