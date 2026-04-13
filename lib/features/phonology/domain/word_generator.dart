import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../phonology/domain/phonotactic_dsl.dart';
import 'default_natural_classes.dart' show defaultNaturalClassAliases;

// Re-export GeminationConstraint so callers only need to import word_generator.
export '../../phonology/domain/phonotactic_dsl.dart'
    show GeminationConstraint, GeminationPosition;

// ---------------------------------------------------------------------------
// Inventory model (passed in from providers)
// ---------------------------------------------------------------------------

/// A lightweight phoneme inventory snapshot used by the word generator.
///
/// All symbols are raw IPA strings. Natural classes map a class name to the
/// IPA symbols of all phonemes in that class.
class PhonemeInventory {
  const PhonemeInventory({
    required this.consonants,
    required this.vowels,
    required this.naturalClasses,
  });

  final List<String> consonants;
  final List<String> vowels;

  /// Maps a natural class name (lowercase, e.g. 'stop', 'nasal') to the IPA
  /// symbols of phonemes in that class.
  final Map<String, List<String>> naturalClasses;

  /// Returns an empty inventory (no phonemes defined yet).
  static const PhonemeInventory empty = PhonemeInventory(
    consonants: [],
    vowels: [],
    naturalClasses: {},
  );
}

// ---------------------------------------------------------------------------
// Validation result
// ---------------------------------------------------------------------------

/// Describes a single phonotactic constraint violation in a word.
class Violation {
  const Violation({
    required this.position,
    required this.length,
    required this.ruleDescription,
  });

  /// Character index in the word string where the violation starts.
  final int position;

  /// Number of characters in the violating subsequence.
  final int length;

  /// Human-readable description of the violated rule (the RHS label).
  final String ruleDescription;
}

/// Result of validating a word against active constraint rules.
class ValidationResult {
  const ValidationResult({required this.violations});

  final List<Violation> violations;

  bool get isValid => violations.isEmpty;
}

// ---------------------------------------------------------------------------
// WordGenerator
// ---------------------------------------------------------------------------

/// Generates random IPA words from syllable templates + phoneme inventory.
///
/// The generator:
///   1. Picks a random active template.
///   2. For each slot, resolves the class to a phoneme list and picks randomly.
///   3. Concatenates N syllables (N drawn from [minSyllables]..[maxSyllables]).
///   4. Optionally validates the word against phonotactic constraint rules.
class WordGenerator {
  WordGenerator({
    Random? random,
  }) : _random = random ?? Random();

  final Random _random;

  /// Probability that an optional slot is included (0.0 – 1.0).
  static const double optionalInclusionProbability = 0.5;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates [count] random IPA words.
  ///
  /// Returns an empty list when no templates or no phonemes are available.
  ///
  /// When [constraints] is non-empty, generated words that violate any
  /// forbidden constraint are rejected and regenerated. The generator
  /// over-generates (up to `count * rejectionBudgetMultiplier` attempts)
  /// to collect [count] valid words; if the template/constraint combination
  /// is overly restrictive the returned list may be shorter than [count].
  List<String> generateWords({
    required List<ParsedTemplate> templates,
    required PhonemeInventory inventory,
    int count = 20,
    int minSyllables = 1,
    int maxSyllables = 3,
    List<ConstraintRule> constraints = const [],
    List<GeminationConstraint> geminationConstraints = const [],
  }) {
    final activeTemplates =
        templates.where((t) => t.isValid && t.slots.isNotEmpty).toList();

    if (activeTemplates.isEmpty) return [];
    if (inventory.consonants.isEmpty && inventory.vowels.isEmpty) return [];

    // Only forbidden, non-empty constraints are worth checking during
    // generation — advisory or malformed rules are silently ignored.
    final activeConstraints = constraints
        .where((c) => c.isForbidden && c.pattern.isNotEmpty)
        .toList();

    final hasAnyConstraints =
        activeConstraints.isNotEmpty || geminationConstraints.isNotEmpty;

    final results = <String>[];
    // Over-generate aggressively when constraints are active so a tight
    // rule set still yields a usable batch. `* 10` is an empirical budget:
    // if even this isn't enough, the rule set is effectively impossible.
    final maxAttempts = hasAnyConstraints ? count * 10 : count;
    for (var i = 0; i < maxAttempts && results.length < count; i++) {
      final word = _generateWord(
        activeTemplates,
        inventory,
        minSyllables,
        maxSyllables,
      );
      if (word.isEmpty) continue;

      if (hasAnyConstraints) {
        final validation = validateWord(
          word: word,
          constraints: activeConstraints,
          inventory: inventory,
          geminationConstraints: geminationConstraints,
        );
        if (!validation.isValid) continue;
      }

      results.add(word);
    }
    return results;
  }

  /// Validates [word] against [constraints].
  ///
  /// Scans the word for subsequences that match any constraint's LHS pattern.
  /// For forbidden constraints, each match is recorded as a [Violation].
  ///
  /// Note: The word is treated as a sequence of IPA characters. Multi-character
  /// IPA symbols (e.g. t͡ʃ) are matched as substrings of the word string, which
  /// works correctly if the phoneme symbols used during generation are consistent
  /// with the symbols in the inventory.
  ValidationResult validateWord({
    required String word,
    required List<ConstraintRule> constraints,
    required PhonemeInventory inventory,
    List<GeminationConstraint> geminationConstraints = const [],
  }) {
    if (word.isEmpty &&
        constraints.isEmpty &&
        geminationConstraints.isEmpty) {
      return const ValidationResult(violations: []);
    }
    if (word.isEmpty) return const ValidationResult(violations: []);

    final violations = <Violation>[];

    // Build a list of phoneme tokens in the word by splitting greedily on the
    // known phonemes (longest-first, like the romanizer).
    final phonemes = _tokenize(word, inventory);

    for (final constraint in constraints) {
      if (!constraint.isForbidden) continue; // Only flag forbidden patterns.
      if (constraint.pattern.isEmpty) continue;

      final matches = _findPatternMatches(phonemes, constraint, inventory);
      for (final match in matches) {
        violations.add(
          Violation(
            position: match.$1,
            length: match.$2,
            ruleDescription: constraint.description,
          ),
        );
      }
    }

    // Gemination violations.
    if (geminationConstraints.isNotEmpty) {
      violations.addAll(
        _checkGemination(phonemes, inventory, geminationConstraints),
      );
    }

    return ValidationResult(violations: violations);
  }

  /// Checks [phonemes] for adjacent identical consonants that violate any of
  /// the given [geminationConstraints].
  ///
  /// Returns a list of [Violation]s — one per violating geminate pair.
  List<Violation> _checkGemination(
    List<(String symbol, int offset)> phonemes,
    PhonemeInventory inventory,
    List<GeminationConstraint> geminationConstraints,
  ) {
    if (phonemes.length < 2 || geminationConstraints.isEmpty) return const [];

    final consonantSet = inventory.consonants.toSet();
    final violations = <Violation>[];
    final lastIndex = phonemes.length - 1;

    for (var i = 0; i < lastIndex; i++) {
      final (symbolA, offsetA) = phonemes[i];
      final (symbolB, _) = phonemes[i + 1];

      // Only flag identical consonant pairs.
      if (symbolA != symbolB) continue;
      if (!consonantSet.contains(symbolA)) continue;

      // Determine the syllabic position of this geminate pair.
      // Simplified heuristics (per plan D-07 / task action step 2):
      //   initial  : token index 0 (pair at 0-1)
      //   final_   : pair ends the word (i == lastIndex - 1)
      //   onset    : pair starts a syllable — at word start OR immediately after a vowel
      //   coda     : pair ends a syllable — at word end OR followed by a consonant
      //              (cluster before a vowel is onset, not coda)
      final isAtWordStart = (i == 0);
      final isAtWordEnd = (i == lastIndex - 1);
      final prevIsVowel =
          i > 0 && inventory.vowels.contains(phonemes[i - 1].$1);
      // Token immediately after the geminate pair (index i+2).
      final nextTokenIdx = i + 2;
      final nextIsVowel =
          nextTokenIdx < phonemes.length &&
          inventory.vowels.contains(phonemes[nextTokenIdx].$1);
      final nextIsConsonant =
          nextTokenIdx < phonemes.length &&
          inventory.consonants.contains(phonemes[nextTokenIdx].$1);

      final isInitial = isAtWordStart;
      final isFinal = isAtWordEnd;
      // Onset: pair immediately follows a vowel (V→CC) or is word-initial.
      final isOnset = isAtWordStart || prevIsVowel;
      // Coda: pair closes a syllable = word-final, or followed by a consonant
      // (C→CC in an inter-syllabic cluster — the pair belongs to the preceding coda).
      // A pair before a vowel (V·CC·V) is typically onset of the next syllable.
      final isCoda = isAtWordEnd || nextIsConsonant || (!nextIsVowel && nextTokenIdx < phonemes.length);

      for (final constraint in geminationConstraints) {
        bool fires = false;
        for (final pos in constraint.positions) {
          fires = switch (pos) {
            GeminationPosition.everywhere => true,
            GeminationPosition.initial => isInitial,
            GeminationPosition.final_ => isFinal,
            GeminationPosition.onset => isOnset,
            GeminationPosition.coda => isCoda,
          };
          if (fires) break;
        }

        if (fires) {
          final positionLabel = constraint.positions.contains(GeminationPosition.everywhere)
              ? 'everywhere'
              : constraint.positions.map((p) => switch (p) {
                    GeminationPosition.everywhere => 'everywhere',
                    GeminationPosition.coda => 'coda',
                    GeminationPosition.onset => 'onset',
                    GeminationPosition.initial => 'initial',
                    GeminationPosition.final_ => 'final',
                  }).join('/');
          violations.add(
            Violation(
              position: offsetA,
              length: symbolA.length * 2,
              ruleDescription: 'gemination violation ($positionLabel)',
            ),
          );
          break; // One violation per geminate pair per word is enough.
        }
      }
    }

    return violations;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _generateWord(
    List<ParsedTemplate> templates,
    PhonemeInventory inventory,
    int minSyllables,
    int maxSyllables,
  ) {
    final syllableCount = minSyllables +
        _random.nextInt(maxSyllables - minSyllables + 1);
    final buffer = StringBuffer();

    for (var s = 0; s < syllableCount; s++) {
      final template = templates[_random.nextInt(templates.length)];
      buffer.write(_generateSyllable(template, inventory));
    }

    return buffer.toString();
  }

  String _generateSyllable(ParsedTemplate template, PhonemeInventory inventory) {
    final buffer = StringBuffer();
    for (final slot in template.slots) {
      if (slot.isOptional &&
          _random.nextDouble() >= optionalInclusionProbability) {
        continue; // Skip optional slot.
      }

      if (slot.isLiteral) {
        buffer.write(slot.literalPhoneme);
        continue;
      }

      final phonemes = _resolveClass(slot.classReference!, inventory);
      if (phonemes.isEmpty) continue;

      buffer.write(phonemes[_random.nextInt(phonemes.length)]);
    }
    return buffer.toString();
  }

  /// Resolves a class reference to its list of IPA symbols.
  ///
  /// Recognised shorthands:
  ///   - `C` → all consonants
  ///   - `V` → all vowels
  ///   - Single-letter alias (S/N/F/L/R, case-sensitive) → default class list
  ///     (D-05a / RESEARCH F-2 — checked BEFORE lowercasing so `S` resolves to
  ///     Stops without colliding with literal /s/)
  ///   - `[name]` or a named class → looks up [inventory.naturalClasses]
  ///   - Anything else → tries consonants first, then natural classes
  List<String> _resolveClass(String classRef, PhonemeInventory inventory) {
    // 1. Reserved system shortcuts (C/V from Phase 1).
    switch (classRef) {
      case 'C':
        return inventory.consonants;
      case 'V':
        return inventory.vowels;
    }

    // 2. Single-letter alias (case-sensitive — checked BEFORE lowercasing so
    //    'S' resolves to Stops without colliding with literal /s/).
    //    Intersected with the user's inventory — the default catalog ships
    //    with full IPA sets but generation must only emit symbols the user
    //    actually has. See Phase 3.2 D-05a / RESEARCH F-2 and 2026-04-10 UAT.
    final alias = defaultNaturalClassAliases[classRef];
    if (alias != null) {
      final userSymbols = <String>{
        ...inventory.consonants,
        ...inventory.vowels,
      };
      return alias.where(userSymbols.contains).toList();
    }

    // 3. Lowercased name lookup (existing behavior — hits user classes and
    //    default full-name classes seeded by buildInventory in Plan 01).
    final key = classRef.toLowerCase();
    if (inventory.naturalClasses.containsKey(key)) {
      return inventory.naturalClasses[key]!;
    }

    // 4. Exact-case fallback (legacy behavior preserved for edge cases).
    if (inventory.naturalClasses.containsKey(classRef)) {
      return inventory.naturalClasses[classRef]!;
    }

    return [];
  }

  /// Testing-only wrapper around [_resolveClass] so unit tests can assert on
  /// resolver behavior without going through `generateWords`.
  @visibleForTesting
  List<String> resolveClassForTesting(
    String classRef,
    PhonemeInventory inventory,
  ) =>
      _resolveClass(classRef, inventory);

  // ---------------------------------------------------------------------------
  // Tokenizer (splits a word into phoneme tokens for constraint validation)
  // ---------------------------------------------------------------------------

  /// Splits [word] into a list of (phoneme, charOffset) pairs.
  ///
  /// Uses a greedy longest-match-first scan over known inventory phonemes.
  /// Unrecognised characters are emitted as single-character tokens.
  List<(String symbol, int offset)> _tokenize(
    String word,
    PhonemeInventory inventory,
  ) {
    // Build a sorted phoneme list (longest first) to handle multi-char IPA.
    final allPhonemes = <String>[
      ...inventory.consonants,
      ...inventory.vowels,
      for (final list in inventory.naturalClasses.values) ...list,
    ];
    final sorted = allPhonemes.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final tokens = <(String, int)>[];
    var i = 0;
    while (i < word.length) {
      String? matched;
      for (final p in sorted) {
        if (word.startsWith(p, i)) {
          matched = p;
          break;
        }
      }
      if (matched != null) {
        tokens.add((matched, i));
        i += matched.length;
      } else {
        tokens.add((word[i], i));
        i++;
      }
    }
    return tokens;
  }

  /// Like [_tokenize] but also treats [extraLiterals] as known atomic tokens,
  /// sorted longest-first alongside inventory phonemes.
  ///
  /// Used by [_applyOneRule] so that multi-char literal clusters written in a
  /// rewrite rule (e.g. "ei" in `ei -> ej`) are recognised as a single token
  /// even when they are not a single phoneme in the inventory.
  List<(String symbol, int offset)> _tokenizeWithExtras(
    String word,
    PhonemeInventory inventory,
    List<String> extraLiterals,
  ) {
    final allPhonemes = <String>[
      ...inventory.consonants,
      ...inventory.vowels,
      for (final list in inventory.naturalClasses.values) ...list,
      ...extraLiterals,
    ];
    final sorted = allPhonemes.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final tokens = <(String, int)>[];
    var i = 0;
    while (i < word.length) {
      String? matched;
      for (final p in sorted) {
        if (word.startsWith(p, i)) {
          matched = p;
          break;
        }
      }
      if (matched != null) {
        tokens.add((matched, i));
        i += matched.length;
      } else {
        tokens.add((word[i], i));
        i++;
      }
    }
    return tokens;
  }

  /// Returns a list of (charStart, charLength) for each location in [phonemes]
  /// where [constraint]'s pattern matches, respecting [constraint.position].
  List<(int, int)> _findPatternMatches(
    List<(String, int)> phonemes,
    ConstraintRule constraint,
    PhonemeInventory inventory,
  ) {
    final pattern = constraint.pattern;
    final matches = <(int, int)>[];

    if (pattern.length > phonemes.length) return matches;

    for (var i = 0; i <= phonemes.length - pattern.length; i++) {
      // Skip positions that don't match the constraint's position filter.
      switch (constraint.position) {
        case ConstraintPosition.start:
          if (i != 0) continue; // only check word-initial
        case ConstraintPosition.end:
          if (i + pattern.length != phonemes.length) continue; // only check word-final
        case ConstraintPosition.anywhere:
          break; // check all positions
      }

      var matchOk = true;
      for (var j = 0; j < pattern.length; j++) {
        final slot = pattern[j];
        final (symbol, _) = phonemes[i + j];

        if (!_slotMatches(slot, symbol, inventory)) {
          matchOk = false;
          break;
        }
      }

      if (matchOk) {
        // Calculate char offset + total char length of the match.
        final startOffset = phonemes[i].$2;
        final endToken = phonemes[i + pattern.length - 1];
        final endOffset = endToken.$2 + endToken.$1.length;
        matches.add((startOffset, endOffset - startOffset));
      }
    }

    return matches;
  }

  bool _slotMatches(Slot slot, String symbol, PhonemeInventory inventory) {
    if (slot.isLiteral) {
      return symbol == slot.literalPhoneme;
    }

    final classRef = slot.classReference!;
    final candidates = _resolveClass(classRef, inventory);
    return candidates.contains(symbol);
  }

  // ---------------------------------------------------------------------------
  // Rewrite rule application
  // ---------------------------------------------------------------------------

  /// Applies [rules] to [word], returning the transformed word.
  ///
  /// Each rule is applied left-to-right across the token sequence. Rules are
  /// applied in order; earlier rules' outputs feed into later rules.
  String applyRewriteRules({
    required String word,
    required List<PhonologicalRewriteRule> rules,
    required PhonemeInventory inventory,
  }) {
    if (rules.isEmpty || word.isEmpty) return word;

    var current = word;
    for (final rule in rules) {
      current = _applyOneRule(current, rule, inventory);
    }
    return current;
  }

  String _applyOneRule(
    String word,
    PhonologicalRewriteRule rule,
    PhonemeInventory inventory,
  ) {
    // Collect any multi-char literal phonemes from the rule's input and context
    // slots. These may not be in the inventory (e.g. "ei" is two separate
    // phonemes but the rule treats the cluster as a single atomic unit).
    // We pass them as extra candidates to _tokenizeWithExtras so the tokenizer
    // can emit "ei" as a single token and _slotMatches can find it.
    final extraLiterals = <String>[];
    for (final slot in [...rule.input, ...rule.leftContext, ...rule.rightContext]) {
      if (slot.isLiteral) {
        final lit = slot.literalPhoneme!;
        if (lit.length > 1) extraLiterals.add(lit);
      }
    }
    final tokens = extraLiterals.isEmpty
        ? _tokenize(word, inventory)
        : _tokenizeWithExtras(word, inventory, extraLiterals);
    if (tokens.isEmpty || rule.input.isEmpty) return word;

    final inputLen = rule.input.length;
    final result = StringBuffer();
    var i = 0;

    while (i < tokens.length) {
      // Check if input pattern matches at position i.
      if (i + inputLen <= tokens.length && _slotsMatch(tokens, i, rule.input, inventory)) {
        // Check left context.
        if (_contextMatches(tokens, i, rule.leftContext, inventory, isLeft: true) &&
            _contextMatches(tokens, i + inputLen, rule.rightContext, inventory, isLeft: false)) {
          // Replace: write output instead of matched tokens.
          result.write(rule.output);
          i += inputLen;
          continue;
        }
      }
      // No match — write original token.
      result.write(tokens[i].$1);
      i++;
    }
    return result.toString();
  }

  /// Checks if slots match tokens starting at [start].
  bool _slotsMatch(
    List<(String, int)> tokens,
    int start,
    List<Slot> slots,
    PhonemeInventory inventory,
  ) {
    for (var j = 0; j < slots.length; j++) {
      if (!_slotMatches(slots[j], tokens[start + j].$1, inventory)) {
        return false;
      }
    }
    return true;
  }

  /// Checks if context slots match adjacent tokens.
  ///
  /// For left context: checks tokens immediately before [anchorIdx].
  /// For right context: checks tokens starting at [anchorIdx].
  bool _contextMatches(
    List<(String, int)> tokens,
    int anchorIdx,
    List<Slot> context,
    PhonemeInventory inventory, {
    required bool isLeft,
  }) {
    if (context.isEmpty) return true; // No context constraint.

    if (isLeft) {
      // Left context: match tokens ending at anchorIdx - 1.
      final start = anchorIdx - context.length;
      if (start < 0) {
        // Check for word boundary (#) at start.
        return context.length == 1 &&
            context[0].isLiteral &&
            context[0].literalPhoneme == '#' &&
            anchorIdx == 0;
      }
      return _slotsMatch(tokens, start, context, inventory);
    } else {
      // Right context: match tokens starting at anchorIdx.
      if (anchorIdx + context.length > tokens.length) {
        // Check for word boundary (#) at end.
        return context.length == 1 &&
            context[0].isLiteral &&
            context[0].literalPhoneme == '#' &&
            anchorIdx == tokens.length;
      }
      return _slotsMatch(tokens, anchorIdx, context, inventory);
    }
  }
}
