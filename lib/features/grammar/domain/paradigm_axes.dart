import 'dart:convert';

import '../../../db/app_database.dart' show Dimension;

/// Axis configuration for rendering a paradigm table (Phase 4 CONTEXT.md D-26).
///
/// - [rows]: dimension id whose levels become table rows (nullable = unused)
/// - [cols]: dimension id whose levels become table columns (nullable = unused)
/// - [tabs]: remaining dimension ids become a tab bar / dropdown (empty list
///   = no tabs)
///
/// Persisted per-POS in `project_settings` under
/// `typology.paradigm_axes.{posId}` as a JSON string.
class ParadigmAxes {
  const ParadigmAxes({this.rows, this.cols, this.tabs = const []});

  final int? rows;
  final int? cols;
  final List<int> tabs;

  Map<String, dynamic> toJson() => {
        if (rows != null) 'rows': rows,
        if (cols != null) 'cols': cols,
        'tabs': tabs,
      };

  factory ParadigmAxes.fromJson(Map<String, dynamic> json) {
    final tabsRaw = json['tabs'];
    return ParadigmAxes(
      rows: json['rows'] as int?,
      cols: json['cols'] as int?,
      tabs: tabsRaw is List ? tabsRaw.whereType<int>().toList() : const [],
    );
  }

  /// Parses a JSON string, returning [ParadigmAxes] with all defaults on
  /// empty, malformed, or non-map input. T-04-11 mitigation: no throws for
  /// hand-edited or corrupted `project_settings` values.
  factory ParadigmAxes.fromJsonString(String raw) {
    if (raw.isEmpty) return const ParadigmAxes();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ParadigmAxes();
      return ParadigmAxes.fromJson(decoded.cast<String, dynamic>());
    } on FormatException {
      return const ParadigmAxes();
    }
  }

  String toJsonString() => jsonEncode(toJson());

  /// Sensible default chooser: first dim = rows, second = cols, rest = tabs.
  /// Used when no explicit axis config exists for a POS.
  factory ParadigmAxes.defaultsFor(List<Dimension> dims) {
    if (dims.isEmpty) return const ParadigmAxes();
    if (dims.length == 1) return ParadigmAxes(rows: dims.first.id);
    return ParadigmAxes(
      rows: dims[0].id,
      cols: dims[1].id,
      tabs: dims.skip(2).map((d) => d.id).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ParadigmAxes) return false;
    if (other.rows != rows || other.cols != cols) return false;
    if (other.tabs.length != tabs.length) return false;
    for (var i = 0; i < tabs.length; i++) {
      if (other.tabs[i] != tabs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(rows, cols, Object.hashAll(tabs));

  @override
  String toString() =>
      'ParadigmAxes(rows: $rows, cols: $cols, tabs: $tabs)';
}
