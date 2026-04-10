// lib/features/phonology/data/allophone_providers.dart
//
// Reactive computation of allophone realizations for every phoneme in the
// current project's inventory. See Phase 3.2 RESEARCH F-6 for the provider
// topology rationale (single Map provider vs. family keyed by symbol).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../domain/allophone_computer.dart';
import 'phoneme_providers.dart';
import 'phonotactic_providers.dart';

/// Maps each phoneme symbol in the current project to its computed allophone
/// realizations. Recomputes automatically whenever the rewrite rule list,
/// the phoneme inventory, or the natural class definitions change.
///
/// Phonemes with no matching rules are OMITTED from the map (D-18 empty
/// state — consumers render nothing for a missing key). This keeps the map
/// small and lets the UI use a simple `map[symbol] ?? const []` pattern.
///
/// Performance envelope: ~30-100 phonemes * ~10-50 rules ~= a few thousand
/// comparisons per recomputation. Negligible even on cold start. See F-6.
/// `parsedRewriteRulesProvider` only emits on DB commit (rule save), not per
/// keystroke, so no debounce is needed (Pitfall 3 verified in threat model).
///
/// Convention: plain `Provider<Map<...>>` (not `@riverpod` codegen) to match
/// the existing style for Drift-type-adjacent providers (see STATE.md note
/// on riverpod_generator 3.x + Drift type traversal).
final allophoneMapProvider =
    Provider<Map<String, List<AllophoneRealization>>>((ref) {
  final rules = ref.watch(parsedRewriteRulesProvider);
  final inventory = ref.watch(phonemeInventoryProvider);
  final phonemesAsync = ref.watch(allPhonemesProvider);
  final phonemes = phonemesAsync.when(
    data: (v) => v,
    loading: () => <Phoneme>[],
    error: (_, _) => <Phoneme>[],
  );

  if (rules.isEmpty || phonemes.isEmpty) {
    return const <String, List<AllophoneRealization>>{};
  }

  final resolver = NaturalClassResolver(inventory);
  final result = <String, List<AllophoneRealization>>{};

  for (final p in phonemes) {
    final realizations = computeAllophones(p.symbol, rules, resolver);
    if (realizations.isNotEmpty) {
      result[p.symbol] = realizations;
    }
  }

  return result;
});
