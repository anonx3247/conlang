import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../grammar/data/grammar_providers.dart';
import '../../grammar/domain/binding_translator.dart';
import '../../grammar/domain/inflectional_rule.dart';
import '../../grammar/domain/rule_kind.dart';
import '../../project/data/project_providers.dart';
import 'morphology_dao.dart';

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// Provides the [MorphologyDao] for the current project database.
///
/// Returns null when no project is open.
///
/// Uses a plain [Provider] (not riverpod_generator) to avoid build_runner
/// type-traversal issues with Drift-generated types.
final morphologyDaoProvider = Provider<MorphologyDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return null;
  return db.morphologyDao;
});

// ---------------------------------------------------------------------------
// Rule providers
// ---------------------------------------------------------------------------

/// Streams all morphological rules for the current project, ordered by
/// [MorphologicalRule.ordering] ascending.
///
/// Emits an empty list when no project is open.
final morphologicalRuleListProvider =
    StreamProvider<List<MorphologicalRule>>((ref) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllRules();
});

// ---------------------------------------------------------------------------
// Parts of Speech providers
// ---------------------------------------------------------------------------

/// Streams all parts of speech for the current project, ordered by name.
///
/// Emits an empty list when no project is open.
final posListProvider = StreamProvider<List<PartsOfSpeechData>>((ref) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllPos();
});

// ---------------------------------------------------------------------------
// Exception providers
// ---------------------------------------------------------------------------

/// Streams exceptions for a specific morphological rule identified by [ruleId].
///
/// Emits an empty list when no project is open.
final morphRuleExceptionsProvider =
    StreamProvider.family<List<MorphologicalRuleException>, int>(
        (ref, ruleId) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchExceptionsForRule(ruleId);
});

// ---------------------------------------------------------------------------
// Kind-aware rule providers (Phase 4)
// ---------------------------------------------------------------------------

/// Streams morphological rules filtered by [RuleKind] (inflectional or
/// derivational). Backed by `MorphologyDao.watchRulesByKind`.
///
/// Emits an empty list when no project is open.
final rulesByKindProvider =
    StreamProvider.family<List<MorphologicalRule>, RuleKind>((ref, kind) {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) return Stream.value(const []);
  return dao.watchRulesByKind(kind);
});

/// Streams ACTIVE inflectional rules that apply to the given POS, converted
/// to [InflectionalRule] view-models ready for the paradigm engine.
///
/// Inactive rules are filtered out here — the paradigm engine should never
/// evaluate them.
///
/// Multi-POS fix (G-67): rule bindings stored as `Map<dimId, levelId>` are
/// POS-specific (each POS has its own Dimensions rows). When a rule is
/// attached to multiple POS via the InflectionalRulePOS junction, its
/// bindings only reference the AUTHORING POS's dim/level IDs — matched
/// against any other POS's paradigm cells, the integer keys never align.
/// We remap bindings to [posId]'s ID space by looking up dim/level NAMES.
/// If the target POS lacks a dim with the authoring name, or the level
/// doesn't exist under that name, the rule is dropped for this POS (it's
/// structurally unreachable there).
///
/// Emits an empty list when no project is open.
final inflectionalRulesForPosProvider =
    StreamProvider.family<List<InflectionalRule>, int>((ref, posId) async* {
  final dao = ref.watch(morphologyDaoProvider);
  if (dao == null) {
    yield const [];
    return;
  }

  await for (final rows in dao.watchInflectionalRulesForPos(posId)) {
    final active = rows.where((r) => r.isActive).toList();

    // Collect every POS id whose dims we'll need to resolve for translation:
    // the query POS plus every rule's authoring POS.
    final neededPosIds = <int>{posId};
    for (final r in active) {
      final auth = authPosIdForRule(
        featureBindingsPos: r.featureBindings.pos,
        legacyInputPosId: r.inputPosId,
      );
      if (auth != null) neededPosIds.add(auth);
    }

    // Snapshot each needed POS's current dim list. Using `.future` on the
    // family member yields the latest emitted value without re-subscribing
    // this listener to every dimension stream — the rule stream itself
    // rebuilds whenever the DAO re-emits, at which point we re-snapshot.
    final posDims = <int, List<Dimension>>{};
    for (final pid in neededPosIds) {
      try {
        posDims[pid] = await ref.read(dimensionsForPosProvider(pid).future);
      } catch (_) {
        posDims[pid] = const <Dimension>[];
      }
    }

    final queryDims = posDims[posId] ?? const <Dimension>[];
    final result = <InflectionalRule>[];
    for (final r in active) {
      final auth = authPosIdForRule(
        featureBindingsPos: r.featureBindings.pos,
        legacyInputPosId: r.inputPosId,
      );
      if (auth == null || auth == posId) {
        result.add(InflectionalRule.fromDbRow(r));
        continue;
      }
      final authDims = posDims[auth] ?? const <Dimension>[];
      final translated = translateBindingsByName(
        original: r.featureBindings,
        authPosDims: authDims,
        queryPosDims: queryDims,
      );
      if (translated == null) {
        // Rule is structurally unreachable on this POS — drop it.
        continue;
      }
      result.add(InflectionalRule(
        id: r.id,
        name: r.name,
        source: r.source,
        isActive: r.isActive,
        bindings: translated,
      ));
    }
    yield result;
  }
});
