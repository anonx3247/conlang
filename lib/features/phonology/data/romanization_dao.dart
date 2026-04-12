import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../domain/notation_helpers.dart';
import 'romanization_bijection.dart';

part 'romanization_dao.g.dart';

/// Drift DAO for CRUD operations on the [RomanizationMappings] table.
///
/// Accessed via [AppDatabase.romanizationDao] (registered in the @DriftDatabase
/// daos list). All methods operate on the current project's database connection.
@DriftAccessor(tables: [RomanizationMappings])
class RomanizationDao extends DatabaseAccessor<AppDatabase>
    with _$RomanizationDaoMixin {
  RomanizationDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive queries
  // ---------------------------------------------------------------------------

  /// Returns a stream of all romanization mappings, updated on every change.
  ///
  /// Consumers watch this to rebuild UI when mappings are added, edited, or
  /// deleted.
  Stream<List<RomanizationMapping>> watchAllMappings() =>
      select(romanizationMappings).watch();

  // ---------------------------------------------------------------------------
  // One-shot queries
  // ---------------------------------------------------------------------------

  /// Fetches all mappings as a single future (non-reactive).
  ///
  /// Used by the romanize conversion function to build the replacement map
  /// on demand.
  Future<List<RomanizationMapping>> getAllMappings() =>
      select(romanizationMappings).get();

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Inserts a new mapping. Returns the new row's auto-generated ID.
  Future<int> insertMapping(RomanizationMappingsCompanion companion) =>
      into(romanizationMappings).insert(companion);

  /// Updates an existing mapping in place.
  ///
  /// Matches by primary key (id). Returns true if the row was updated.
  Future<bool> updateMapping(RomanizationMapping mapping) =>
      update(romanizationMappings).replace(mapping);

  /// Deletes the mapping with the given [id].
  Future<int> deleteMapping(int id) =>
      (delete(romanizationMappings)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Plan 04-15 D-72 + D-78: Bijection validator
  // ---------------------------------------------------------------------------

  /// Validates that the active romanization-mapping set forms a dot-aware
  /// bijection (D-78). Returns the list of violations — empty list means the
  /// mapping set is valid and rule DSL round-trip via `dotAwareDeromanize` /
  /// `smartRomanize` is safe.
  ///
  /// Three kinds of violations are reported:
  ///
  /// 1. [BijectionViolationKind.duplicatePhonemeTarget] — two rows sharing
  ///    the same `ipaSymbol`. Not dot-disambiguatable.
  /// 2. [BijectionViolationKind.duplicateRomTarget] — two rows sharing the
  ///    same `latinMapping`. Not dot-disambiguatable.
  /// 3. [BijectionViolationKind.nonRoundTrip] — D-78 revision: the set as a
  ///    whole has at least one phoneme pair (p, q) where
  ///    `dotAwareDeromanize(smartRomanize(p + q)) != p + q`. This is a
  ///    property of the SET, not a row — sets like `{t→t, h→h, θ→th}`
  ///    now PASS this check because `at.ha` disambiguates them.
  ///
  /// The non-round-trip check composes the full active mapping set (not
  /// each row in isolation) because the underlying bug is always a property
  /// of the set.
  Future<List<BijectionViolation>> validateRomanizationBijection() async {
    final mappings = await getAllMappings();
    return _validateBijectionForRows(mappings);
  }
}

// ---------------------------------------------------------------------------
// Pure validation helper — exposed at the library level so the provider can
// run a dry-run validation on a proposed mapping set (without hitting the
// DB) and the widget test can call it directly with a seeded row list.
// ---------------------------------------------------------------------------

List<BijectionViolation> _validateBijectionForRows(
  List<RomanizationMapping> rows,
) {
  final violations = <BijectionViolation>[];

  // Drop rows with empty strings — they are not active mappings.
  final active = rows
      .where((r) => r.ipaSymbol.isNotEmpty && r.latinMapping.isNotEmpty)
      .toList();

  // Check 1: duplicate phoneme targets.
  final byIpa = <String, List<RomanizationMapping>>{};
  for (final m in active) {
    byIpa.putIfAbsent(m.ipaSymbol, () => []).add(m);
  }
  for (final entry in byIpa.entries) {
    if (entry.value.length > 1) {
      for (final row in entry.value.skip(1)) {
        violations.add(BijectionViolation(
          kind: BijectionViolationKind.duplicatePhonemeTarget,
          rowId: row.id,
          detail:
              'Phoneme /${entry.key}/ is mapped by more than one row '
              '(rows: ${entry.value.map((r) => r.id).join(', ')}).',
        ));
      }
    }
  }

  // Check 2: duplicate rom targets.
  final byRom = <String, List<RomanizationMapping>>{};
  for (final m in active) {
    byRom.putIfAbsent(m.latinMapping, () => []).add(m);
  }
  for (final entry in byRom.entries) {
    if (entry.value.length > 1) {
      for (final row in entry.value.skip(1)) {
        violations.add(BijectionViolation(
          kind: BijectionViolationKind.duplicateRomTarget,
          rowId: row.id,
          detail:
              'Rom glyph "${entry.key}" is targeted by more than one phoneme '
              '(rows: ${entry.value.map((r) => r.id).join(', ')}). '
              'No dot boundary can recover this ambiguity.',
        ));
      }
    }
  }

  // Check 3: D-78 sequence-level round-trip. Skip if we already have
  // duplicate-target violations — those must be fixed first and would
  // make this check noisy with redundant errors.
  if (violations.isEmpty) {
    // Project to the pure NotationMapping shape for the helper library.
    final notation = active
        .map<NotationMapping>(
          (m) => (ipaSymbol: m.ipaSymbol, latinMapping: m.latinMapping),
        )
        .toList();
    if (!isDotAwareBijection(notation)) {
      // Walk pairwise to find at least one offending pair to name in the
      // detail. The helper already knows the answer — we just re-search
      // to produce a nice error message.
      String? offenderDetail;
      outer:
      for (final p in notation) {
        for (final q in notation) {
          final input = p.ipaSymbol + q.ipaSymbol;
          final rom = smartRomanize(input, notation);
          final back = dotAwareDeromanize(rom, notation);
          if (back != input) {
            offenderDetail =
                'Phoneme pair /${p.ipaSymbol}/+/${q.ipaSymbol}/ does not '
                'round-trip (rom="$rom" → re-parsed as "$back").';
            break outer;
          }
        }
      }
      violations.add(BijectionViolation(
        kind: BijectionViolationKind.nonRoundTrip,
        rowId: null,
        detail: offenderDetail ??
            'Mapping set does not form a dot-aware bijection.',
      ));
    }
  }

  return violations;
}

/// Public entry point that exposes the pure validation helper for callers
/// that already have a list of rows in hand (e.g. the settings page running
/// a dry-run on a proposed insert/update set).
List<BijectionViolation> validateMappingsBijection(
  List<RomanizationMapping> rows,
) =>
    _validateBijectionForRows(rows);
