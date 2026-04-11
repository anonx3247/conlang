import 'dart:convert';

/// A single level within a grammatical dimension (e.g. "Singular" within
/// "Number").
///
/// Levels are stored inline in `Dimensions.levelsJson` as a JSON array of
/// `{id, name, abbr, ordering}` objects. Level [id]s are integers unique
/// within a single dimension row (NOT globally unique) — Phase 4 research
/// recommendation A6.
class DimensionLevel {
  const DimensionLevel({
    required this.id,
    required this.name,
    required this.abbr,
    required this.ordering,
  });

  final int id;
  final String name;
  final String abbr;
  final int ordering;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'abbr': abbr,
        'ordering': ordering,
      };

  factory DimensionLevel.fromJson(Map<String, dynamic> json) => DimensionLevel(
        id: json['id'] as int,
        name: json['name'] as String,
        abbr: json['abbr'] as String,
        ordering: json['ordering'] as int,
      );

  DimensionLevel copyWith({
    int? id,
    String? name,
    String? abbr,
    int? ordering,
  }) =>
      DimensionLevel(
        id: id ?? this.id,
        name: name ?? this.name,
        abbr: abbr ?? this.abbr,
        ordering: ordering ?? this.ordering,
      );

  @override
  bool operator ==(Object other) =>
      other is DimensionLevel &&
      other.id == id &&
      other.name == name &&
      other.abbr == abbr &&
      other.ordering == ordering;

  @override
  int get hashCode => Object.hash(id, name, abbr, ordering);

  @override
  String toString() =>
      'DimensionLevel(id: $id, name: $name, abbr: $abbr, ordering: $ordering)';
}

/// Encode a list of [DimensionLevel]s to the JSON string stored in
/// `Dimensions.levelsJson`.
String encodeLevelsJson(List<DimensionLevel> levels) =>
    jsonEncode(levels.map((l) => l.toJson()).toList());

/// Decode the JSON string stored in `Dimensions.levelsJson` back to a list.
///
/// Defensive against malformed DB state — returns `const []` on empty input,
/// non-JSON input, or input that does not decode to a List. Phase 4 threat
/// T-04-07.
List<DimensionLevel> decodeLevelsJson(String raw) {
  if (raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => DimensionLevel.fromJson(m.cast<String, dynamic>()))
        .toList();
  } on FormatException {
    return const [];
  }
}
