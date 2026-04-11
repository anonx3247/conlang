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
/// as the root for all project directories and the registry.json file.
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
  /// Phase 4: Before flipping state we run [prepareProjectDb] which
  /// transparently copies project.db to project.db.v7.bak if the file
  /// is at a pre-v8 schema. This must happen BEFORE the projectDatabase
  /// family provider materialises an [AppDatabase] for [id], otherwise
  /// Drift's onUpgrade would mutate rows we have not backed up yet.
  Future<void> open(String id) async {
    final docsDir = await ref.read(appDocsDirProvider.future);
    final dbPath = p.join(docsDir, id, 'project.db');
    await prepareProjectDb(dbPath);
    state = id;
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
/// Path: `{appDocsDir}/{projectId}/project.db`
@riverpod
AppDatabase projectDatabase(Ref ref, String projectId) {
  // We need the absolute path to the project's database file.
  // Because appDocsDirProvider is async, we read its cached value.
  // If it hasn't resolved yet, we use a placeholder path — the LazyDatabase
  // inside AppDatabase.fromPath defers the actual file open until first use,
  // at which point the path will be correct.
  //
  // In practice, currentDatabase (below) only creates the db after
  // appDocsDir has resolved, so the fallback path is never actually used.
  final docsDir = ref.read(appDocsDirProvider).value ??
      p.join('.', 'conlang'); // fallback, never used in practice

  final dbPath = p.join(docsDir, projectId, 'project.db');
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
