import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Copies `project.db` to `project.db.v7.bak` iff:
///   - the file at [dbPath] exists, AND
///   - its current `PRAGMA user_version` is less than 8 (i.e. pre-Phase-4 schema), AND
///   - a backup at `$dbPath.v7.bak` does NOT already exist.
///
/// Must be called BEFORE opening the Drift `AppDatabase` on the file, because
/// Drift's `onUpgrade` mutates rows as soon as it opens.
///
/// Returns true iff a new backup file was written.
///
/// Phase 4 research recommendation A8 — safety net for the first mutating
/// migration (v7→v8). The backup is a byte-for-byte copy of the SQLite file;
/// on corruption, the user (or a future recovery tool) can restore by
/// renaming `.v7.bak` back to `project.db`.
///
/// Threat model note (T-04-03): the backup file lives next to the live db.
/// On a single-user desktop tool any process with read access to the project
/// folder already has access to the live db, so this is acceptable.
Future<bool> backupProjectDbIfNeeded(String dbPath) async {
  final dbFile = File(dbPath);
  if (!dbFile.existsSync()) return false;

  final backupFile = File('$dbPath.v7.bak');
  if (backupFile.existsSync()) return false;

  // Read user_version without Drift to avoid triggering onUpgrade.
  final raw = sqlite3.open(dbPath);
  int userVersion;
  try {
    final result = raw.select('PRAGMA user_version');
    userVersion =
        result.isEmpty ? 0 : (result.first.values.first as int? ?? 0);
  } finally {
    raw.dispose();
  }

  if (userVersion >= 8) return false;

  await dbFile.copy(backupFile.path);
  return true;
}
