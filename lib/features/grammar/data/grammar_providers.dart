import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import 'dimension_templates.dart';
import 'grammar_dao.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05, riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time, so grammar-scoped providers that traffic in Drift-generated
// classes (`Dimension`, `MorphologicalRule`, etc.) must be hand-written.

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// The [GrammarDao] scoped to the currently-open project database.
///
/// Returns null when no project is open.
final grammarDaoProvider = Provider<GrammarDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.grammarDao;
});

// ---------------------------------------------------------------------------
// Dimensions providers
// ---------------------------------------------------------------------------

/// Watches dimensions for a given POS, reactive to DB changes. Emits an
/// empty list stream when no project is open.
final dimensionsForPosProvider =
    StreamProvider.family<List<Dimension>, int>((ref, posId) {
  final dao = ref.watch(grammarDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchDimensionsForPos(posId);
});

// ---------------------------------------------------------------------------
// Template catalog provider
// ---------------------------------------------------------------------------

/// Constant template catalog — for UI consumption in the "Add Dimension"
/// picker. Stable reference (no DB access), but exposed as a provider for
/// consistency with the other grammar providers.
final dimensionTemplatesProvider = Provider<List<DimensionTemplate>>((ref) {
  return dimensionTemplates;
});
