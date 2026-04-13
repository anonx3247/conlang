import 'dart:convert';

import '../../../db/app_database.dart' show Dimension;
import 'feature_bindings.dart';

/// Translates [original] bindings authored against [authPosDims] into the
/// dimension/level ID space of [queryPosDims] by matching on dimension
/// name and level name/abbr.
///
/// Returns `null` if any binding can't be translated (the query POS lacks a
/// dimension with the matching name, or the target level doesn't exist in
/// the query POS's version of that dimension). In that case the rule should
/// be dropped for [queryPosDims] — it's structurally unreachable.
///
/// If [original]'s dims is empty, returns [original] unchanged (empty-bindings
/// rules never fire anyway — the engine enforces that separately).
///
/// Context: Plan 04-11 shipped multi-POS inflectional rules with a dim-chip
/// UI that renders the intersection of POS dimensions *by name* but stores
/// bindings as `Map<dimId, levelId>` using the first POS's row IDs. The
/// paradigm engine matches bindings by integer equality, so the rule only
/// fired on the authoring POS. This helper is the read-side remap that
/// makes the same rule fire on every attached POS.
FeatureBindings? translateBindingsByName({
  required FeatureBindings original,
  required List<Dimension> authPosDims,
  required List<Dimension> queryPosDims,
}) {
  if (original.dims.isEmpty) return original;

  // Resolve auth-side dim id → (dim name, level id → level name/abbr).
  final authDimById = <int, Dimension>{
    for (final d in authPosDims) d.id: d,
  };

  // Build query-side name → dim and, within it, level name/abbr → level id.
  final queryDimByName = <String, Dimension>{
    for (final d in queryPosDims) d.name: d,
  };

  final translated = <int, int>{};
  for (final entry in original.dims.entries) {
    final authDimId = entry.key;
    final authLevelId = entry.value;

    final authDim = authDimById[authDimId];
    if (authDim == null) return null; // auth dim no longer exists

    final queryDim = queryDimByName[authDim.name];
    if (queryDim == null) return null; // query POS has no dim with that name

    if (queryDim.id == authDimId) {
      // Same dimension row — level ids already align.
      translated[authDimId] = authLevelId;
      continue;
    }

    final authLevel = _findLevel(authDim, authLevelId);
    if (authLevel == null) return null;

    // Match level by name first, fall back to abbr — the template catalog
    // uses both and either is a stable identifier across POS copies.
    final queryLevelId = _findLevelIdByName(queryDim, authLevel)
        ?? _findLevelIdByAbbr(queryDim, authLevel);
    if (queryLevelId == null) return null;

    translated[queryDim.id] = queryLevelId;
  }

  return FeatureBindings(pos: original.pos, dims: translated);
}

/// Locates the [authoringPosId] for a rule: the POS whose dim rows were
/// used when authoring the rule's [FeatureBindings]. Per the editor
/// convention (plan 04-11), this is the smallest POS id in the junction
/// set — matching the sort order in `_save()` at
/// `rule_editor_dialog.dart:479`. Falls back to the legacy `inputPosId`
/// column for pre-04-11 rules that never had a junction attached.
///
/// Returns `null` when neither source is populated.
int? authPosIdForRule({
  required List<int> featureBindingsPos,
  required int? legacyInputPosId,
}) {
  if (featureBindingsPos.isNotEmpty) {
    return featureBindingsPos.reduce((a, b) => a < b ? a : b);
  }
  return legacyInputPosId;
}

_LevelLite? _findLevel(Dimension dim, int levelId) {
  final levels = _decode(dim.levelsJson);
  for (final l in levels) {
    if (l['id'] == levelId) {
      return _LevelLite(
        name: l['name'] as String? ?? '',
        abbr: l['abbr'] as String? ?? '',
      );
    }
  }
  return null;
}

int? _findLevelIdByName(Dimension dim, _LevelLite target) {
  if (target.name.isEmpty) return null;
  for (final l in _decode(dim.levelsJson)) {
    if ((l['name'] as String? ?? '') == target.name) return l['id'] as int?;
  }
  return null;
}

int? _findLevelIdByAbbr(Dimension dim, _LevelLite target) {
  if (target.abbr.isEmpty) return null;
  for (final l in _decode(dim.levelsJson)) {
    if ((l['abbr'] as String? ?? '') == target.abbr) return l['id'] as int?;
  }
  return null;
}

List<Map<String, dynamic>> _decode(String json) {
  if (json.isEmpty) return const [];
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>();
  } catch (_) {
    return const [];
  }
}

class _LevelLite {
  const _LevelLite({required this.name, required this.abbr});
  final String name;
  final String abbr;
}
