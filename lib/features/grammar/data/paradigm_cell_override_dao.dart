import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'paradigm_cell_override_dao.g.dart';

// ---------------------------------------------------------------------------
// Canonical key helpers
// ---------------------------------------------------------------------------

/// Canonical string key for a feature set: `"dimId:levelId,dimId:levelId,..."`
/// sorted by `dimId` ascending. Used to key the per-lexeme override map.
///
/// Named `featureSetKeyForOverride` instead of `featureSetKey` to avoid an
/// unavoidable collision with the identical helper in
/// `typology_providers.dart` (Plan 04-03) — both sit under
/// `lib/features/grammar/data/` and any file that imports both would get an
/// ambiguous symbol error. The semantics are identical; the helper is
/// defined twice only for import hygiene, and unit tests lock both copies
/// to the same output.
String featureSetKeyForOverride(Map<int, int> featureSet) {
  final entries = featureSet.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}

/// Serialises a feature set to the `feature_set_json` column format. Keys
/// are sorted by dimension id for deterministic storage (so equality checks
/// against the raw SQL string also work), and keys are stringified because
/// JSON object keys must be strings.
String featureSetToJson(Map<int, int> featureSet) {
  final keys = featureSet.keys.toList()..sort();
  final out = <String, int>{
    for (final k in keys) k.toString(): featureSet[k]!,
  };
  return jsonEncode(out);
}

/// Inverse of [featureSetToJson]. Returns an empty map on malformed or
/// empty input (defense in depth against hand-edited DB state).
Map<int, int> featureSetFromJson(String raw) {
  if (raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    final out = <int, int>{};
    for (final e in decoded.entries) {
      final k = int.tryParse(e.key.toString());
      final v = e.value;
      if (k != null && v is int) out[k] = v;
    }
    return out;
  } on FormatException {
    return const {};
  }
}

// ---------------------------------------------------------------------------
// DAO
// ---------------------------------------------------------------------------

/// Drift DAO for per-cell manual overrides in a paradigm table
/// (Phase 4 CONTEXT.md D-22 / D-28 option B).
///
/// Keyed by `(lexemeId, featureSetJson)` — the feature set JSON identifies
/// exactly which paradigm cell is being overridden. Because JSON objects
/// with the same keys in different insertion order produce different raw
/// text, [featureSetToJson] always sorts keys for deterministic equality.
@DriftAccessor(tables: [ParadigmCellOverrides])
class ParadigmCellOverrideDao extends DatabaseAccessor<AppDatabase>
    with _$ParadigmCellOverrideDaoMixin {
  ParadigmCellOverrideDao(super.db);

  /// Watches every override row belonging to [lexemeId] and maps them into
  /// a `Map<String, ParadigmCellOverride>` keyed by the canonical feature
  /// set key. The UI uses this to look up cell overrides by feature set
  /// without iterating rows on every cell rebuild.
  Stream<Map<String, ParadigmCellOverride>> watchOverridesForLexeme(
    int lexemeId,
  ) {
    return (select(paradigmCellOverrides)
          ..where((t) => t.lexemeId.equals(lexemeId)))
        .watch()
        .map((rows) {
      final out = <String, ParadigmCellOverride>{};
      for (final r in rows) {
        final key = featureSetKeyForOverride(
          featureSetFromJson(r.featureSetJson),
        );
        out[key] = r;
      }
      return out;
    });
  }

  /// Upserts an override for (lexemeId, featureSet). Inserts a new row when
  /// none exists, otherwise updates the `override_ipa`, `override_romanization`,
  /// and `notes` columns of the existing row.
  ///
  /// The match predicate uses the canonical JSON string produced by
  /// [featureSetToJson], so inserting the "same feature set in a different
  /// order" does not create a duplicate.
  Future<void> upsertOverride({
    required int lexemeId,
    required Map<int, int> featureSet,
    required String overrideIpa,
    String? overrideRomanization,
    String? notes,
  }) async {
    final json = featureSetToJson(featureSet);
    final existing = await (select(paradigmCellOverrides)
          ..where((t) =>
              t.lexemeId.equals(lexemeId) & t.featureSetJson.equals(json)))
        .getSingleOrNull();
    if (existing == null) {
      await into(paradigmCellOverrides).insert(
        ParadigmCellOverridesCompanion.insert(
          lexemeId: lexemeId,
          featureSetJson: json,
          overrideIpa: overrideIpa,
          overrideRomanization: Value(overrideRomanization),
          notes: Value(notes),
        ),
      );
    } else {
      await (update(paradigmCellOverrides)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        ParadigmCellOverridesCompanion(
          overrideIpa: Value(overrideIpa),
          overrideRomanization: Value(overrideRomanization),
          notes: Value(notes),
        ),
      );
    }
  }

  /// Deletes the override row for (lexemeId, featureSet). Returns the number
  /// of rows removed (0 or 1).
  Future<int> clearOverride({
    required int lexemeId,
    required Map<int, int> featureSet,
  }) {
    final json = featureSetToJson(featureSet);
    return (delete(paradigmCellOverrides)
          ..where((t) =>
              t.lexemeId.equals(lexemeId) & t.featureSetJson.equals(json)))
        .go();
  }
}
