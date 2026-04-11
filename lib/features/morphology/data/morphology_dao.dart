import 'package:drift/drift.dart';

import '../../../db/app_database.dart';
import '../../grammar/domain/rule_kind.dart';

part 'morphology_dao.g.dart';

/// Drift DAO for CRUD operations on [MorphologicalRules],
/// [MorphologicalRuleExceptions], and [PartsOfSpeech] tables.
///
/// Obtain via `currentDatabase.morphologyDao` or the Riverpod
/// [morphologyDaoProvider] which derives it from the active project database.
@DriftAccessor(tables: [MorphologicalRules, MorphologicalRuleExceptions, PartsOfSpeech])
class MorphologyDao extends DatabaseAccessor<AppDatabase>
    with _$MorphologyDaoMixin {
  MorphologyDao(super.db);

  // ---------------------------------------------------------------------------
  // Rules — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all morphological rules, ordered by [ordering] ascending.
  Stream<List<MorphologicalRule>> watchAllRules() =>
      (select(morphologicalRules)
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  /// Watches morphological rules of a given [kind] (inflectional or
  /// derivational). Filters on the `kind` column added in schema v8.
  ///
  /// Ordered by [ordering] ascending so consumers see the same priority
  /// sequence the overall rules list uses.
  Stream<List<MorphologicalRule>> watchRulesByKind(RuleKind kind) {
    return (select(morphologicalRules)
          ..where((t) => t.kind.equals(kind.dbString))
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .watch();
  }

  /// Watches inflectional rules that apply to the given [posId].
  ///
  /// A rule applies to [posId] iff `kind='inflectional'` AND either
  /// `featureBindings.pos` is empty (applies to all POS) or contains
  /// [posId]. Filtering on `featureBindings` is done in Dart because the
  /// column is a JSON [TypeConverter] and the subset check is not expressible
  /// in SQL.
  Stream<List<MorphologicalRule>> watchInflectionalRulesForPos(int posId) {
    return watchRulesByKind(RuleKind.inflectional).map((rules) {
      return rules.where((r) {
        final pos = r.featureBindings.pos;
        return pos.isEmpty || pos.contains(posId);
      }).toList();
    });
  }

  /// Inserts a rule and guarantees its `kind` column matches [kind].
  ///
  /// Any `kind` value in [companion] is overridden — this method is the
  /// canonical entry point for callers that know which kind they're writing.
  Future<int> insertRuleWithKind(
    MorphologicalRulesCompanion companion,
    RuleKind kind,
  ) {
    return into(morphologicalRules)
        .insert(companion.copyWith(kind: Value(kind.dbString)));
  }

  // ---------------------------------------------------------------------------
  // Rules — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new morphological rule and returns its generated row ID.
  Future<int> insertRule(MorphologicalRulesCompanion c) =>
      into(morphologicalRules).insert(c);

  /// Replaces all fields of an existing morphological rule row.
  Future<bool> updateRule(MorphologicalRule r) =>
      update(morphologicalRules).replace(r);

  /// Deletes the morphological rule with the given [id].
  Future<int> deleteRule(int id) =>
      (delete(morphologicalRules)..where((t) => t.id.equals(id))).go();

  /// Swaps the [ordering] values of two rules so their display positions exchange.
  ///
  /// Handles the degenerate case where both rules have the same ordering value
  /// (e.g. both 0) by assigning distinct values before swapping.
  Future<void> swapOrdering(int ruleIdA, int ruleIdB) async {
    await transaction(() async {
      final a = await (select(morphologicalRules)
            ..where((t) => t.id.equals(ruleIdA)))
          .getSingle();
      final b = await (select(morphologicalRules)
            ..where((t) => t.id.equals(ruleIdB)))
          .getSingle();

      var ordA = a.ordering;
      var ordB = b.ordering;

      // If both have the same ordering, assign distinct values first.
      if (ordA == ordB) {
        ordB = ordA + 1;
        await (update(morphologicalRules)..where((t) => t.id.equals(ruleIdB)))
            .write(MorphologicalRulesCompanion(ordering: Value(ordB)));
      }

      await (update(morphologicalRules)..where((t) => t.id.equals(ruleIdA)))
          .write(MorphologicalRulesCompanion(ordering: Value(ordB)));
      await (update(morphologicalRules)..where((t) => t.id.equals(ruleIdB)))
          .write(MorphologicalRulesCompanion(ordering: Value(ordA)));
    });
  }

  /// Assigns sequential ordering values to all rules that share duplicate ordering.
  ///
  /// Call once on rules page load to fix existing rules that all have ordering=0.
  Future<void> fixDuplicateOrdering() async {
    final rules = await (select(morphologicalRules)
          ..orderBy([(t) => OrderingTerm.asc(t.ordering), (t) => OrderingTerm.asc(t.id)]))
        .get();
    if (rules.length <= 1) return;

    // Check if any duplicates exist
    final orderings = rules.map((r) => r.ordering).toSet();
    if (orderings.length == rules.length) return; // all unique

    await transaction(() async {
      for (var i = 0; i < rules.length; i++) {
        await (update(morphologicalRules)..where((t) => t.id.equals(rules[i].id)))
            .write(MorphologicalRulesCompanion(ordering: Value(i)));
      }
    });
  }

  /// Returns the next ordering value (max + 1) for inserting a new rule at the end.
  Future<int> nextOrdering() async {
    final result = await customSelect(
      'SELECT COALESCE(MAX(ordering), -1) + 1 AS next_ord FROM morphological_rules',
    ).getSingle();
    return result.read<int>('next_ord');
  }

  // ---------------------------------------------------------------------------
  // Exceptions — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches exceptions associated with a specific [ruleId].
  Stream<List<MorphologicalRuleException>> watchExceptionsForRule(int ruleId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.ruleId.equals(ruleId)))
          .watch();

  /// Watches exceptions associated with a specific [lexemeId].
  Stream<List<MorphologicalRuleException>> watchExceptionsForLexeme(
          int lexemeId) =>
      (select(morphologicalRuleExceptions)
            ..where((t) => t.lexemeId.equals(lexemeId)))
          .watch();

  // ---------------------------------------------------------------------------
  // Exceptions — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new morphological rule exception and returns its generated row ID.
  Future<int> insertException(MorphologicalRuleExceptionsCompanion c) =>
      into(morphologicalRuleExceptions).insert(c);

  /// Deletes the morphological rule exception with the given [id].
  Future<int> deleteException(int id) =>
      (delete(morphologicalRuleExceptions)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Parts of Speech — reactive queries
  // ---------------------------------------------------------------------------

  /// Watches all parts of speech, ordered by name ascending.
  Stream<List<PartsOfSpeechData>> watchAllPos() =>
      (select(partsOfSpeech)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  // ---------------------------------------------------------------------------
  // Parts of Speech — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new part of speech and returns its generated row ID.
  Future<int> insertPos(PartsOfSpeechCompanion c) =>
      into(partsOfSpeech).insert(c);

  /// Replaces all fields of an existing part of speech row.
  Future<bool> updatePos(PartsOfSpeechData p) => update(partsOfSpeech).replace(p);

  /// Deletes the part of speech with the given [id].
  Future<int> deletePos(int id) =>
      (delete(partsOfSpeech)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // Stale exception detection
  // ---------------------------------------------------------------------------

  /// Returns exceptions for [ruleId] whose [ruleSourceSnapshot] no longer
  /// matches [currentSource] — i.e. the rule was edited after the exception
  /// was created and may need review.
  Future<List<MorphologicalRuleException>> findStaleExceptions(
      int ruleId, String currentSource) async {
    final all = await (select(morphologicalRuleExceptions)
          ..where((t) => t.ruleId.equals(ruleId)))
        .get();
    return all
        .where((e) => e.ruleSourceSnapshot != currentSource)
        .toList();
  }
}
