// lib/features/phonology/domain/allophone_computer.dart
//
// Pure computation of allophone realizations for a phoneme, derived from
// the project's existing rewrite rules. See Phase 3.2 CONTEXT D-10 through
// D-13 and RESEARCH F-4/F-5.
//
// This module does NOT apply rewrite rules (no SPE engine in v1). It only
// lists the RHS of rules that target a given phoneme, as a descriptive
// catalog of its known realizations.

import '../../morphology/domain/morphology_engine.dart' show resolvePhonemeClass;
import 'phonotactic_dsl.dart';
import 'word_generator.dart' show PhonemeInventory;

/// A single realization of an underlying phoneme, derived from one rewrite rule.
///
/// Equality and hashCode are based on [output] alone — this enables
/// deduplication via `Set<AllophoneRealization>` keyed by surface form, per D-12.
class AllophoneRealization {
  const AllophoneRealization({
    required this.output,
    required this.ruleSource,
    required this.isFeatureBundle,
  });

  /// The RHS of the rewrite rule, verbatim. Examples: 'ʃ', '[+nasal]', 'b'.
  final String output;

  /// The full original DSL string of the source rule, for tooltip display
  /// in the UI (e.g. 's -> ʃ / _i'). Supplementary info per D-17.
  final String ruleSource;

  /// True if [output] looks like a feature-bundle descriptor ('[...]').
  /// Plan 04 uses this flag to style bundle outputs differently (italic or
  /// dimmer) since they are not concrete segments per D-13.
  final bool isFeatureBundle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllophoneRealization && other.output == output);

  @override
  int get hashCode => output.hashCode;
}

/// Thin wrapper around [resolvePhonemeClass] so [computeAllophones] has an
/// ergonomic, injectable resolver handle. Keeps the pure function free of
/// direct dependencies on Plan 02's top-level function while still sharing
/// the alias + default + user-class precedence chain.
class NaturalClassResolver {
  const NaturalClassResolver(this.inventory);

  final PhonemeInventory inventory;

  /// Delegates to the shared resolver (Plan 02 — handles aliases, defaults,
  /// and user classes with correct precedence).
  List<String> resolve(String classRef) =>
      resolvePhonemeClass(classRef, inventory);
}

/// Walks [rules] and returns deduplicated realizations of [phonemeSymbol],
/// preserving the iteration order of the input list.
///
/// Matching cases (RESEARCH F-5):
///   * Case A — single-segment literal input equals [phonemeSymbol] → match
///   * Case B — single-segment class-reference input whose resolved class
///     contains [phonemeSymbol] → match
///   * Case C — multi-segment (cluster) input → SKIP. A cluster rule like
///     `st -> ʃt` is not naturally an allophone of /s/ or /t/ individually;
///     listing it would produce noisy output (A2).
///
/// Additional filters:
///   * Identity rules (output equals the phoneme symbol) are skipped per
///     D-12 (the elsewhere case is implicit and not shown per D-18).
///   * Rules with no class reference on a non-literal slot are skipped
///     defensively — the parser rejects them but we guard anyway.
///   * Duplicate outputs are deduplicated by surface form (D-12).
///
/// Feature-bundle outputs (e.g. '[+nasal]') are preserved verbatim and
/// flagged with [AllophoneRealization.isFeatureBundle]=true per D-13.
List<AllophoneRealization> computeAllophones(
  String phonemeSymbol,
  List<PhonologicalRewriteRule> rules,
  NaturalClassResolver resolver,
) {
  final out = <AllophoneRealization>[];
  final seen = <String>{};

  for (final r in rules) {
    // Case C — cluster skip. Any multi-slot LHS is filtered out before we
    // even look at the contents.
    if (r.input.length != 1) continue;

    final slot = r.input[0];

    final bool matches;
    if (slot.isLiteral) {
      matches = slot.literalPhoneme == phonemeSymbol;
    } else {
      final classRef = slot.classReference;
      if (classRef == null) continue; // defensive — Slot invariant guards this
      final members = resolver.resolve(classRef);
      matches = members.contains(phonemeSymbol);
    }
    if (!matches) continue;

    // Identity skip (D-12) — elsewhere case is implicit.
    if (r.output == phonemeSymbol) continue;

    if (seen.add(r.output)) {
      // Feature-bundle detection: output starts with '[' and ends with ']',
      // with at least one character between. Guards against lone '[' or ']'
      // malformed outputs (non-crashing fallback — treats them as non-bundle).
      final isBundle = r.output.length >= 2 &&
          r.output.startsWith('[') &&
          r.output.endsWith(']');
      out.add(AllophoneRealization(
        output: r.output,
        ruleSource: r.source,
        isFeatureBundle: isBundle,
      ));
    }
  }

  return out;
}
