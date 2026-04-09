import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import 'romanization_dao.dart';

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// Returns the [RomanizationDao] for the currently open project database, or
/// null when no project is open.
final romanizationDaoProvider = Provider<RomanizationDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.romanizationDao;
});

// ---------------------------------------------------------------------------
// Mapping list provider
// ---------------------------------------------------------------------------

/// Watches all romanization mappings in the current project.
///
/// Returns an empty list when no project is open. The stream updates
/// reactively whenever mappings are added, edited, or deleted.
final romanizationMappingsProvider = StreamProvider<List<RomanizationMapping>>(
  (ref) {
    final dao = ref.watch(romanizationDaoProvider);
    if (dao == null) return Stream.value([]);
    return dao.watchAllMappings();
  },
);

// ---------------------------------------------------------------------------
// Romanization enabled provider
// ---------------------------------------------------------------------------

const _kRomanizationKey = 'romanization_enabled';

/// Watches the project-level romanization toggle.
///
/// Returns `true` when no setting exists (default on). Updates reactively
/// when the setting changes.
final romanizationEnabledProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(true);
  return db
      .select(db.projectSettings)
      .watch()
      .map((rows) {
        final row = rows.where((r) => r.key == _kRomanizationKey).firstOrNull;
        return row?.value != 'false';
      });
});

/// Upserts the romanization_enabled setting for the current project.
///
/// Uses a direct UPDATE-then-INSERT pattern because Drift's
/// `insertOnConflictUpdate` targets the primary key (id), not the unique
/// `key` column — so a second insert creates a duplicate row instead of
/// updating the existing one.
Future<void> setRomanizationEnabled(WidgetRef ref, bool enabled) async {
  final db = ref.read(currentDatabaseProvider);
  if (db == null) return;
  final updated = await (db.update(db.projectSettings)
        ..where((t) => t.key.equals(_kRomanizationKey)))
      .write(ProjectSettingsCompanion(value: Value(enabled.toString())));
  if (updated == 0) {
    await db.into(db.projectSettings).insert(
          ProjectSettingsCompanion.insert(
            key: _kRomanizationKey,
            value: enabled.toString(),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Romanization conversion function provider
// ---------------------------------------------------------------------------

/// Returns a String Function(String ipa) that converts an IPA string to its
/// romanized Latin form using the project's currently defined mappings.
///
/// When no project is open (DAO is null), returns an identity function.
final romanizeProvider = FutureProvider<String Function(String ipa)>((
  ref,
) async {
  final dao = ref.watch(romanizationDaoProvider);
  if (dao == null) return (String ipa) => ipa;

  final mappings = await dao.getAllMappings();

  final sorted = List<RomanizationMapping>.from(mappings)
    ..sort((a, b) => b.ipaSymbol.length.compareTo(a.ipaSymbol.length));

  return (String ipa) {
    var result = ipa;
    for (final mapping in sorted) {
      result = result.replaceAll(mapping.ipaSymbol, mapping.latinMapping);
    }
    return result;
  };
});
