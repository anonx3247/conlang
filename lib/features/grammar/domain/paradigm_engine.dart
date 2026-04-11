import '../../morphology/domain/morphology_dsl.dart';
import '../../morphology/domain/morphology_engine.dart';
import '../../phonology/domain/phonotactic_dsl.dart'
    show PhonologicalRewriteRule;
import '../../phonology/domain/word_generator.dart'
    show PhonemeInventory, WordGenerator;
import 'inflectional_rule.dart';
import 'paradigm_cell.dart';

/// The feature set identifying one paradigm cell.
/// Keys are dimension ids; values are level ids within that dimension.
typedef FeatureSet = Map<int, int>;

/// Compute a single paradigm cell using the feature-consumption algorithm
/// (Phase 4 CONTEXT.md D-10, D-11, D-12, D-13 + research A3).
///
/// Algorithm (strict most-specific with intra-specificity fall-through — A3):
///
///   1. Pre-filter: drop any rule that is inactive or has empty bindings
///      (unbound = derivational by definition — D-13 says unbound never
///      fires on inflectional paths).
///   2. While `remaining` feature set is non-empty:
///      a. Collect candidates whose `bindings.dims` is a (non-empty) subset
///         of `remaining`.
///      b. If candidates is empty:
///           - if chain is empty  -> ParadigmUncovered (no rule ever fired)
///           - if chain non-empty -> ParadigmFilled(working, chain) (partial)
///      c. Find the max specificity among candidates and isolate the top
///         group (all candidates with that specificity).
///      d. If the top group contains 2+ rules whose binding maps are
///         IDENTICAL, return ParadigmAmbiguous — the user must resolve the
///         conflict manually (D-12). Two rules at the same specificity with
///         DIFFERENT binding maps are NOT ambiguous here: they target
///         different dims of the cell and can both fire in sequence.
///      e. Try the top-group candidates in list order:
///           parseMorphDsl(source) -> engine.applyRule(rule, working, inv)
///         First MorphSuccess wins (intra-specificity fall-through).
///      f. If ALL top-group candidates fail (MorphNoMatch or invalid DSL)
///         the engine is STRICT: do NOT fall through to lower specificity.
///           - if chain empty     -> ParadigmUncovered(failureReason)
///           - if chain non-empty -> ParadigmFilled(working, chain) (partial)
///      g. On success, update `working` form, append winner to chain, and
///         remove the winner's bound dims from `remaining`. Loop.
///   3. When `remaining` is empty, return ParadigmFilled(working, chain).
ParadigmCell computeParadigmCell({
  required String root,
  required FeatureSet target,
  required List<InflectionalRule> rules,
  required PhonemeInventory inventory,
  List<PhonologicalRewriteRule> rewriteRules = const [],
  MorphologyEngine engine = const MorphologyEngine(),
}) {
  // D-13: only active inflectional rules are eligible. Derivational rules
  // have empty dims, which also means `isInflectional == false`, so the
  // pre-filter covers both "unbound never fires" and "skip derivational".
  final active = rules
      .where((r) => r.isActive && r.bindings.isInflectional)
      .toList();

  var working = root;
  final remaining = Map<int, int>.from(target);
  final chain = <InflectionalRule>[];

  while (remaining.isNotEmpty) {
    final candidates =
        active.where((r) => _isSubset(r.bindings.dims, remaining)).toList();

    if (candidates.isEmpty) {
      if (chain.isEmpty) {
        return const ParadigmUncovered(
          'No inflectional rule binds the requested feature set.',
        );
      }
      return ParadigmFilled(form: working, ruleChain: chain);
    }

    // Sort by specificity desc and isolate the top group.
    candidates.sort((a, b) => b.specificity.compareTo(a.specificity));
    final maxSpec = candidates.first.specificity;
    final topGroup =
        candidates.where((r) => r.specificity == maxSpec).toList();

    // Identical-binding ambiguity: if any pair in the top group has the
    // same binding map, surface as ParadigmAmbiguous so the user can pick
    // one explicitly (D-12). Identical bindings are the ONLY tie that
    // matters — different-binding same-specificity rules are distinct
    // candidates that can be tried in sequence.
    final identicalGroup = _identicalBindingGroup(topGroup);
    if (identicalGroup.length > 1) {
      return ParadigmAmbiguous(identicalGroup);
    }

    // Intra-specificity fall-through: try each top-group candidate in order;
    // the first one whose DSL condition succeeds on the working form wins.
    InflectionalRule? winner;
    String? winnerForm;
    String? failureReason;
    for (final candidate in topGroup) {
      final parsed = parseMorphDsl(
        candidate.source,
        id: candidate.id,
        name: candidate.name,
      );
      if (!parsed.isValid || parsed.rule == null) {
        failureReason ??=
            'Rule "${candidate.name}" has invalid DSL: ${parsed.error ?? 'parse error'}';
        continue;
      }
      final result = engine.applyRule(parsed.rule!, working, inventory);
      switch (result) {
        case MorphSuccess(:final form):
          winner = candidate;
          winnerForm = form;
          break;
        case MorphNoMatch(:final reason):
          failureReason ??=
              'Rule "${candidate.name}" did not match: $reason';
      }
      if (winner != null) break;
    }

    if (winner == null) {
      // Strict most-specific: do NOT fall through to lower specificity.
      if (chain.isEmpty) {
        return ParadigmUncovered(
          failureReason ?? 'All candidate rules failed.',
        );
      }
      return ParadigmFilled(form: working, ruleChain: chain);
    }

    // Apply winner and advance.
    working = winnerForm!;
    chain.add(winner);
    for (final dimId in winner.bindings.dims.keys) {
      remaining.remove(dimId);
    }
  }

  // G-08: after the inflectional chain completes, run the phonology
  // rewrite pipeline ONCE on the final form. D-29 requires paradigm cells
  // to reflect the same phonological surface as root words — rewrite rules
  // applied to roots must also apply after inflectional affixation. The
  // rewrite is only invoked for the ParadigmFilled success path; the
  // ParadigmUncovered and ParadigmAmbiguous returns earlier in this
  // function deliberately skip it.
  final finalForm = rewriteRules.isEmpty
      ? working
      : WordGenerator().applyRewriteRules(
          word: working,
          rules: rewriteRules,
          inventory: inventory,
        );

  return ParadigmFilled(form: finalForm, ruleChain: chain);
}

/// True iff every entry in [sub] is present in [sup] with the same value.
/// Empty [sub] returns false — unbound rules never fire (D-13). This also
/// guarantees each iteration of the main loop consumes at least one dim
/// from `remaining`, so the loop terminates in bounded steps.
bool _isSubset(Map<int, int> sub, Map<int, int> sup) {
  if (sub.isEmpty) return false;
  for (final entry in sub.entries) {
    if (sup[entry.key] != entry.value) return false;
  }
  return true;
}

/// Returns the largest group of rules in [topGroup] that share an identical
/// binding map. If no two rules share bindings, returns a single-element
/// list (the first element). Callers use `length > 1` to detect ambiguity.
List<InflectionalRule> _identicalBindingGroup(
  List<InflectionalRule> topGroup,
) {
  if (topGroup.length <= 1) return topGroup;
  final byKey = <String, List<InflectionalRule>>{};
  for (final rule in topGroup) {
    final key = _bindingKey(rule.bindings.dims);
    byKey.putIfAbsent(key, () => []).add(rule);
  }
  // Return the largest group. If no ties, returns a length-1 list.
  return byKey.values
      .reduce((a, b) => a.length >= b.length ? a : b);
}

String _bindingKey(Map<int, int> dims) {
  final entries = dims.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}
