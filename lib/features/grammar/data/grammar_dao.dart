import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/dimension_level.dart';
import '../domain/level_deletion_report.dart';
import 'intrinsic_levels_codec.dart';

part 'grammar_dao.g.dart';

/// Drift DAO for the Phase 4 `Dimensions` table.
///
/// This is a THIN grammar-side DAO separate from `MorphologyDao`. Per D-41,
/// rule CRUD still lives in `MorphologyDao`. This DAO only owns the
/// Dimensions table because that table is Grammar-scoped.
///
/// Obtain via `currentDatabase.grammarDao` or the Riverpod
/// `grammarDaoProvider` which derives it from the active project database.
@DriftAccessor(tables: [
  Dimensions,
  Lexemes,
  MorphologicalRules,
  StandardFormPatterns,
])
class GrammarDao extends DatabaseAccessor<AppDatabase> with _$GrammarDaoMixin {
  GrammarDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Watches all dimensions for a POS, ordered by `ordering` ascending.
  Stream<List<Dimension>> watchDimensionsForPos(int posId) {
    return (select(dimensions)
          ..where((t) => t.posId.equals(posId))
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .watch();
  }

  /// Returns the next `ordering` value to use when inserting a new dimension
  /// on [posId] (max(ordering) + 1, or 0 if none exist).
  Future<int> nextDimensionOrdering(int posId) async {
    final existing = await (select(dimensions)
          ..where((t) => t.posId.equals(posId)))
        .get();
    if (existing.isEmpty) return 0;
    return existing.map((d) => d.ordering).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Returns the next level id for a dimension — `max(level.id) + 1` across
  /// the dimension's existing `levelsJson`, or `1` if the list is empty.
  ///
  /// Uses the [decodeLevelsJson] helper so malformed JSON is treated as an
  /// empty list (returns 1).
  Future<int> nextLevelId(int dimensionId) async {
    final row = await (select(dimensions)
          ..where((t) => t.id.equals(dimensionId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
          '[GrammarDao.nextLevelId] expected exactly one row for id=$dimensionId, found none');
    }
    final levels = decodeLevelsJson(row.levelsJson);
    if (levels.isEmpty) return 1;
    return levels.map((l) => l.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new dimension and returns its generated row id.
  Future<int> insertDimension(DimensionsCompanion c) =>
      into(dimensions).insert(c);

  /// Replaces all fields of an existing dimension row.
  Future<bool> updateDimension(Dimension d) => update(dimensions).replace(d);

  /// Convenience: encodes [levels] and writes them to the dimension's
  /// `levels_json` column. Returns the number of rows affected (1 on success).
  Future<int> updateDimensionLevels(
    int dimensionId,
    List<DimensionLevel> levels,
  ) {
    return (update(dimensions)..where((t) => t.id.equals(dimensionId))).write(
      DimensionsCompanion(levelsJson: Value(encodeLevelsJson(levels))),
    );
  }

  /// Deletes the dimension with the given [id]. Returns the number of rows
  /// deleted (1 on success, 0 if the row did not exist).
  Future<int> deleteDimension(int id) =>
      (delete(dimensions)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // D-82 / D-84 / D-85 — 04-17 intrinsic dimension toggle + backfill + purge
  // ---------------------------------------------------------------------------

  /// Returns the lexemes whose [Lexemes.partOfSpeech] matches [posId]'s
  /// name or abbreviation (case-insensitive), per `posForLexeme` semantics.
  Future<List<Lexeme>> _lexemesForPos(int posId) async {
    final posRow = await (select(db.partsOfSpeech)
          ..where((t) => t.id.equals(posId)))
        .getSingleOrNull();
    if (posRow == null) return const [];
    final all = await select(lexemes).get();
    final nameLower = posRow.name.toLowerCase();
    final abbrLower = posRow.abbreviation.toLowerCase();
    return all.where((lex) {
      final raw = lex.partOfSpeech;
      if (raw == null) return false;
      final needle = raw.toLowerCase().trim();
      if (needle.isEmpty) return false;
      return needle == nameLower || needle == abbrLower;
    }).toList();
  }

  /// D-84 — 04-17. Toggles the [Dimensions.intrinsic] flag for [dimId].
  ///
  /// On false→true: reads every lexeme whose POS matches the dim's POS,
  /// merges `{dimId: firstLevelId}` into each lexeme's
  /// [Lexemes.intrinsicLevelsJson] via [IntrinsicLevelsCodec.merge]
  /// (preserving existing entries for other dims), and returns the
  /// number of lexemes affected. Also writes a
  /// `intrinsic_backfill_pending_<dimId>` row to project_settings so
  /// the D-84 banner can surface the "Review N words with auto-assigned
  /// default level" affordance.
  ///
  /// On true→false: flips the flag only; lexeme rows are left untouched
  /// (D-85 explicit purge is the separate affordance).
  ///
  /// Returns the affected lexeme count (0 on true→false).
  Future<int> setDimensionIntrinsic(int dimId, bool intrinsic) async {
    final dim = await (select(dimensions)..where((t) => t.id.equals(dimId)))
        .getSingleOrNull();
    if (dim == null) return 0;

    // Always write the flag.
    await (update(dimensions)..where((t) => t.id.equals(dimId))).write(
      DimensionsCompanion(intrinsic: Value(intrinsic)),
    );

    if (!intrinsic) return 0; // true→false never touches lexemes.
    if (dim.intrinsic == true) return 0; // no-op: already intrinsic.

    final levels = decodeLevelsJson(dim.levelsJson);
    if (levels.isEmpty) return 0;
    final firstLevelId = levels.first.id;

    final affectedLexemes = await _lexemesForPos(dim.posId);
    var count = 0;
    for (final lex in affectedLexemes) {
      final merged =
          IntrinsicLevelsCodec.merge(lex.intrinsicLevelsJson, {dimId: firstLevelId});
      await (update(lexemes)..where((t) => t.id.equals(lex.id))).write(
        LexemesCompanion(intrinsicLevelsJson: Value(merged)),
      );
      count++;
    }

    // Write the banner pending row. Schema: project_settings is a K/V
    // TextColumn table with a unique constraint on `key`. Delete any
    // existing row then insert fresh to avoid upsert-by-unique-column
    // complications with the autoIncrement primary key.
    final bannerKey = 'intrinsic_backfill_pending_$dimId';
    final bannerValue = jsonEncode({
      'count': count,
      'dimName': dim.name,
      'dimId': dimId,
    });
    await (delete(db.projectSettings)..where((t) => t.key.equals(bannerKey)))
        .go();
    await into(db.projectSettings).insert(
      ProjectSettingsCompanion.insert(
        key: bannerKey,
        value: bannerValue,
      ),
    );
    return count;
  }

  /// D-85 — 04-17. Removes every entry for [dimId] from every lexeme's
  /// [Lexemes.intrinsicLevelsJson]. Used when toggling a dim back to
  /// non-intrinsic and the user explicitly opts to clean up stale state.
  /// Returns the number of lexeme rows updated.
  Future<int> purgeIntrinsicLevelEntries(int dimId) async {
    final dim = await (select(dimensions)..where((t) => t.id.equals(dimId)))
        .getSingleOrNull();
    if (dim == null) return 0;
    final affected = await _lexemesForPos(dim.posId);
    var count = 0;
    for (final lex in affected) {
      final decoded = IntrinsicLevelsCodec.decode(lex.intrinsicLevelsJson);
      if (!decoded.containsKey(dimId)) continue;
      final updated = Map<int, int>.from(decoded)..remove(dimId);
      await (update(lexemes)..where((t) => t.id.equals(lex.id))).write(
        LexemesCompanion(
          intrinsicLevelsJson: Value(IntrinsicLevelsCodec.encode(updated)),
        ),
      );
      count++;
    }
    return count;
  }

  /// D-85 — 04-17. Counts how many lexeme rows still carry an entry for
  /// [dimId] in their [Lexemes.intrinsicLevelsJson]. Used by the purge
  /// affordance's visibility check without mutating anything.
  Future<int> countStaleIntrinsicEntries(int dimId) async {
    final dim = await (select(dimensions)..where((t) => t.id.equals(dimId)))
        .getSingleOrNull();
    if (dim == null) return 0;
    final affected = await _lexemesForPos(dim.posId);
    var count = 0;
    for (final lex in affected) {
      final decoded = IntrinsicLevelsCodec.decode(lex.intrinsicLevelsJson);
      if (decoded.containsKey(dimId)) count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // D-86 — 04-17 unified level-deletion dependency check + reassign
  // ---------------------------------------------------------------------------

  /// D-86 — 04-17. Counts references to the `(dimId, levelId)` pair across
  /// (a) [Lexemes.intrinsicLevelsJson], (b) [StandardFormPatterns], and
  /// (c) [MorphologicalRules.featureBindings]. Returns a structured
  /// [LevelDeletionReport] consumed by the reassign dialog in
  /// `dimension_editor_panel.dart`.
  Future<LevelDeletionReport> checkLevelDeletionDependencies(
    int dimId,
    int levelId,
  ) async {
    // (a) Lexemes whose intrinsicLevelsJson[dimId] == levelId.
    final allLexemes = await select(lexemes).get();
    final lexemeIds = <int>[];
    for (final lex in allLexemes) {
      final decoded = IntrinsicLevelsCodec.decode(lex.intrinsicLevelsJson);
      if (decoded[dimId] == levelId) lexemeIds.add(lex.id);
    }

    // (b) StandardFormPatterns rows with matching composite key.
    final patternRows = await (select(standardFormPatterns)
          ..where((p) =>
              p.dimensionId.equals(dimId) & p.levelId.equals(levelId)))
        .get();
    final patternCount = patternRows.length;

    // (c) MorphologicalRules whose featureBindings.dims has [dimId] == levelId.
    // featureBindings is stored via FeatureBindingsConverter, so the Drift row
    // decodes it for us into a typed FeatureBindings object.
    final ruleRows = await select(morphologicalRules).get();
    final ruleNames = <String>[];
    for (final row in ruleRows) {
      final bindings = row.featureBindings;
      if (bindings.dims[dimId] == levelId) {
        ruleNames.add(row.name);
      }
    }

    return LevelDeletionReport(
      lexemeCount: lexemeIds.length,
      patternCount: patternCount,
      ruleCount: ruleNames.length,
      ruleNames: ruleNames,
      lexemeIds: lexemeIds,
    );
  }

  /// D-86 — 04-17. Atomically reassigns every reference from
  /// `(dimId, oldLevelId)` to `(dimId, newLevelId)` across lexemes,
  /// standard-form patterns, and rules, THEN removes `oldLevelId`
  /// from the dimension's levelsJson. All writes happen in a single
  /// transaction so a failure mid-way leaves no partial state.
  Future<void> reassignLevelAndDelete(
    int dimId,
    int oldLevelId,
    int newLevelId,
  ) async {
    await transaction(() async {
      // Update lexemes.
      final allLexemes = await select(lexemes).get();
      for (final lex in allLexemes) {
        final decoded = IntrinsicLevelsCodec.decode(lex.intrinsicLevelsJson);
        if (decoded[dimId] != oldLevelId) continue;
        final updated = Map<int, int>.from(decoded)..[dimId] = newLevelId;
        await (update(lexemes)..where((t) => t.id.equals(lex.id))).write(
          LexemesCompanion(
            intrinsicLevelsJson: Value(IntrinsicLevelsCodec.encode(updated)),
          ),
        );
      }

      // Update standard_form_patterns rows: levelId swap under same dim.
      await customStatement(
        'UPDATE standard_form_patterns '
        'SET level_id = ? WHERE dimension_id = ? AND level_id = ?',
        [newLevelId, dimId, oldLevelId],
      );

      // Update rules whose featureBindings dims map has oldLevelId for dimId.
      final ruleRows = await select(morphologicalRules).get();
      for (final row in ruleRows) {
        final bindings = row.featureBindings;
        if (bindings.dims[dimId] != oldLevelId) continue;
        final newDims = Map<int, int>.from(bindings.dims)..[dimId] = newLevelId;
        final newBindings =
            bindings.copyWith(dims: newDims);
        await (update(morphologicalRules)
              ..where((t) => t.id.equals(row.id)))
            .write(MorphologicalRulesCompanion(
          featureBindings: Value(newBindings),
        ));
      }

      // Finally remove the old level from the dimension's levelsJson.
      final dim = await (select(dimensions)..where((t) => t.id.equals(dimId)))
          .getSingleOrNull();
      if (dim == null) {
        throw StateError(
            '[GrammarDao.reassignLevelAndDelete] expected exactly one row for id=$dimId, found none');
      }
      final remaining = decodeLevelsJson(dim.levelsJson)
          .where((l) => l.id != oldLevelId)
          .toList();
      await (update(dimensions)..where((t) => t.id.equals(dimId))).write(
        DimensionsCompanion(levelsJson: Value(encodeLevelsJson(remaining))),
      );
    });
  }
}
