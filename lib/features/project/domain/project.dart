import 'dart:convert';

/// Represents a single conlang project. Each project has its own SQLite
/// database in an isolated directory.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastOpenedAt,
    required this.directoryPath,
  });

  /// Unique identifier (timestamp-based hex string, e.g. "1a2b3c4d5e6f").
  final String id;

  /// User-facing project name, e.g. "Elvish" or "My First Conlang".
  final String name;

  /// When the project was first created.
  final DateTime createdAt;

  /// When the project was last opened (updated on each open).
  final DateTime lastOpenedAt;

  /// Absolute path to the project directory on disk.
  /// Format: {appDocumentsDir}/conlang/{id}/
  final String directoryPath;

  /// Deserialise from the registry JSON map.
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      directoryPath: json['directoryPath'] as String,
    );
  }

  /// Serialise to a JSON-compatible map for registry storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'directoryPath': directoryPath,
    };
  }

  /// Returns a copy of this project with the given fields replaced.
  Project copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    String? directoryPath,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      directoryPath: directoryPath ?? this.directoryPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Project(id: $id, name: $name)';

  // Convenience: encode/decode a Project to/from a JSON string.
  String toJsonString() => jsonEncode(toJson());
  factory Project.fromJsonString(String s) => Project.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
