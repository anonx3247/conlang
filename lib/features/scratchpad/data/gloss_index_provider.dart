import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../grammar/data/grammar_providers.dart';
import '../../grammar/data/typology_providers.dart';
import '../../grammar/domain/dimension_level.dart';
import '../../grammar/domain/paradigm_cell.dart';
import '../../grammar/domain/paradigm_engine.dart' show FeatureSet;
import '../../grammar/domain/pos_resolver.dart';
import '../../lexicon/data/lexeme_providers.dart';
import '../../morphology/data/morphology_providers.dart';
import '../../phonology/data/romanization_providers.dart';
import '../../../db/app_database.dart';
import '../domain/gloss_match.dart';

/// Pre-computed index mapping every known surface form (IPA and romanization)
/// to its [GlossMatch] decomposition. The scratchpad parser does O(1) lookups
/// against this map instead of brute-force paradigm computation per token.
///
/// Rebuilds reactively when the lexicon, grammar rules, or phonology changes.
///
/// Lookup keys include both IPA and romanization for each form, so users can
/// type in either notation (per Pitfall 4 from RESEARCH.md).
final glossIndexProvider = Provider<Map<String, GlossMatch>>((ref) {
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  if (allLexemes.isEmpty) return const {};

  final romanize = ref.watch(romanizeProvider);
  final posListAsync = ref.watch(posListProvider);
  final posList = posListAsync.asData?.value ?? const <PartsOfSpeechData>[];

  final index = <String, GlossMatch>{};

  for (final lex in allLexemes) {
    // Step 1: exact root/base form
    final exactMatch = ExactLexemeMatch(lexeme: lex);
    index.putIfAbsent(lex.ipa, () => exactMatch);
    if (lex.romanization != null && lex.romanization!.isNotEmpty) {
      index.putIfAbsent(lex.romanization!, () => exactMatch);
    }

    // Step 2: inflected forms via paradigm engine
    final paradigm = ref.watch(computedInflectedParadigmProvider(lex.id));
    if (paradigm.isNotEmpty) {
      // Resolve POS to get dimensions for Leipzig labels
      final pos = posForLexeme(lex, posList);
      final dims = pos != null
          ? (ref.watch(dimensionsForPosProvider(pos.id)).asData?.value ??
              const <Dimension>[])
          : const <Dimension>[];

      for (final entry in paradigm.entries) {
        if (entry.cell
            case ParadigmFilled(
              :final form,
              :final phonemic,
              :final ruleChain,
            )) {
          // Build Leipzig abbreviation list from featureSet + dimensions
          final levelAbbrs = _buildLevelAbbrs(entry.featureSet, dims);

          final inflMatch = InflectedFormMatch(
            lexeme: lex,
            ruleChain: ruleChain,
            levelAbbrs: levelAbbrs,
          );

          // Key on phonetic surface form (post-rewrite)
          index.putIfAbsent(form, () => inflMatch);
          // Key on romanized form of the phonemic (pre-rewrite) output
          final rom = romanize(phonemic);
          if (rom != phonemic) {
            index.putIfAbsent(rom, () => inflMatch);
          }
          // Also key on the raw phonemic form
          if (phonemic != form) {
            index.putIfAbsent(phonemic, () => inflMatch);
          }
        }
      }
    }

    // Step 3: derived forms via morphology engine
    final derived = ref.watch(computedDerivedFormsProvider(lex.id));
    for (final d in derived) {
      final derMatch = DerivedFormMatch(
        rootLexeme: lex,
        ruleName: d.ruleName,
        derivedIpa: d.derivedIpa,
      );
      index.putIfAbsent(d.derivedIpa, () => derMatch);
      // Also add romanized key for derived forms
      final rom = romanize(d.derivedIpa);
      if (rom != d.derivedIpa) {
        index.putIfAbsent(rom, () => derMatch);
      }
    }
  }

  return index;
});

/// Builds a list of Leipzig abbreviations from a feature set by resolving
/// each dimension ID -> level ID -> DimensionLevel.abbr.
List<String> _buildLevelAbbrs(
  FeatureSet featureSet,
  List<Dimension> dims,
) {
  final abbrs = <String>[];
  for (final entry in featureSet.entries) {
    final dimId = entry.key;
    final levelId = entry.value;
    // Find the dimension
    final dim = dims.where((d) => d.id == dimId).firstOrNull;
    if (dim == null) continue;
    // Decode levels JSON to find the level's abbreviation
    final levels = decodeLevelsJson(dim.levelsJson);
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    if (level != null) {
      abbrs.add(level.abbr.toUpperCase());
    }
  }
  return abbrs;
}
