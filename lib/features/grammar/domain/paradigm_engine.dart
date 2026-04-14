import '../../../db/app_database.dart' show Lexeme, ConstructionSlot;
import '../../morphology/domain/morphology_dsl.dart';
import '../../morphology/domain/morphology_engine.dart';
import '../../phonology/domain/phonotactic_dsl.dart'
    show PhonologicalRewriteRule;
import '../../phonology/domain/word_generator.dart'
    show PhonemeInventory, WordGenerator;
import 'construction_rule.dart';
import 'inflectional_rule.dart';
import 'marker.dart';
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
  List<MarkerDecl> markers = const [],
  MorphologyEngine engine = const MorphologyEngine(),
  // D-88 — 04-17. When provided, rule candidates whose bindings contain
  // an entry on an intrinsic dim are short-circuit-filtered: the entry
  // must match the lexeme's intrinsicLevelsJson value for the rule to
  // be eligible.
  Map<int, int>? lexemeIntrinsicLevels,
  // D-88 — 04-17. Maps dimId → intrinsic flag. When a dim has
  // intrinsic == true and the rule has a binding on it, the binding
  // acts as a filter, not an axis.
  // Null = legacy callers (backward compat) - intrinsic short-circuit
  // disabled when null.
  Map<int, bool>? dimensionIntrinsicFlags,
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

  // D-88 — 04-17. Intrinsic short-circuit: when flags are provided, a
  // rule whose bindings contain an intrinsic-dim entry must match the
  // lexeme's intrinsicLevelsJson value for that dim to be eligible.
  // Null `lexemeIntrinsicLevels` means "no word-level intrinsic data
  // known" — any rule binding on an intrinsic dim fails the match.
  bool matchesIntrinsicConstraints(InflectionalRule r) {
    if (dimensionIntrinsicFlags == null) return true;
    for (final entry in r.bindings.dims.entries) {
      if (dimensionIntrinsicFlags[entry.key] == true) {
        final lexemeValue = lexemeIntrinsicLevels?[entry.key];
        if (lexemeValue != entry.value) return false;
      }
    }
    return true;
  }

  /// D-45 step 3 fall-back: when the inflectional rule loop would return
  /// ParadigmUncovered because no chain was produced, consult [markers]
  /// instead. A marker whose binding dims are a subset of the ORIGINAL
  /// `target` (not the post-consumption `remaining`, which is identical
  /// here because `chain.isEmpty` implies no consumption occurred) asserts
  /// "no form change at this cell" — the root IS the form, so we return
  /// ParadigmUnmarked. On ties, the highest-specificity marker wins; on
  /// equal specificity, the first marker in list order wins (stable,
  /// deterministic — marker ties are NOT surfaced as ambiguous because
  /// asserting absence is non-contradictory, unlike rule ambiguity D-12).
  ParadigmCell markerOrUncovered(String reason) {
    if (markers.isEmpty) return ParadigmUncovered(reason);
    final matching = markers.where((m) => m.matches(target)).toList();
    if (matching.isEmpty) return ParadigmUncovered(reason);
    matching.sort((a, b) => b.specificity.compareTo(a.specificity));
    return ParadigmUnmarked(root: root, source: matching.first);
  }

  while (remaining.isNotEmpty) {
    // D-88 — 04-17. Two-stage filter: first, intrinsic constraint check
    // (rule's intrinsic-dim bindings must match the lexeme's
    // intrinsicLevelsJson), then subset against the non-intrinsic
    // projection of the binding map. Order is locked: intrinsic FIRST
    // so we never evaluate subset membership against bindings that
    // would have been rejected by the constraint.
    final candidates = active
        .where(matchesIntrinsicConstraints)
        .where((r) => _isSubset(
            _nonIntrinsicBindings(r, dimensionIntrinsicFlags), remaining))
        .toList();

    if (candidates.isEmpty) {
      if (chain.isEmpty) {
        return markerOrUncovered(
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
        return markerOrUncovered(
          failureReason ?? 'All candidate rules failed.',
        );
      }
      return ParadigmFilled(form: working, ruleChain: chain);
    }

    // Apply winner and advance.
    working = winnerForm!;
    chain.add(winner);
    for (final dimId in winner.bindings.dims.keys) {
      // D-88 — 04-17. Intrinsic dims are filters, not axes — they must
      // never be removed from `remaining` because `remaining` only ever
      // contains non-intrinsic entries upstream. Guarding here defends
      // against callers that pass an intrinsic dim in the target map
      // by mistake.
      if (dimensionIntrinsicFlags?[dimId] == true) continue;
      remaining.remove(dimId);
    }
  }

  // G-08: after the inflectional chain completes, run the phonology
  // rewrite pipeline ONCE on the final form. D-29 requires paradigm cells
  // to reflect the same phonological surface as root words ��� rewrite rules
  // applied to roots must also apply after inflectional affixation. The
  // rewrite is only invoked for the ParadigmFilled success path; the
  // ParadigmUncovered and ParadigmAmbiguous returns earlier in this
  // function deliberately skip it.
  //
  // D-112 (plan 04-17): the engine now returns BOTH the raw phonemic
  // (`working`) and the post-rewrite phonetic (`finalForm`). Consumers
  // MUST use `phonemic` for romanize() and `form` for [bracket] display.
  final finalForm = rewriteRules.isEmpty
      ? working
      : WordGenerator().applyRewriteRules(
          word: working,
          rules: rewriteRules,
          inventory: inventory,
        );

  return ParadigmFilled(form: finalForm, ruleChain: chain, phonemic: working);
}

/// D-88 — 04-17. Projects a rule's binding map to the non-intrinsic dims
/// only. When [flags] is null (legacy callers), returns the binding map
/// unchanged. The subset check against `remaining` uses this projection
/// so intrinsic-dim entries act as filters (handled by
/// `matchesIntrinsicConstraints`), not as axes that would require the
/// paradigm cell target to contain them.
Map<int, int> _nonIntrinsicBindings(
  InflectionalRule r,
  Map<int, bool>? flags,
) {
  if (flags == null) return r.bindings.dims;
  return Map.fromEntries(
    r.bindings.dims.entries.where((e) => flags[e.key] != true),
  );
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

// ---------------------------------------------------------------------------
// Phase 10.1 — Construction rule resolution
// ---------------------------------------------------------------------------

/// Resolves a single paradigm cell's construction overlay.
///
/// Called from [generateParadigm] as a post-pass after all inflectional cells
/// are computed. Returns the original [inflectionalResult] if no construction
/// rule matches the [target] feature set.
///
/// D-04: When a construction rule matches AND an inflectional result exists,
/// the construction wraps the inflected form (composition). The inflectional
/// chain fires first; the construction's word slot resolves to the inflected
/// output.
///
/// D-09: Cycle detection via [resolvingStack] — a set of featureSetKeys
/// currently being resolved. If [target] is already in the set, returns
/// [ParadigmUnresolvable] with the cycle path.
///
/// T-10.1-04: [resolvingStack] guarantees O(N) termination where N = number
/// of paradigm cells. Infinite recursion is impossible.
/// T-10.1-05: If a referenced featureSet is absent from the chart, falls
/// through gracefully to the inflectional-only result.
ParadigmCell resolveConstructionCell({
  required String root,
  required FeatureSet target,
  required ParadigmCell inflectionalResult,
  required List<ConstructionRule> constructionRules,
  required List<ConstructionSlot> Function(int constructionId) slotsLookup,
  required List<Lexeme> closedClassWords,
  required Map<String, ParadigmCell> inflectionalChart,
  required Set<String> resolvingStack,
  required Map<String, ParadigmCell> resolvedCache,
  required List<ConstructionRule> allConstructionRules,
  required PhonemeInventory inventory,
  List<PhonologicalRewriteRule> rewriteRules = const [],
}) {
  // Step 1: find the best matching active construction rule.
  final targetKey = _featureSetKey(target);
  final candidates = constructionRules
      .where((r) => r.isActive && _isSubset(r.bindings.dims, target))
      .toList();
  if (candidates.isEmpty) return inflectionalResult;

  // Most-specific rule wins (highest specificity = most binding dims).
  candidates.sort((a, b) => b.specificity.compareTo(a.specificity));
  final winner = candidates.first;

  // Step 2: cycle detection — if this target is already being resolved,
  // return ParadigmUnresolvable.
  if (resolvingStack.contains(targetKey)) {
    return ParadigmUnresolvable(
      cyclePath: _buildCyclePath(resolvingStack, targetKey),
    );
  }

  // Step 3: mark this cell as being resolved.
  resolvingStack.add(targetKey);

  try {
    // Step 4: resolve the word slot form. For CellFormReference, recursively
    // resolve the referenced cell and propagate any cycle it detects.
    final ParadigmCell? cycleResult;
    final String wordIpa;
    final String wordPhonemic;

    switch (winner.formReference) {
      case BaseFormReference():
        // D-04: use the inflectional result's form if available.
        cycleResult = null;
        (wordIpa, wordPhonemic) = switch (inflectionalResult) {
          ParadigmFilled(:final form, :final phonemic) => (form, phonemic),
          ParadigmUnmarked(:final root) => (root, root),
          _ => (root, root),
        };

      case CellFormReference(:final targetFeatureSet):
        final refKey = _featureSetKey(targetFeatureSet);

        // Check resolved cache first (already computed construction cells).
        if (resolvedCache.containsKey(refKey)) {
          final cached = resolvedCache[refKey]!;
          if (cached is ParadigmUnresolvable) {
            cycleResult = ParadigmUnresolvable(cyclePath: cached.cyclePath);
            wordIpa = root;
            wordPhonemic = root;
          } else {
            cycleResult = null;
            (wordIpa, wordPhonemic) = _cellToWordForm(cached, root);
          }
        } else {
          // Check if the referenced target has a construction rule.
          final refCandidates = allConstructionRules
              .where((r) =>
                  r.isActive && _isSubset(r.bindings.dims, targetFeatureSet))
              .toList();

          if (refCandidates.isNotEmpty) {
            // Recursively resolve — threads the same resolvingStack for D-09.
            final refInflectional =
                inflectionalChart[refKey] ?? const ParadigmUncovered();
            final resolved = resolveConstructionCell(
              root: root,
              target: targetFeatureSet,
              inflectionalResult: refInflectional,
              constructionRules: allConstructionRules,
              slotsLookup: slotsLookup,
              closedClassWords: closedClassWords,
              inflectionalChart: inflectionalChart,
              resolvingStack: resolvingStack,
              resolvedCache: resolvedCache,
              allConstructionRules: allConstructionRules,
              inventory: inventory,
              rewriteRules: rewriteRules,
            );
            if (resolved is ParadigmUnresolvable) {
              // Cycle detected in the referenced cell — propagate.
              cycleResult = resolved;
              wordIpa = root;
              wordPhonemic = root;
            } else {
              cycleResult = null;
              (wordIpa, wordPhonemic) = _cellToWordForm(resolved, root);
            }
          } else {
            // No construction rule for referenced cell — use inflectional output.
            final inflRef = inflectionalChart[refKey];
            cycleResult = null;
            (wordIpa, wordPhonemic) = inflRef != null
                ? _cellToWordForm(inflRef, root)
                : (root, root); // T-10.1-05: missing cell → fall through.
          }
        }
    }

    // If a cycle was detected during word slot resolution, return it now.
    if (cycleResult != null) {
      resolvedCache[targetKey] = cycleResult;
      return cycleResult;
    }

    // Step 5: load slots for the winning construction and assemble tokens.
    final slots = slotsLookup(winner.constructionId);
    final tokens = _assembleTokens(
      slots: slots,
      wordSlotId: winner.wordSlotId,
      wordIpa: wordIpa,
      wordPhonemic: wordPhonemic,
      closedClassWords: closedClassWords,
    );

    // Step 6: use the rule name as the construction identifier.
    final constructionName = winner.name;

    final result = ParadigmConstructionFilled(
      tokens: tokens,
      constructionName: constructionName,
      ruleId: winner.id,
    );
    resolvedCache[targetKey] = result;
    return result;
  } finally {
    resolvingStack.remove(targetKey);
  }
}

/// Extracts (ipa, phonemic) from a resolved [ParadigmCell] for use as
/// a WordSlotToken's form. Falls back to [root] for unresolvable cells.
(String, String) _cellToWordForm(ParadigmCell cell, String root) =>
    switch (cell) {
      ParadigmFilled(:final form, :final phonemic) => (form, phonemic),
      ParadigmConstructionFilled(:final form, :final phonemic) =>
        (form, phonemic),
      ParadigmUnmarked(:final root) => (root, root),
      _ => (root, root),
    };

/// Assembles [ConstructionToken] list from [slots].
///
/// For each slot:
/// - If `slot.id == wordSlotId`: create [WordSlotToken] with [wordIpa]/[wordPhonemic].
/// - If `slot.slotType == 'gloss_tag'`: look up [closedClassWords] by glossTag
///   (case-insensitive) → [ParticleToken]. If no match, skip the slot rather
///   than crashing (T-10.1-05 graceful handling).
/// - Other slot types: skip (not yet handled in this phase).
List<ConstructionToken> _assembleTokens({
  required List<ConstructionSlot> slots,
  required int wordSlotId,
  required String wordIpa,
  required String wordPhonemic,
  required List<Lexeme> closedClassWords,
}) {
  // Sort slots by ordering to ensure correct assembly order.
  final ordered = [...slots]..sort((a, b) => a.ordering.compareTo(b.ordering));
  final tokens = <ConstructionToken>[];

  for (final slot in ordered) {
    if (slot.id == wordSlotId) {
      tokens.add(WordSlotToken(ipa: wordIpa, phonemic: wordPhonemic));
    } else if (slot.slotType == 'gloss_tag') {
      final match = closedClassWords.where(
        (l) => l.glossTag?.toUpperCase() == slot.slotValue.toUpperCase(),
      ).firstOrNull;
      if (match != null) {
        tokens.add(ParticleToken(ipa: match.ipa, romanization: match.romanization));
      }
      // If no match: slot is silently skipped (T-10.1-05 — no crash).
    }
    // pos slots that are NOT the word slot are skipped in this phase.
  }

  return tokens;
}

/// Canonical string key for a [FeatureSet]. Mirrors [featureSetKey] in
/// typology_providers.dart but defined here to keep paradigm_engine.dart
/// self-contained (no circular imports).
String _featureSetKey(FeatureSet featureSet) {
  final entries = featureSet.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}

/// Builds a human-readable cycle path string for [ParadigmUnresolvable].
///
/// Format: `"Cell {key1} → Cell {key2} → ... → Cell {newKey}"`.
String _buildCyclePath(Set<String> stack, String newKey) {
  final parts = [...stack, newKey].map((k) => 'Cell $k').toList();
  return parts.join(' → ');
}
