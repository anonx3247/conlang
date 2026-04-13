import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/project.dart';

/// Manages the `registry.json` file that tracks all known projects.
///
/// The registry lives at:
///   {appDocumentsDir}/conlang/registry.json
///
/// Projects are now standalone .conlang files (SQLite DB with custom extension)
/// that can be placed anywhere the user chooses. The registry simply records
/// the file paths, display names, and timestamps for each known project.
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

  /// Creates a new project with the given [name] at the user-chosen [filePath].
  ///
  /// - Generates a unique ID
  /// - Creates an empty file at [filePath] if it does not already exist
  ///   (Drift will initialise the DB schema on first open)
  /// - Registers the project in registry.json
  ///
  /// [filePath] is optional for backward compatibility with existing call sites
  /// that have not yet been updated to supply a path. When omitted, the project
  /// is stored in the legacy `{baseDir}/{id}/project.db` layout so existing
  /// workflows keep compiling while Plan 03 adds the native save-dialog flow.
  ///
  /// Returns the newly created [Project].
  Future<Project> createProject(String name, [String? filePath]) async {
    assert(name.trim().isNotEmpty, 'Project name must not be empty');

    final id = _generateId();
    final now = DateTime.now();

    // Resolve the actual file path, falling back to the legacy layout when the
    // caller does not (yet) supply one.
    final resolvedFilePath =
        (filePath != null && filePath.trim().isNotEmpty)
            ? filePath
            : path.join(baseDir, id, 'project.db');

    // Ensure the parent directory exists and touch the file so Drift can open it.
    await Directory(path.dirname(resolvedFilePath)).create(recursive: true);
    final file = File(resolvedFilePath);
    if (!file.existsSync()) {
      await file.create();
    }

    // Reassign to final local so the closure below can capture it cleanly.
    filePath = resolvedFilePath;

    final project = Project(
      id: id,
      name: name.trim(),
      createdAt: now,
      lastOpenedAt: now,
      filePath: filePath,
    );

    final projects = await _readAll();
    projects.add(project);
    await _writeAll(projects);

    return project;
  }

  /// Registers an existing .conlang file in the registry.
  ///
  /// - Verifies the file exists on disk
  /// - If the file path is already registered, returns the existing [Project]
  /// - Otherwise creates a new registry entry whose name is derived from the
  ///   filename (strips the `.conlang` extension)
  ///
  /// Returns the [Project] for the opened file.
  Future<Project> openProjectFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    final projects = await _readAll();

    // If already registered, return existing entry.
    final existing =
        projects.where((p) => p.filePath == filePath).firstOrNull;
    if (existing != null) return existing;

    // Derive display name from filename.
    final basename = path.basenameWithoutExtension(filePath);
    final id = _generateId();
    final now = DateTime.now();

    final project = Project(
      id: id,
      name: basename,
      createdAt: now,
      lastOpenedAt: now,
      filePath: filePath,
    );

    projects.add(project);
    await _writeAll(projects);

    return project;
  }

  /// Copies a project's .conlang file to [newFilePath] and registers the copy
  /// as a new project ("Save As" / duplicate flow).
  ///
  /// - Reads the source project by [sourceId]
  /// - Copies the .conlang file to [newFilePath]
  /// - Registers the copy as a distinct project (new ID, same name by default)
  ///
  /// Returns the newly registered [Project].
  Future<Project> duplicateProject(String sourceId, String newFilePath) async {
    final projects = await _readAll();
    final source = projects.where((p) => p.id == sourceId).firstOrNull;
    if (source == null) {
      throw ArgumentError('Project not found: $sourceId');
    }

    final sourceFile = File(source.filePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('Source file not found', source.filePath);
    }

    // Ensure target parent directory exists then copy.
    await Directory(path.dirname(newFilePath)).create(recursive: true);
    await sourceFile.copy(newFilePath);

    final id = _generateId();
    final now = DateTime.now();

    final newProject = Project(
      id: id,
      name: source.name,
      createdAt: now,
      lastOpenedAt: now,
      filePath: newFilePath,
    );

    projects.add(newProject);
    await _writeAll(projects);

    return newProject;
  }

  /// Updates the display [newName] for the project with the given [id].
  ///
  /// Per D-10: the display name is stored in project metadata only — the
  /// .conlang filename on disk is NOT renamed.
  Future<void> renameProject(String id, String newName) async {
    assert(newName.trim().isNotEmpty, 'New name must not be empty');

    final projects = await _readAll();
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;

    projects[idx] = projects[idx].copyWith(name: newName.trim());
    await _writeAll(projects);
  }

  /// Deletes a project by [id].
  ///
  /// - Removes the .conlang file from disk
  /// - Removes the entry from the registry JSON
  Future<void> deleteProject(String id) async {
    final projects = await _readAll();
    final project = projects.where((p) => p.id == id).firstOrNull;

    if (project != null) {
      final file = File(project.filePath);
      if (file.existsSync()) {
        await file.delete();
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
