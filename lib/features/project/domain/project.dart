import 'dart:convert';

import 'package:path/path.dart' as path;

/// Represents a single conlang project backed by a .conlang file (SQLite DB
/// with a custom extension) that the user places anywhere on disk.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastOpenedAt,
    required this.filePath,
  });

  /// Unique identifier (timestamp-based base-36 string, e.g. "lf3q2k1a9z").
  final String id;

  /// User-facing project name, e.g. "Elvish" or "My First Conlang".
  final String name;

  /// When the project was first created.
  final DateTime createdAt;

  /// When the project was last opened (updated on each open).
  final DateTime lastOpenedAt;

  /// Absolute path to the .conlang file on disk.
  /// e.g. `/Users/x/Documents/Elvish.conlang`
  final String filePath;

  /// Absolute path to the directory containing the .conlang file.
  /// Derived from [filePath] for convenience / backward compat.
  String get directoryPath => path.dirname(filePath);

  /// Deserialise from the registry JSON map.
  ///
  /// Backward compat: if the stored entry has `directoryPath` but no
  /// `filePath` (legacy format from before Plan 09-02), the filePath is
  /// derived as `{directoryPath}/project.db` so existing projects keep
  /// working without a manual migration step.
  factory Project.fromJson(Map<String, dynamic> json) {
    final String resolvedFilePath;
    if (json.containsKey('filePath')) {
      resolvedFilePath = json['filePath'] as String;
    } else {
      // Legacy entry — derive filePath from directoryPath.
      final dir = json['directoryPath'] as String;
      resolvedFilePath = path.join(dir, 'project.db');
    }

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      filePath: resolvedFilePath,
    );
  }

  /// Serialise to a JSON-compatible map for registry storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'filePath': filePath,
    };
  }

  /// Returns a copy of this project with the given fields replaced.
  Project copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    String? filePath,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Project(id: $id, name: $name, filePath: $filePath)';

  // Convenience: encode/decode a Project to/from a JSON string.
  String toJsonString() => jsonEncode(toJson());
  factory Project.fromJsonString(String s) =>
      Project.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
