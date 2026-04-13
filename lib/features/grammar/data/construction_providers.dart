import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import 'construction_dao.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05, riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time, so grammar-scoped providers that traffic in Drift-generated
// classes must be hand-written.

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// The [ConstructionDao] scoped to the currently-open project database.
///
/// Returns null when no project is open.
final constructionDaoProvider = Provider<ConstructionDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return null;
  return db.constructionDao;
});

// ---------------------------------------------------------------------------
// Construction list provider
// ---------------------------------------------------------------------------

/// Watches all phrase constructions ordered by [ordering].
///
/// Emits an empty list when no project is open.
final constructionListProvider =
    StreamProvider<List<PhraseConstruction>>((ref) {
  final dao = ref.watch(constructionDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAll();
});

// ---------------------------------------------------------------------------
// Construction slots provider
// ---------------------------------------------------------------------------

/// Watches all slots for a specific construction, ordered by [ordering].
///
/// Emits an empty list when no project is open.
final constructionSlotsProvider =
    StreamProvider.family<List<ConstructionSlot>, int>((ref, constructionId) {
  final dao = ref.watch(constructionDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchSlotsFor(constructionId);
});
