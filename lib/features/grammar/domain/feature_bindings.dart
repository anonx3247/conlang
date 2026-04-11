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
/// - All other top-level keys are stringified dimension ids mapping to the
///   level id (unique within that dimension row) the rule binds to.
///
/// D-09 / D-10 — per CONTEXT.md
class FeatureBindings {
  const FeatureBindings({required this.pos, required this.dims});

  final List<int> pos;
  final Map<int, int> dims; // dimensionId -> levelId

  /// Number of grammatical dimensions this rule binds = specificity (D-10 step 3).
  int get specificity => dims.length;

  /// Inflectional iff at least one dimension binding is present (D-13).
  bool get isInflectional => dims.isNotEmpty;

  /// Derivational iff no dimension binding is present.
  bool get isDerivational => dims.isEmpty;

  FeatureBindings copyWith({List<int>? pos, Map<int, int>? dims}) =>
      FeatureBindings(pos: pos ?? this.pos, dims: dims ?? this.dims);

  @override
  bool operator ==(Object other) =>
      other is FeatureBindings &&
      _listEq(other.pos, pos) &&
      _mapEq(other.dims, dims);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(pos),
        Object.hashAllUnordered(
          dims.entries.map((e) => Object.hash(e.key, e.value)),
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
    final dims = <int, int>{};
    for (final entry in json.entries) {
      if (entry.key == 'pos') continue;
      final dimId = int.tryParse(entry.key);
      final levelId = entry.value;
      if (dimId != null && levelId is int) dims[dimId] = levelId;
    }
    return FeatureBindings(pos: pos, dims: dims);
  }

  @override
  Map<String, dynamic> toJson(FeatureBindings value) {
    final out = <String, dynamic>{};
    if (value.pos.isNotEmpty) out['pos'] = value.pos;
    for (final e in value.dims.entries) {
      out[e.key.toString()] = e.value;
    }
    return out;
  }
}
