import 'package:flutter_riverpod/flutter_riverpod.dart';

// Hide the Drift-generated `MorphologicalRule` row class — we refer to
// the row via `db.select(db.morphologicalRules).get()` which returns
// that generated class unqualified anyway, but hiding it here keeps the
// imports explicit about which `MorphologicalRule` we mean (we don't use
// the domain DSL type in this file).
import '../../../db/app_database.dart';
import '../../grammar/domain/pos_resolver.dart';
import '../../grammar/domain/rule_kind.dart';
import '../../project/data/project_providers.dart';

/// D-59: reconcile service that materializes auto-apply derivational
/// rules into promoted [Lexeme] rows.
///
/// Walks every derivational rule where `autoApply = true` and creates a
/// promoted Lexeme row for every matching-POS parent with a non-null
/// meaning, using the exact templated gloss
/// `"{parent.meaning} ({rule.name})"` from 04-CONTEXT-GAPS §D-59:
///
///     kama (Noun, meaning "to run") + rule "Actor" autoApply=true
///     -> promoted lexeme with gloss "to run (Actor)"
///
/// Idempotent: running twice yields exactly one row per `(parent, rule)`
/// pair (identified by `derivedFromLexemeId` + `derivedViaRuleId`).
///
/// Intended call sites (plan 04-12 + 04-14):
///   - app startup once the database is open
///   - after rule edits (rule editor save path)
///   - after lexeme meaning edits (when a previously-null meaning lands,
///     Test 3 in `auto_apply_derivation_test.dart` guards this behavior)
///
/// Not a stream — callers trigger [reconcile] explicitly.
class DerivationPromotionService {
  DerivationPromotionService(this._ref);

  final Ref _ref;

  /// Reconcile the Lexemes table against every `autoApply=true`
  /// derivational rule. Returns the number of new rows created.
  ///
  /// Promotes a row iff ALL hold:
  ///   - `rule.kind = 'derivational'`
  ///   - `rule.isActive = true`
  ///   - `rule.autoApply = true`
  ///   - `rule.inputPosId` is non-null
  ///   - parent's POS (via [posForLexeme]) equals `rule.inputPosId`
  ///   - parent's meaning is non-null and non-empty
  ///   - parent is itself a root / non-promoted lexeme (we do NOT
  ///     cascade auto-apply across derivation chains — D-59 scopes this
  ///     to the first layer only)
  ///   - no existing row already has
  ///     `(derivedFromLexemeId = parent, derivedViaRuleId = rule)`
  Future<int> reconcile() async {
    final db = _ref.read(currentDatabaseProvider);
    if (db == null) return 0;

    final rules = await db.select(db.morphologicalRules).get();
    final allLexemes = await db.select(db.lexemes).get();
    final posList = await db.select(db.partsOfSpeech).get();
    final lexemeDao = db.lexemeDao;

    // Build a set of existing (parent, rule) pairs for idempotency.
    final existingPairs = <String>{};
    for (final lx in allLexemes) {
      if (lx.derivedFromLexemeId != null && lx.derivedViaRuleId != null) {
        existingPairs.add('${lx.derivedFromLexemeId}:${lx.derivedViaRuleId}');
      }
    }

    var created = 0;
    for (final rule in rules) {
      if (!rule.isActive) continue;
      if (rule.kind != RuleKind.derivational.dbString) continue;
      if (!rule.autoApply) continue;
      if (rule.inputPosId == null) continue;

      for (final lexeme in allLexemes) {
        // Skip promoted lexemes — auto-apply only fires on the first
        // derivation layer; chaining is out of scope for D-59.
        if (lexeme.derivedViaRuleId != null) continue;

        // Defer when the parent has no meaning (D-59: no "null (Actor)"
        // ghost rows).
        final meaning = lexeme.meaning;
        if (meaning == null || meaning.trim().isEmpty) continue;

        // POS match via the free-text resolver.
        final pos = posForLexeme(lexeme, posList);
        if (pos == null || pos.id != rule.inputPosId) continue;

        // Idempotency guard.
        final key = '${lexeme.id}:${rule.id}';
        if (existingPairs.contains(key)) continue;

        // Exact D-59 template: "{parent.meaning} ({rule.name})".
        final templatedGloss = '$meaning (${rule.name})';

        await lexemeDao.promoteDerivation(
          parentId: lexeme.id,
          ruleId: rule.id,
          gloss: templatedGloss,
        );
        existingPairs.add(key);
        created += 1;
      }
    }
    return created;
  }
}

/// Riverpod entry point for [DerivationPromotionService]. A plain
/// `Provider` so callers can `ref.read(...).reconcile()` without any
/// async boilerplate.
final derivationPromotionServiceProvider =
    Provider<DerivationPromotionService>((ref) {
  return DerivationPromotionService(ref);
});
