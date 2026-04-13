import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import '../domain/notation_helpers.dart';
import 'romanization_bijection.dart';
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

/// Returns a `String Function(String ipa)` that converts an IPA string to
/// its romanized Latin form using the project's currently defined mappings.
///
/// D-78 (plan 04-15): this provider is now a thin wrapper over
/// [smartRomanize] in `notation_helpers.dart`. It emits `.` between
/// adjacent rom tokens whenever naive concatenation would re-parse as a
/// different phoneme sequence (e.g. `/atha/` → `at.ha` when `θ→th` is in
/// the mapping set). See `notation_helpers.dart` for the boundary-insertion
/// algorithm. `.` is a consumed glyph separator — see notation_helpers.dart.
///
/// Watches the live mappings stream so the function updates whenever
/// mappings are added, edited, or deleted. When no project is open,
/// returns an identity function.
final romanizeProvider = Provider<String Function(String ipa)>((ref) {
  final mappingsAsync = ref.watch(romanizationMappingsProvider);
  final mappings = mappingsAsync.asData?.value;
  if (mappings == null || mappings.isEmpty) return (String ipa) => ipa;

  final notation = mappings
      .map<NotationMapping>(
        (m) => (ipaSymbol: m.ipaSymbol, latinMapping: m.latinMapping),
      )
      .toList(growable: false);
  return (String ipa) => smartRomanize(ipa, notation);
});

// ---------------------------------------------------------------------------
// Inverse romanization (deromanize)
// ---------------------------------------------------------------------------

/// Returns a `String Function(String latin)` that converts a romanized
/// Latin string back into its IPA form using the project's currently
/// defined mappings in reverse.
///
/// D-78 (plan 04-15): this provider is now a thin wrapper over
/// [dotAwareDeromanize] in `notation_helpers.dart`. `.` is a consumed glyph
/// separator — typing `at.ha` under the `(t, h, th)` mapping set yields
/// three separate phonemes `/atha/` while `atha` yields `/aθa/` via
/// longest-match. See `notation_helpers.dart` for the algorithm.
///
/// When no project is open, returns an identity function. Used by the word
/// creation / edit forms and the rule editor dialog to convert rom input
/// to phonemic storage.
final deromanizeProvider = Provider<String Function(String latin)>((ref) {
  final mappingsAsync = ref.watch(romanizationMappingsProvider);
  final mappings = mappingsAsync.asData?.value;
  if (mappings == null || mappings.isEmpty) return (String latin) => latin;

  final notation = mappings
      .where((m) => m.latinMapping.isNotEmpty && m.ipaSymbol.isNotEmpty)
      .map<NotationMapping>(
        (m) => (ipaSymbol: m.ipaSymbol, latinMapping: m.latinMapping),
      )
      .toList(growable: false);
  if (notation.isEmpty) return (String latin) => latin;
  return (String latin) => dotAwareDeromanize(latin, notation);
});

// ---------------------------------------------------------------------------
// Plan 04-15 D-72: Bijection status provider
// ---------------------------------------------------------------------------

/// Watches the current romanization mapping set and exposes the list of
/// bijection violations (empty list = valid). Used by the romanization
/// settings section for the project-open banner and by the rule editor
/// dialog for the edit-locked gate.
///
/// Updates reactively whenever mappings change.
final bijectionStatusProvider =
    Provider<AsyncValue<List<BijectionViolation>>>((ref) {
  final mappingsAsync = ref.watch(romanizationMappingsProvider);
  return mappingsAsync.when(
    data: (mappings) =>
        AsyncValue.data(validateMappingsBijection(mappings)),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// True when [lexeme] has a manually-overridden IPA — i.e. its stored IPA
/// differs from what `deromanize(romanization)` would produce. Words with no
/// romanization, or with a romanization that round-trips to the stored IPA,
/// are considered NOT overridden.
///
/// Used by list / detail views to render a visual flag indicating that the
/// IPA is intentional rather than derived from orthography.
bool isIpaManuallyOverridden(
  String ipa,
  String? romanization,
  String Function(String) deromanize,
) {
  if (romanization == null || romanization.isEmpty) return false;
  return deromanize(romanization) != ipa;
}
