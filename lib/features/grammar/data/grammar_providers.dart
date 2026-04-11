import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import '../domain/marker.dart';
import 'dimension_templates.dart';
import 'grammar_dao.dart';
import 'inflectional_rule_pos_dao.dart';
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
