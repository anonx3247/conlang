import 'package:petitparser/petitparser.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// A single position in a syllable template.
///
/// A slot represents one sound-position in the syllable structure.
/// Examples from the template `(C)(C)V(C)`:
///   - Slot(classReference: 'C', isOptional: true)
///   - Slot(classReference: 'C', isOptional: true)
///   - Slot(classReference: 'V', isOptional: false)
///   - Slot(classReference: 'C', isOptional: true)
///
/// For `[stop]`:  Slot(classReference: 'stop', isOptional: false)
/// For literal `p`: Slot(literalPhoneme: 'p', isOptional: false)
class Slot {
  const Slot({
    this.classReference,
    this.isOptional = false,
    this.literalPhoneme,
  }) : assert(
         classReference != null || literalPhoneme != null,
         'Slot must have either classReference or literalPhoneme',
       );

  /// The name of a natural class (e.g. 'C', 'V', 'stop', 'tone:H').
  /// Null if this is a literal-phoneme slot.
  final String? classReference;

  /// Whether this slot may be omitted during word generation.
  final bool isOptional;

  /// A specific IPA symbol (for literal phoneme positions). Null if this is
  /// a class-reference slot.
  final String? literalPhoneme;

  bool get isLiteral => literalPhoneme != null;

  @override
  String toString() {
    final core = isLiteral ? '"$literalPhoneme"' : '[$classReference]';
    return isOptional ? '($core)?' : core;
  }

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      classReference == other.classReference &&
      isOptional == other.isOptional &&
      literalPhoneme == other.literalPhoneme;

  @override
  int get hashCode => Object.hash(classReference, isOptional, literalPhoneme);
}

/// Result of parsing a full syllable template string.
///
/// `pattern` is the original source string; `slots` is the ordered list of
/// parsed positions. [ParsedTemplate.error] is non-null when parsing failed.
class ParsedTemplate {
  const ParsedTemplate.success({
    required this.pattern,
    required this.slots,
  }) : error = null;

  const ParsedTemplate.failure({
    required this.pattern,
    required this.error,
  }) : slots = const [];

  final String pattern;
  final List<Slot> slots;
  final String? error;

  bool get isValid => error == null;
}

/// A forbidden sound sequence constraint.
///
/// Examples:
///   - `[stop][stop]` → pattern=[stop,stop] — no two stops in a row
///   - `CC`           → pattern=[C,C]       — no consonant clusters
///
/// All constraints are forbidden sequences. Legacy `LHS -> RHS` format is
/// accepted for backward compatibility but the RHS is stored as description.
class ConstraintRule {
  const ConstraintRule({
    required this.pattern,
    required this.description,
    required this.isForbidden,
    required this.source,
  });

  /// The segment sequence to match (reuses the same [Slot] type as templates).
  final List<Slot> pattern;

  /// Optional description (from legacy RHS or user-provided).
  final String description;

  /// Always true — all constraints are forbidden sequences.
  final bool isForbidden;

  /// Original source string, for display/edit round-tripping.
  final String source;

  @override
  String toString() => '$pattern';
}

/// Result of parsing a constraint rule string.
class ParsedConstraint {
  const ParsedConstraint.success({
    required this.source,
    required this.rule,
  }) : error = null;

  const ParsedConstraint.failure({
    required this.source,
    required this.error,
  }) : rule = null;

  final String source;
  final ConstraintRule? rule;
  final String? error;

  bool get isValid => error == null;
}

// ---------------------------------------------------------------------------
// Grammar helpers
// ---------------------------------------------------------------------------

/// Parses a natural-class name `[...]`.
/// Allows alphanumerics, underscores, hyphens, colons (e.g. `tone:H`).
Parser<String> _classNameBodyParser() =>
    pattern('a-zA-Z0-9_:-').plus().flatten();

/// Uppercase single letter (e.g. C, V, N) used as a shorthand class reference.
/// More-specific alternatives (bracketed class names) are tried first, so a
/// lone 'C' is only matched here when the square-bracket form fails.
Parser<String> _singleLetterParser() => uppercase().flatten();

/// Any character that is NOT a structural grammar character.
/// Catches multi-character IPA sequences and special phoneme characters.
Parser<String> _ipaCharParser() =>
    pattern('^\\[\\]() >\n\r-#_').plus().flatten();

// ---------------------------------------------------------------------------
// Core segment parser (shared by template and constraint parsers)
// ---------------------------------------------------------------------------

/// Parses a single segment element from a template or constraint LHS.
///
/// Priority order (PEG: first match wins):
///   1. `[className]`  — natural class in brackets
///   2. Single uppercase letter — shorthand class (C, V, N …)
///   3. IPA literal — any other phoneme symbol
///   4. `#` — word boundary marker
///
/// Returns a [Slot] with `isOptional = false` — optionality is applied by the
/// template parser wrapping this in `(...)`.
Parser<Slot> _segmentParser() {
  // 1. [className]
  final bracketClass =
      (char('[') & _classNameBodyParser() & char(']')).map((values) {
    return Slot(classReference: values[1] as String);
  });

  // 2. Single uppercase letter
  final singleClass = _singleLetterParser().map((c) => Slot(classReference: c));

  // 3. IPA literal
  final literal = _ipaCharParser().map((s) => Slot(literalPhoneme: s));

  // 4. Word boundary marker
  final wordBoundary = char('#').map((_) => Slot(literalPhoneme: '#'));

  return (bracketClass | singleClass | literal | wordBoundary).cast<Slot>();
}

// ---------------------------------------------------------------------------
// Template parser
// ---------------------------------------------------------------------------

/// Parses a syllable structure template string such as `(C)(C)V(C)`.
///
/// Returns a [ParsedTemplate] — check [ParsedTemplate.isValid] before use.
ParsedTemplate parseSyllableTemplate(String input) {
  if (input.trim().isEmpty) {
    return ParsedTemplate.failure(pattern: input, error: 'Template is empty');
  }

  final segmentParser = _segmentParser();

  // Optional slot: `(segment)`
  final optionalSlot = (char('(') & segmentParser & char(')')).map((values) {
    final slot = values[1] as Slot;
    return Slot(
      classReference: slot.classReference,
      literalPhoneme: slot.literalPhoneme,
      isOptional: true,
    );
  });

  // Required slot: bare segment
  final requiredSlot = segmentParser;

  // Template = one or more slots (try optional first)
  final templateParser = (optionalSlot | requiredSlot).plus().end();

  final result = templateParser.parse(input.trim());

  switch (result) {
    case Success():
      return ParsedTemplate.success(
        pattern: input,
        slots: List<Slot>.from(result.value),
      );
    case Failure():
      return ParsedTemplate.failure(
        pattern: input,
        error:
            'Parse error at position ${result.position}: expected ${result.message}',
      );
  }
}

// ---------------------------------------------------------------------------
// Constraint rule parser
// ---------------------------------------------------------------------------

/// Parses a forbidden sequence pattern such as `[stop][stop]` or `CC`.
///
/// Also accepts legacy `LHS -> RHS` format for backward compatibility,
/// but the RHS is treated as an optional description only.
///
/// Returns a [ParsedConstraint] — check [ParsedConstraint.isValid] before use.
ParsedConstraint parseConstraintRule(String input) {
  if (input.trim().isEmpty) {
    return ParsedConstraint.failure(source: input, error: 'Pattern is empty');
  }

  String patternRaw;
  String description;

  // Support legacy `LHS -> RHS` format for existing data.
  final arrowIdx = input.indexOf('->');
  if (arrowIdx >= 0) {
    patternRaw = input.substring(0, arrowIdx).trim();
    description = input.substring(arrowIdx + 2).trim();
  } else {
    patternRaw = input.trim();
    description = 'forbidden';
  }

  if (patternRaw.isEmpty) {
    return ParsedConstraint.failure(
      source: input,
      error: 'Pattern is empty',
    );
  }

  // Parse the pattern as a sequence of segments.
  final parser = _segmentParser().plus().end();
  final result = parser.parse(patternRaw);

  switch (result) {
    case Failure():
      return ParsedConstraint.failure(
        source: input,
        error:
            'Parse error at position ${result.position}: expected ${result.message}',
      );
    case Success():
      final slots = List<Slot>.from(result.value);

      return ParsedConstraint.success(
        source: input,
        rule: ConstraintRule(
          pattern: slots,
          description: description,
          isForbidden: true, // All constraints are forbidden sequences
          source: input,
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Rewrite rule data model
// ---------------------------------------------------------------------------

/// A phonological rewrite rule in SPE-style notation: A -> B / C_D
///
/// Examples:
///   - `k -> x / V_V`  (velar lenition between vowels)
///   - `V -> [+nasal] / _N`  (vowel nasalization before nasal)
///   - `t -> ʔ / _#`  (glottal stop at word boundary)
///   - `a -> e / [stop]_`  (vowel raising after stops)
class PhonologicalRewriteRule {
  const PhonologicalRewriteRule({
    required this.input,
    required this.output,
    required this.leftContext,
    required this.rightContext,
    required this.source,
  });

  /// The LHS input segment(s) to match (what changes).
  final List<Slot> input;

  /// The RHS output: either a literal string (replacement) or a feature
  /// description in brackets. Stored as raw string for v1 — we parse the
  /// input context but keep the output as a display string since applying
  /// the transformation is Phase 2 morphology engine work.
  final String output;

  /// Segments to the left of the target (before '_'). Empty list = no left context.
  final List<Slot> leftContext;

  /// Segments to the right of the target (after '_'). Empty list = no right context.
  final List<Slot> rightContext;

  /// Original source string for round-tripping.
  final String source;

  @override
  String toString() => source;
}

/// Result of parsing a rewrite rule string.
class ParsedRewriteRule {
  const ParsedRewriteRule.success({required this.source, required this.rule})
      : error = null;

  const ParsedRewriteRule.failure({required this.source, required this.error})
      : rule = null;

  final String source;
  final PhonologicalRewriteRule? rule;
  final String? error;

  bool get isValid => error == null;
}

// ---------------------------------------------------------------------------
// Rewrite rule parser
// ---------------------------------------------------------------------------

/// Parses a rewrite rule string such as `k -> x / V_V`.
///
/// Notation: `input -> output / leftContext_rightContext`
/// The environment (/ ...) is optional; left or right context can be empty.
///
/// Returns a [ParsedRewriteRule] — check [ParsedRewriteRule.isValid] before use.
ParsedRewriteRule parseRewriteRule(String input) {
  if (input.trim().isEmpty) {
    return ParsedRewriteRule.failure(source: input, error: 'Rule is empty');
  }

  // Split on " -> " (with spaces) to separate input from rhs.
  final arrowIdx = input.indexOf(' -> ');
  if (arrowIdx < 0) {
    return ParsedRewriteRule.failure(
      source: input,
      error: "Missing ' -> ' separator (use spaces around ->)",
    );
  }

  final inputPart = input.substring(0, arrowIdx).trim();
  final rhsPart = input.substring(arrowIdx + 4).trim(); // skip " -> "

  if (inputPart.isEmpty) {
    return ParsedRewriteRule.failure(
      source: input,
      error: 'Input (LHS) is empty',
    );
  }
  if (rhsPart.isEmpty) {
    return ParsedRewriteRule.failure(
      source: input,
      error: 'Output (RHS) is empty',
    );
  }

  // Split rhs on " / " to separate output from optional context.
  final slashIdx = rhsPart.indexOf(' / ');
  final outputPart =
      slashIdx >= 0 ? rhsPart.substring(0, slashIdx).trim() : rhsPart.trim();
  final contextPart =
      slashIdx >= 0 ? rhsPart.substring(slashIdx + 3).trim() : null;

  if (outputPart.isEmpty) {
    return ParsedRewriteRule.failure(
      source: input,
      error: 'Output segment is empty',
    );
  }

  // Parse the input segment(s) using the shared segment parser.
  final inputParser = _segmentParser().plus().end();
  final inputResult = inputParser.parse(inputPart);
  if (inputResult is Failure) {
    return ParsedRewriteRule.failure(
      source: input,
      error:
          'Input parse error at position ${inputResult.position}: ${inputResult.message}',
    );
  }
  final inputSlots = List<Slot>.from((inputResult as Success).value);

  // Parse context if present.
  List<Slot> leftContext = [];
  List<Slot> rightContext = [];

  if (contextPart != null) {
    // Split on "_" to get left and right context.
    final underscoreIdx = contextPart.indexOf('_');
    if (underscoreIdx < 0) {
      return ParsedRewriteRule.failure(
        source: input,
        error: "Context must contain '_' to mark target position",
      );
    }

    final leftRaw = contextPart.substring(0, underscoreIdx).trim();
    final rightRaw = contextPart.substring(underscoreIdx + 1).trim();

    // Parse left context (zero or more segments).
    if (leftRaw.isNotEmpty) {
      final leftParser = _segmentParser().plus().end();
      final leftResult = leftParser.parse(leftRaw);
      if (leftResult is Failure) {
        return ParsedRewriteRule.failure(
          source: input,
          error:
              'Left context parse error at position ${leftResult.position}: ${leftResult.message}',
        );
      }
      leftContext = List<Slot>.from((leftResult as Success).value);
    }

    // Parse right context (zero or more segments).
    if (rightRaw.isNotEmpty) {
      final rightParser = _segmentParser().plus().end();
      final rightResult = rightParser.parse(rightRaw);
      if (rightResult is Failure) {
        return ParsedRewriteRule.failure(
          source: input,
          error:
              'Right context parse error at position ${rightResult.position}: ${rightResult.message}',
        );
      }
      rightContext = List<Slot>.from((rightResult as Success).value);
    }
  }

  return ParsedRewriteRule.success(
    source: input,
    rule: PhonologicalRewriteRule(
      input: inputSlots,
      output: outputPart,
      leftContext: leftContext,
      rightContext: rightContext,
      source: input,
    ),
  );
}
