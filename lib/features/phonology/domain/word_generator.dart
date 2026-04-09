import 'dart:math';

import '../../phonology/domain/phonotactic_dsl.dart';

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
  List<String> generateWords({
    required List<ParsedTemplate> templates,
    required PhonemeInventory inventory,
    int count = 20,
    int minSyllables = 1,
    int maxSyllables = 3,
  }) {
    final activeTemplates =
        templates.where((t) => t.isValid && t.slots.isNotEmpty).toList();

    if (activeTemplates.isEmpty) return [];
    if (inventory.consonants.isEmpty && inventory.vowels.isEmpty) return [];

    final results = <String>[];
    for (var i = 0; i < count; i++) {
      final word = _generateWord(
        activeTemplates,
        inventory,
        minSyllables,
        maxSyllables,
      );
      if (word.isNotEmpty) results.add(word);
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
  }) {
    if (word.isEmpty || constraints.isEmpty) {
      return const ValidationResult(violations: []);
    }

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

    return ValidationResult(violations: violations);
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
  ///   - `[name]` or a named class → looks up [inventory.naturalClasses]
  ///   - Anything else → tries consonants first, then natural classes
  List<String> _resolveClass(String classRef, PhonemeInventory inventory) {
    switch (classRef) {
      case 'C':
        return inventory.consonants;
      case 'V':
        return inventory.vowels;
      default:
        // Try natural class by name (case-insensitive lookup).
        final key = classRef.toLowerCase();
        if (inventory.naturalClasses.containsKey(key)) {
          return inventory.naturalClasses[key]!;
        }
        // Fallback: try exact case.
        if (inventory.naturalClasses.containsKey(classRef)) {
          return inventory.naturalClasses[classRef]!;
        }
        return [];
    }
  }

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
    final tokens = _tokenize(word, inventory);
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
