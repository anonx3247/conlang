import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import '../domain/marker.dart';
import 'dimension_templates.dart';
import 'grammar_dao.dart';
import 'inflectional_rule_pos_dao.dart';
import 'intrinsic_levels_codec.dart';
import 'lexeme_parents_dao.dart';
import 'marker_dao.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05, riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time, so grammar-scoped providers that traffic in Drift-generated
// classes (`Dimension`, `MorphologicalRule`, etc.) must be hand-written.

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// The [GrammarDao] scoped to the currently-open project database.
///
/// Returns null when no project is open.
final grammarDaoProvider = Provider<GrammarDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.grammarDao;
});

// ---------------------------------------------------------------------------
// Dimensions providers
// ---------------------------------------------------------------------------

/// Watches dimensions for a given POS, reactive to DB changes. Emits an
/// empty list stream when no project is open.
final dimensionsForPosProvider =
    StreamProvider.family<List<Dimension>, int>((ref, posId) {
  final dao = ref.watch(grammarDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchDimensionsForPos(posId);
});

// ---------------------------------------------------------------------------
// Template catalog provider
// ---------------------------------------------------------------------------

/// Constant template catalog — for UI consumption in the "Add Dimension"
/// picker. Stable reference (no DB access), but exposed as a provider for
/// consistency with the other grammar providers.
final dimensionTemplatesProvider = Provider<List<DimensionTemplate>>((ref) {
  return dimensionTemplates;
});

// ---------------------------------------------------------------------------
// Markers providers (Phase 4 gap D-44, plan 04-10)
// ---------------------------------------------------------------------------

/// The [MarkerDao] scoped to the currently-open project database. Returns
/// null when no project is open so call sites can short-circuit to an empty
/// list without touching a nullable Drift database.
final markerDaoProvider = Provider<MarkerDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.markerDao;
});

/// Watches the markers bound to a given POS. Emits the empty list when no
/// project is open. Used by [computedInflectedParadigmProvider] to apply the
/// D-45 resolution step 3 (marker lookup after the inflectional rule chain).
final markersForPosProvider =
    StreamProvider.family<List<MarkerDecl>, int>((ref, posId) {
  final dao = ref.watch(markerDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchMarkersForPos(posId);
});

// ---------------------------------------------------------------------------
// Inflectional rule POS junction providers (D-55)
// ---------------------------------------------------------------------------

/// The [InflectionalRulePOSDao] scoped to the currently-open project
/// database. Returns null when no project is open.
final inflectionalRulePOSDaoProvider =
    Provider<InflectionalRulePOSDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db == null ? null : InflectionalRulePOSDao(db);
});

/// Streams the POS set attached to a single inflectional rule, identified
/// by rule id. Emits an empty set when no project is open.
final posSetForRuleProvider =
    StreamProvider.family<Set<int>, int>((ref, ruleId) {
  final dao = ref.watch(inflectionalRulePOSDaoProvider);
  if (dao == null) return Stream.value(const <int>{});
  return dao.watchPosSetForRule(ruleId);
});

/// Streams the full `Map<ruleId, Set<posId>>` for every inflectional rule
/// with at least one junction row. Used by the rules list (D-56) to group
/// rules by POS set without spawning one stream per rule.
final allRulePosSetsProvider =
    StreamProvider<Map<int, Set<int>>>((ref) {
  final dao = ref.watch(inflectionalRulePOSDaoProvider);
  if (dao == null) return Stream.value(const <int, Set<int>>{});
  return dao.watchAllPosSetsByRuleId();
});

// ---------------------------------------------------------------------------
// Lexeme parents junction providers (plan 04-12 — D-62)
// ---------------------------------------------------------------------------

/// The [LexemeParentsDao] scoped to the currently-open project database.
/// Returns null when no project is open.
final lexemeParentsDaoProvider = Provider<LexemeParentsDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db == null ? null : LexemeParentsDao(db);
});

/// Streams the manual parent links for a given child lexeme. Consumers
/// (plan 04-14 UI) render these alongside the rule-linked derivation so
/// the user sees a unified parent/etymology view.
final parentsForLexemeProvider =
    StreamProvider.family<List<LexemeParentRow>, int>((ref, childLexemeId) {
  final dao = ref.watch(lexemeParentsDaoProvider);
  if (dao == null) return const Stream<List<LexemeParentRow>>.empty();
  return dao.watchParentsForChild(childLexemeId);
});

/// Streams the manual child links for a given parent lexeme (the reverse
/// direction — "what does this lexeme produce derivations for").
final childrenForLexemeProvider =
    StreamProvider.family<List<LexemeParentRow>, int>((ref, parentLexemeId) {
  final dao = ref.watch(lexemeParentsDaoProvider);
  if (dao == null) return const Stream<List<LexemeParentRow>>.empty();
  return dao.watchChildrenForParent(parentLexemeId);
});

// ---------------------------------------------------------------------------
// D-82 / D-84 / D-85 — 04-17 intrinsic dimensions providers
// ---------------------------------------------------------------------------

/// D-82 — 04-17. Filters [dimensionsForPosProvider] to only intrinsic
/// dimensions. Used by the word creation / edit intrinsic sub-form
/// (Task 7) and the standard-form validation provider (Task 11).
final intrinsicDimensionsForPosProvider =
    Provider.family<List<Dimension>, int>((ref, posId) {
  final async = ref.watch(dimensionsForPosProvider(posId));
  final list = async.asData?.value ?? const <Dimension>[];
  return list.where((d) => d.intrinsic).toList();
});

/// D-85 — 04-17. Counts how many lexemes still carry an intrinsic level
/// entry for [dimId] in their [Lexemes.intrinsicLevelsJson]. Used by the
/// purge affordance's visibility check in dimension_editor_panel.dart.
/// Returns 0 when no project is open.
final staleIntrinsicEntryCountProvider =
    FutureProvider.family<int, int>((ref, dimId) async {
  final dao = ref.watch(grammarDaoProvider);
  if (dao == null) return 0;
  return dao.countStaleIntrinsicEntries(dimId);
});

/// D-84 — 04-17. Intrinsic backfill banner row payload surfaced on the
/// Inflections sub-tab after a false→true intrinsic toggle.
class IntrinsicBackfillBanner {
  const IntrinsicBackfillBanner({
    required this.dimId,
    required this.dimName,
    required this.count,
  });

  final int dimId;
  final String dimName;
  final int count;
}

/// D-84 — 04-17. Watches project_settings for pending backfill banner
/// rows (key pattern `intrinsic_backfill_pending_*`) and filters out
/// dismissed rows (key pattern `intrinsic_backfill_banner_dismissed_*`).
///
/// The provider is a FutureProvider that reads the project_settings table
/// directly via the database — it intentionally does not stream because
/// banners are only refreshed after explicit user action (dismiss or
/// toggle). Consumers call `ref.invalidate(intrinsicBackfillBannerProvider)`
/// to force a refresh.
final intrinsicBackfillBannerProvider =
    FutureProvider<List<IntrinsicBackfillBanner>>((ref) async {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return const [];
  final rows = await db.select(db.projectSettings).get();
  final pending = <IntrinsicBackfillBanner>[];
  final dismissedDimIds = <int>{};
  for (final row in rows) {
    if (row.key.startsWith('intrinsic_backfill_banner_dismissed_')) {
      final idPart = row.key.split('_').last;
      final id = int.tryParse(idPart);
      if (id != null && row.value == 'true') dismissedDimIds.add(id);
    }
  }
  for (final row in rows) {
    if (!row.key.startsWith('intrinsic_backfill_pending_')) continue;
    try {
      final decoded = _decodePendingBanner(row.value);
      if (decoded == null) continue;
      if (dismissedDimIds.contains(decoded.dimId)) continue;
      pending.add(decoded);
    } catch (_) {
      // Skip malformed rows silently.
    }
  }
  return pending;
});

/// D-88 / D-89 — 04-17. Helper used by `computedInflectedParadigmProvider`
/// in `typology_providers.dart` to build the intrinsic short-circuit
/// inputs for the paradigm engine:
///
/// - `dimensionIntrinsicFlags`: `{d.id: d.intrinsic}` for every dimension
///   the POS carries. The engine uses this flag map to decide, per rule
///   binding entry, whether the entry acts as an axis (non-intrinsic) or
///   a filter (intrinsic).
/// - `lexemeIntrinsicLevels`: [IntrinsicLevelsCodec.decode] of the
///   lexeme's stored `intrinsicLevelsJson`. Null / empty input decodes
///   to an empty map, which downstream fails any intrinsic constraint
///   check for that dim.
///
/// Keeping the helper here (beside the other 04-17 intrinsic providers)
/// means `typology_providers.dart` only has to import + call — the
/// binding semantics live next to `intrinsicDimensionsForPosProvider`
/// so future audits find everything in one place.
({
  Map<int, bool> dimensionIntrinsicFlags,
  Map<int, int> lexemeIntrinsicLevels,
}) buildIntrinsicParadigmInputs({
  required List<Dimension> dims,
  required String? intrinsicLevelsJson,
}) {
  return (
    dimensionIntrinsicFlags: {for (final d in dims) d.id: d.intrinsic},
    lexemeIntrinsicLevels: IntrinsicLevelsCodec.decode(intrinsicLevelsJson),
  );
}

IntrinsicBackfillBanner? _decodePendingBanner(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    final dimId = decoded['dimId'] as int?;
    final dimName = decoded['dimName'] as String?;
    final count = decoded['count'] as int?;
    if (dimId == null || dimName == null || count == null) return null;
    return IntrinsicBackfillBanner(
      dimId: dimId,
      dimName: dimName,
      count: count,
    );
  } catch (_) {
    return null;
  }
}
