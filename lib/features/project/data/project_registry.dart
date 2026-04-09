import 'dart:convert';
import 'dart:io';

import '../domain/project.dart';

/// Manages the `registry.json` file that tracks all known projects.
///
/// The registry lives at:
///   {appDocumentsDir}/conlang/registry.json
///
/// Each project also gets its own directory:
///   {appDocumentsDir}/conlang/{projectId}/
///
/// The SQLite database for each project lives inside that directory as
/// `project.db` (created by AppDatabase via Drift).
class ProjectRegistry {
  ProjectRegistry({required this.baseDir});

  /// The `{appDocumentsDir}/conlang/` directory (created on first use).
  final String baseDir;

  File get _registryFile => File('$baseDir/registry.json');

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _ensureBaseDir() async {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  Future<List<Project>> _readAll() async {
    await _ensureBaseDir();
    final file = _registryFile;
    if (!file.existsSync()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> raw = jsonDecode(content) as List<dynamic>;
      return raw
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt registry — return empty so the app can recover.
      return [];
    }
  }

  Future<void> _writeAll(List<Project> projects) async {
    await _ensureBaseDir();
    final content = const JsonEncoder.withIndent('  ')
        .convert(projects.map((p) => p.toJson()).toList());
    await _registryFile.writeAsString(content);
  }

  /// Generates a short unique ID from the current timestamp.
  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Convert to base-36 string, pad to 10 chars for uniqueness.
    return ts.toRadixString(36).padLeft(10, '0');
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns all known projects, sorted by last opened (most recent first).
  Future<List<Project>> listProjects() async {
    final projects = await _readAll();
    projects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return projects;
  }

  /// Creates a new project with the given [name].
  ///
  /// - Generates a unique ID
  /// - Creates `{baseDir}/{id}/` directory
  /// - Writes a new entry to the registry
  ///
  /// Returns the newly created [Project].
  Future<Project> createProject(String name) async {
    assert(name.trim().isNotEmpty, 'Project name must not be empty');

    final id = _generateId();
    final dirPath = '$baseDir/$id';
    final now = DateTime.now();

    // Create the project directory.
    await Directory(dirPath).create(recursive: true);

    final project = Project(
      id: id,
      name: name.trim(),
      createdAt: now,
      lastOpenedAt: now,
      directoryPath: dirPath,
    );

    final projects = await _readAll();
    projects.add(project);
    await _writeAll(projects);

    return project;
  }

  /// Deletes a project by [id].
  ///
  /// - Removes the project directory and all its contents (including project.db)
  /// - Removes the entry from the registry JSON
  Future<void> deleteProject(String id) async {
    final projects = await _readAll();
    final project = projects.where((p) => p.id == id).firstOrNull;

    if (project != null) {
      final dir = Directory(project.directoryPath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }

    final updated = projects.where((p) => p.id != id).toList();
    await _writeAll(updated);
  }

  /// Updates the `lastOpenedAt` timestamp for the given project [id].
  ///
  /// Call this whenever a project is opened so the selector shows it at the top.
  Future<void> updateLastOpened(String id) async {
    final projects = await _readAll();
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;

    projects[idx] = projects[idx].copyWith(lastOpenedAt: DateTime.now());
    await _writeAll(projects);
  }

  /// Looks up a single project by [id]. Returns null if not found.
  Future<Project?> findById(String id) async {
    final projects = await _readAll();
    return projects.where((p) => p.id == id).firstOrNull;
  }
}
