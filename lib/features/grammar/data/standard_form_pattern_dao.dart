import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/standard_form_branch.dart';

part 'standard_form_pattern_dao.g.dart';

/// D-97 / D-97-dao — 04-17. CRUD over [StandardFormPatterns].
///
/// Stores per-(intrinsic-dim, level) pattern branch lists. Branches are
/// JSON-encoded as a list of `{kind, literal}` objects via
/// [StandardFormBranch.toJson] / [StandardFormBranch.fromJson].
///
/// Cascade delete on Dimensions removal is handled by the foreign key.
@DriftAccessor(tables: [StandardFormPatterns])
class StandardFormPatternDao extends DatabaseAccessor<AppDatabase>
    with _$StandardFormPatternDaoMixin {
  StandardFormPatternDao(super.db);

  /// Returns the list of branches for the (dimId, levelId) pair, or null
  /// if no row exists. An empty list means the row exists but has no
  /// branches (trivially-matching constraint).
  Future<List<StandardFormBranch>?> getPattern(int dimId, int levelId) async {
    final row = await (select(standardFormPatterns)
          ..where((p) =>
              p.dimensionId.equals(dimId) & p.levelId.equals(levelId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decodeBranches(row.branchesJson);
  }

  /// Inserts or replaces the pattern row for (dimId, levelId).
  Future<void> upsertPattern(
    int dimId,
    int levelId,
    List<StandardFormBranch> branches,
  ) async {
    final json = jsonEncode(branches.map((b) => b.toJson()).toList());
    await into(standardFormPatterns).insertOnConflictUpdate(
      StandardFormPatternsCompanion(
        dimensionId: Value(dimId),
        levelId: Value(levelId),
        branchesJson: Value(json),
      ),
    );
  }

  /// Deletes the pattern row for (dimId, levelId), if any.
  Future<void> deletePattern(int dimId, int levelId) async {
    await (delete(standardFormPatterns)
          ..where((p) =>
              p.dimensionId.equals(dimId) & p.levelId.equals(levelId)))
        .go();
  }

  /// Streams every pattern row for [dimId] keyed by levelId.
  Stream<Map<int, List<StandardFormBranch>>> watchAllPatternsForDim(int dimId) {
    return (select(standardFormPatterns)
          ..where((p) => p.dimensionId.equals(dimId)))
        .watch()
        .map((rows) => {
              for (final r in rows) r.levelId: _decodeBranches(r.branchesJson),
            });
  }

  static List<StandardFormBranch> _decodeBranches(String json) {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    return raw
        .map((e) => StandardFormBranch.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
