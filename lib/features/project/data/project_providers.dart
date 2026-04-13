import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../db/app_database.dart';
import 'project_backup.dart';
import 'project_registry.dart';

part 'project_providers.g.dart';

// ---------------------------------------------------------------------------
// Documents directory (cached)
// ---------------------------------------------------------------------------

/// Resolves and caches the application documents directory path.
///
/// Returns the absolute path to `{appDocumentsDir}/conlang/` which serves
/// as the root for the registry.json file (and legacy project directories).
@riverpod
Future<String> appDocsDir(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'conlang');
}

// ---------------------------------------------------------------------------
// Current project selection
// ---------------------------------------------------------------------------

/// Holds the ID of the currently open project, or null when no project is open.
///
/// Set this via `ref.read(currentProjectIdProvider.notifier).state = id`
/// to switch projects anywhere in the app.
@riverpod
class CurrentProjectId extends _$CurrentProjectId {
  @override
  String? build() => null;

  /// Opens (or switches to) the project with the given [id].
  ///
  /// Resolves the project's [filePath] from the registry so the pre-open
  /// backup step (Phase 4) operates on the correct file regardless of whether
  /// the project uses the legacy `{docsDir}/{id}/project.db` layout or a
  /// user-chosen .conlang path.
  Future<void> open(String id) async {
    // Try to resolve filePath from registry. Fall back to legacy path so
    // existing projects continue to work even if not yet in the registry.
    final dbPath = await _resolveDbPath(id);
    await prepareProjectDb(dbPath);
    state = id;
  }

  Future<String> _resolveDbPath(String id) async {
    try {
      final registry = await ref.read(projectRegistryProvider.future);
      final project = await registry.findById(id);
      if (project != null) return project.filePath;
    } catch (_) {
      // Registry unavailable — fall through to legacy path.
    }
    // Legacy fallback: construct old-style path.
    final docsDir = await ref.read(appDocsDirProvider.future);
    return p.join(docsDir, id, 'project.db');
  }

  /// Synchronous open used by tests / hot-reload paths that already
  /// guarantee the v8 backup ran. Prefer [open] in production code.
  void openWithoutBackup(String id) => state = id;

  /// Closes the current project, returning to the empty state.
  void close() => state = null;
}

/// Prepares a project database file for opening by performing any pre-open
/// migrations safety steps. Currently:
///   - Phase 4: backs up pre-v8 project.db files to project.db.v7.bak
///     (see [backupProjectDbIfNeeded]).
///
/// Idempotent — safe to call multiple times for the same [dbPath].
Future<void> prepareProjectDb(String dbPath) async {
  await backupProjectDbIfNeeded(dbPath);
}

// ---------------------------------------------------------------------------
// Per-project file path (async resolver)
// ---------------------------------------------------------------------------

/// Resolves the absolute file path for the project database identified by
/// [projectId].
///
/// Looks up the project in the registry to get its [filePath]. Falls back to
/// the legacy `{appDocsDir}/{projectId}/project.db` path for projects that
/// pre-date the .conlang file format (Plan 09-02 backward compat).
@riverpod
Future<String> projectFilePath(Ref ref, String projectId) async {
  try {
    final registry = await ref.watch(projectRegistryProvider.future);
    final project = await registry.findById(projectId);
    if (project != null) return project.filePath;
  } catch (_) {
    // Registry unavailable — fall through to legacy path.
  }
  // Legacy fallback.
  final docsDir = await ref.watch(appDocsDirProvider.future);
  return p.join(docsDir, projectId, 'project.db');
}

// ---------------------------------------------------------------------------
// Per-project database (family provider)
// ---------------------------------------------------------------------------

/// Returns an [AppDatabase] instance scoped to [projectId].
///
/// Uses a family provider so that each project gets exactly one database
/// connection, shared across all widgets in the same project context.
/// Disposal (via [ref.onDispose]) closes the SQLite connection — critical
/// to avoid "database is closed" errors when switching projects (Pitfall 1
/// from Phase 1 research).
///
/// The database path is resolved from the project's [filePath] in the
/// registry (Plan 09-02). Legacy projects (`{appDocsDir}/{id}/project.db`)
/// are handled transparently via [projectFilePathProvider]'s fallback logic.
@riverpod
AppDatabase projectDatabase(Ref ref, String projectId) {
  // Resolve from registry async provider if already cached; otherwise fall
  // back to the legacy synchronous path. The LazyDatabase inside
  // AppDatabase.fromPath defers the actual file open until first query, so
  // the path just needs to be correct before the first real read/write.
  final filePathAsync = ref.watch(projectFilePathProvider(projectId));

  final String dbPath;
  if (filePathAsync.hasValue) {
    dbPath = filePathAsync.value!;
  } else {
    // Fallback while projectFilePathProvider is resolving (async gap).
    final docsDir = ref.read(appDocsDirProvider).value ??
        p.join('.', 'conlang'); // never used in practice
    dbPath = p.join(docsDir, projectId, 'project.db');
  }

  final db = AppDatabase.fromPath(dbPath);

  // CRITICAL: close the SQLite connection when the provider is disposed.
  // This fires when currentProjectId changes or the ProviderScope is unmounted.
  ref.onDispose(db.close);

  return db;
}

// ---------------------------------------------------------------------------
// Current project database (derived)
// ---------------------------------------------------------------------------

/// Watches [currentProjectIdProvider] and returns the open [AppDatabase],
/// or null when no project is selected.
///
/// Consumers watch this to get database access. Null means "show empty state".
@riverpod
AppDatabase? currentDatabase(Ref ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;
  return ref.watch(projectDatabaseProvider(projectId));
}

// ---------------------------------------------------------------------------
// Project registry
// ---------------------------------------------------------------------------

/// Provides a [ProjectRegistry] rooted at the application documents directory.
///
/// The registry is async because [appDocsDirProvider] is async. In practice
/// it resolves within a few ms on app startup.
@riverpod
Future<ProjectRegistry> projectRegistry(Ref ref) async {
  final baseDir = await ref.watch(appDocsDirProvider.future);
  return ProjectRegistry(baseDir: baseDir);
}
