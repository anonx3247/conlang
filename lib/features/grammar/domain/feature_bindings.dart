import 'dart:convert';

import 'package:drift/drift.dart';

/// Parsed feature-binding payload for a morphological rule.
///
/// Schema (JSON, stored in MorphologicalRules.feature_bindings TEXT column):
/// ```
/// {"pos": [1, 3], "5": 2, "7": 4}
/// ```
/// - Top-level reserved key `"pos"` holds the list of POS ids the rule applies to.
///   Empty list or missing key = applies to all POS.
/// - Top-level reserved key `"outputIntrinsic"` holds a map of stringified
///   dimension ids -> level ids for the intrinsic levels of the output POS in
///   a derivational rule (e.g. `{"outputIntrinsic": {"3": 1}}`). Missing key
///   defaults to empty map (backward-compatible with pre-04-20-01 rows).
/// - All other top-level keys are stringified dimension ids mapping to the
///   level id (unique within that dimension row) the rule binds to.
///
/// D-09 / D-10 — per CONTEXT.md
class FeatureBindings {
  const FeatureBindings({
    required this.pos,
    required this.dims,
    this.outputIntrinsic = const {},
  });

  final List<int> pos;
  final Map<int, int> dims; // dimensionId -> levelId

  /// plan 04-20-01 (UAT New Gap 1): for derivational rules, maps each
  /// intrinsic dimension of the output POS to the selected level. Stored
  /// under the `outputIntrinsic` key in the featureBindings JSON. Defaults
  /// to an empty map (backward-compatible — key absent in old rows).
  final Map<int, int> outputIntrinsic;

  /// Number of grammatical dimensions this rule binds = specificity (D-10 step 3).
  int get specificity => dims.length;

  /// Inflectional iff at least one dimension binding is present (D-13).
  bool get isInflectional => dims.isNotEmpty;

  /// Derivational iff no dimension binding is present.
  bool get isDerivational => dims.isEmpty;

  FeatureBindings copyWith({
    List<int>? pos,
    Map<int, int>? dims,
    Map<int, int>? outputIntrinsic,
  }) =>
      FeatureBindings(
        pos: pos ?? this.pos,
        dims: dims ?? this.dims,
        outputIntrinsic: outputIntrinsic ?? this.outputIntrinsic,
      );

  @override
  bool operator ==(Object other) =>
      other is FeatureBindings &&
      _listEq(other.pos, pos) &&
      _mapEq(other.dims, dims) &&
      _mapEq(other.outputIntrinsic, outputIntrinsic);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(pos),
        Object.hashAllUnordered(
          dims.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(
          outputIntrinsic.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEq(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || b[k] != a[k]) return false;
    }
    return true;
  }
}

/// Drift TypeConverter: `FeatureBindings <-> String (JSON)`.
///
/// Wire via `.map(const FeatureBindingsConverter())` on the column definition.
class FeatureBindingsConverter extends TypeConverter<FeatureBindings, String>
    with JsonTypeConverter2<FeatureBindings, String, Map<String, dynamic>> {
  const FeatureBindingsConverter();

  @override
  FeatureBindings fromSql(String fromDb) {
    if (fromDb.isEmpty) return const FeatureBindings(pos: [], dims: {});
    final decoded = jsonDecode(fromDb);
    if (decoded is! Map) return const FeatureBindings(pos: [], dims: {});
    return fromJson(decoded.cast<String, dynamic>());
  }

  @override
  String toSql(FeatureBindings value) => jsonEncode(toJson(value));

  @override
  FeatureBindings fromJson(Map<String, dynamic> json) {
    final posRaw = json['pos'];
    final pos = <int>[];
    if (posRaw is List) {
      for (final p in posRaw) {
        if (p is int) pos.add(p);
      }
    }
    // plan 04-20-01: parse outputIntrinsic map (backward-compatible — missing
    // key produces an empty map so old rows continue to parse correctly).
    final outputIntrinsic = <int, int>{};
    final oiRaw = json['outputIntrinsic'];
    if (oiRaw is Map) {
      for (final entry in oiRaw.entries) {
        final dimId = int.tryParse(entry.key.toString());
        final levelId = entry.value;
        if (dimId != null && levelId is int) outputIntrinsic[dimId] = levelId;
      }
    }
    final dims = <int, int>{};
    for (final entry in json.entries) {
      if (entry.key == 'pos') continue;
      if (entry.key == 'outputIntrinsic') continue;
      final dimId = int.tryParse(entry.key);
      final levelId = entry.value;
      if (dimId != null && levelId is int) dims[dimId] = levelId;
    }
    return FeatureBindings(pos: pos, dims: dims, outputIntrinsic: outputIntrinsic);
  }

  @override
  Map<String, dynamic> toJson(FeatureBindings value) {
    final out = <String, dynamic>{};
    if (value.pos.isNotEmpty) out['pos'] = value.pos;
    for (final e in value.dims.entries) {
      out[e.key.toString()] = e.value;
    }
    // plan 04-20-01: persist outputIntrinsic for derivational rules.
    if (value.outputIntrinsic.isNotEmpty) {
      out['outputIntrinsic'] = {
        for (final e in value.outputIntrinsic.entries) e.key.toString(): e.value,
      };
    }
    return out;
  }
}
