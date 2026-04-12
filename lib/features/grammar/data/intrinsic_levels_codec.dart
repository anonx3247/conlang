import 'dart:convert';

/// D-83 — 04-17. Codec for the [Lexemes.intrinsicLevelsJson] column.
///
/// Shape: `{"<dimensionId>": <levelId>, ...}` — string keys (the JSON
/// type system requires strings), int values.
///
/// Null/empty input decodes to an empty map; encoding an empty map yields
/// null (the canonical "no intrinsic levels" representation in the column).
class IntrinsicLevelsCodec {
  const IntrinsicLevelsCodec();

  /// Decode a stored JSON string into a `{dimId: levelId}` map.
  /// Defensive: malformed/null input returns an empty const map.
  static Map<int, int> decode(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final raw = jsonDecode(json);
      if (raw is! Map) return const {};
      return raw.map((k, v) => MapEntry(int.parse(k as String), v as int));
    } catch (_) {
      return const {};
    }
  }

  /// Encode a `{dimId: levelId}` map into a JSON string. Empty maps return
  /// null so the column stores NULL (the canonical absence sentinel).
  static String? encode(Map<int, int> levels) {
    if (levels.isEmpty) return null;
    return jsonEncode(levels.map((k, v) => MapEntry(k.toString(), v)));
  }

  /// Merges [additions] into the decoded form of [existing], returning the
  /// re-encoded JSON. Used by the D-84 backfill — preserves entries for
  /// other dimensions and overwrites only the keys present in [additions].
  static String? merge(String? existing, Map<int, int> additions) {
    final merged = Map<int, int>.from(decode(existing))..addAll(additions);
    return encode(merged);
  }
}
