import 'morphology_dsl.dart';
import '../../phonology/domain/word_generator.dart';

/// Describes a single unknown-phoneme violation in a parsed rule literal
/// field. Plan 04-16 D-81 / G-69.
///
/// - [opIndex] is the 0-based index of the [MorphOperation] within its
///   branch. Condition violations (from [PatternCond]) use
///   [opIndex] == -1 to distinguish from operation violations; the
///   render-side code handles per-condition vs per-op display
///   accordingly.
/// - [literalOffset] is the 0-based character index within the literal
///   string where the violation starts.
/// - [length] is the character count of the violating run (usually 1).
/// - [char] is the offending substring for tooltip display.
class PhonemeViolation {
  const PhonemeViolation({
    required this.opIndex,
    required this.literalOffset,
    required this.length,
    required this.char,
  });

  final int opIndex;
  final int literalOffset;
  final int length;
  final String char;

  @override
  bool operator ==(Object other) =>
      other is PhonemeViolation &&
      other.opIndex == opIndex &&
      other.literalOffset == literalOffset &&
      other.length == length &&
      other.char == char;

  @override
  int get hashCode => Object.hash(opIndex, literalOffset, length, char);

  @override
  String toString() =>
      'PhonemeViolation(op:$opIndex, off:$literalOffset, len:$length, char:$char)';
}

/// Scans literal-string fields in every MorphOperation + PatternCond kind
/// against a [PhonemeInventory] using longest-match phoneme recognition.
/// Class-ref tokens (V, C, F, `[name]`) are skipped. Plan 04-16 D-81 /
/// G-69.
///
/// Scanner is pure — no Riverpod dependency. Consumers
/// `ref.watch(phonemeInventoryProvider)` and pass the snapshot.
///
/// Coverage (every MorphOperation subclass in `morphology_dsl.dart` is
/// explicitly handled):
///   - [PrefixOp]        — scan `.affix`
///   - [SuffixOp]        — scan `.affix`
///   - [InfixOp]         — scan `.affix` (`.position` is an int, not a
///                         literal)
///   - [AblautOp]        — scan `.from` AND `.to`
///   - [TemplateOp]      — scan `.pattern`, SKIPPING digits 1-9
///                         (consonant slot markers per
///                         `morphology_dsl.dart` line 46)
///   - [RedupOp]         — No literal phonemic fields (`.scope` and
///                         `.position` are structural enum-as-string
///                         values `'full' | 'CV' | 'C'` and
///                         `'prefix' | 'suffix'`). Intentional no-op.
///   - [SuppleteOp]      — scan `.form`
///   - [RemoveSuffixOp]  — scan `.suffix`
/// Conditions:
///   - [PatternCond]     — scan `.pattern`, tokenizing class-refs
///                         `V`/`C`/`F`/`[name]` as skip tokens.
class PhonemeLiteralScanner {
  const PhonemeLiteralScanner();

  /// Main entry. Returns an empty list for parse failures (defensive —
  /// we cannot scan what we cannot parse; the rule editor will show a
  /// separate parse-error indicator).
  List<PhonemeViolation> scan(
    ParsedMorphRule parsed,
    PhonemeInventory inventory,
  ) {
    if (!parsed.isValid || parsed.rule == null) return const [];
    final rule = parsed.rule!;
    final phonemes = _buildLongestFirstPhonemeList(inventory);
    final violations = <PhonemeViolation>[];

    for (final branch in rule.branches) {
      // Conditions — opIndex == -1 marks condition-scope violations.
      for (final cond in branch.conditions) {
        if (cond is PatternCond) {
          _scanPatternCond(cond, phonemes, violations);
        }
      }
      // Operations — opIndex is the 0-based index within the branch.
      for (var i = 0; i < branch.operations.length; i++) {
        final op = branch.operations[i];
        _scanOperation(op, i, phonemes, violations);
      }
    }
    return violations;
  }

  // ---------------------------------------------------------------------
  // Operation dispatch — exhaustive switch on MorphOperation subclasses.
  // If a new MorphOperation subclass is added to morphology_dsl.dart,
  // Dart's sealed class analysis will flag this switch as non-exhaustive.
  // ---------------------------------------------------------------------
  void _scanOperation(
    MorphOperation op,
    int opIndex,
    List<String> phonemes,
    List<PhonemeViolation> out,
  ) {
    switch (op) {
      case PrefixOp(:final affix):
        _scanLiteral(affix, opIndex, phonemes, out);
      case SuffixOp(:final affix):
        _scanLiteral(affix, opIndex, phonemes, out);
      case InfixOp(:final affix):
        _scanLiteral(affix, opIndex, phonemes, out);
      case AblautOp(:final from, :final to):
        _scanLiteral(from, opIndex, phonemes, out);
        _scanLiteral(to, opIndex, phonemes, out);
      case TemplateOp(:final pattern):
        _scanTemplate(pattern, opIndex, phonemes, out);
      case RedupOp():
        // No literal phonemic fields — scope and position are
        // structural enum-as-string values. Intentional no-op.
        break;
      case SuppleteOp(:final form):
        _scanLiteral(form, opIndex, phonemes, out);
      case RemoveSuffixOp(:final suffix):
        _scanLiteral(suffix, opIndex, phonemes, out);
    }
  }

  // ---------------------------------------------------------------------
  // Literal-string longest-match scan. Mirrors the
  // `word_generator.dart:172` tokenizer pattern.
  // ---------------------------------------------------------------------
  void _scanLiteral(
    String literal,
    int opIndex,
    List<String> phonemes,
    List<PhonemeViolation> out,
  ) {
    if (literal.isEmpty) return;
    var i = 0;
    while (i < literal.length) {
      final matched = _longestMatchAt(literal, i, phonemes);
      if (matched > 0) {
        i += matched;
      } else {
        // Unknown character — emit a 1-char violation. Consecutive
        // unknowns are emitted as individual violations (not merged)
        // so each tooltip can name the exact offending char.
        out.add(PhonemeViolation(
          opIndex: opIndex,
          literalOffset: i,
          length: 1,
          char: literal[i],
        ));
        i += 1;
      }
    }
  }

  // ---------------------------------------------------------------------
  // Template scan — skips digits 1-9 (consonant slot markers per
  // morphology_dsl.dart line 46).
  // ---------------------------------------------------------------------
  void _scanTemplate(
    String pattern,
    int opIndex,
    List<String> phonemes,
    List<PhonemeViolation> out,
  ) {
    if (pattern.isEmpty) return;
    var i = 0;
    while (i < pattern.length) {
      final ch = pattern[i];
      final code = ch.codeUnitAt(0);
      // Skip digits '1'..'9' (consonant slot markers).
      if (code >= 0x31 && code <= 0x39) {
        i += 1;
        continue;
      }
      final matched = _longestMatchAt(pattern, i, phonemes);
      if (matched > 0) {
        i += matched;
      } else {
        out.add(PhonemeViolation(
          opIndex: opIndex,
          literalOffset: i,
          length: 1,
          char: ch,
        ));
        i += 1;
      }
    }
  }

  // ---------------------------------------------------------------------
  // PatternCond scan — tokenizes class-refs (V, C, F, [name]) as skip
  // tokens. Class-refs bypass inventory check per D-73 / D-81.
  // ---------------------------------------------------------------------
  void _scanPatternCond(
    PatternCond cond,
    List<String> phonemes,
    List<PhonemeViolation> out,
  ) {
    final pattern = cond.pattern;
    if (pattern.isEmpty) return;
    var i = 0;
    while (i < pattern.length) {
      final ch = pattern[i];
      // Bracketed class-ref: '[name]' — skip the whole bracketed run.
      if (ch == '[') {
        final closeIdx = pattern.indexOf(']', i + 1);
        if (closeIdx == -1) {
          // Malformed — treat '[' as a single unknown literal and
          // advance by one char.
          out.add(PhonemeViolation(
            opIndex: -1,
            literalOffset: i,
            length: 1,
            char: ch,
          ));
          i += 1;
          continue;
        }
        i = closeIdx + 1;
        continue;
      }
      // Single-letter class-refs: V, C, F (morphology_dsl.dart:87 —
      // 'Single uppercase letter: C = any consonant, V = any vowel',
      // F reserved for feature/flag class per D-73).
      if (ch == 'V' || ch == 'C' || ch == 'F') {
        i += 1;
        continue;
      }
      // Optional group markers `(` and `)` — structural, skip per
      // morphology_dsl.dart:90 '(group) — optional group'.
      if (ch == '(' || ch == ')') {
        i += 1;
        continue;
      }
      // Literal phoneme char — longest-match against inventory.
      final matched = _longestMatchAt(pattern, i, phonemes);
      if (matched > 0) {
        i += matched;
      } else {
        out.add(PhonemeViolation(
          opIndex: -1,
          literalOffset: i,
          length: 1,
          char: ch,
        ));
        i += 1;
      }
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  /// Builds a longest-first list of phonemes from the inventory's
  /// consonants and vowels. Duplicates (a phoneme appearing in both
  /// lists — shouldn't happen but defensive) are de-duplicated.
  List<String> _buildLongestFirstPhonemeList(PhonemeInventory inv) {
    final all = <String>{...inv.consonants, ...inv.vowels}.toList();
    all.sort((a, b) => b.length.compareTo(a.length));
    return all;
  }

  /// Returns the length of the longest phoneme matching [literal] at
  /// offset [i], or 0 if no phoneme matches.
  int _longestMatchAt(String literal, int i, List<String> phonemes) {
    for (final p in phonemes) {
      if (p.isEmpty) continue;
      if (i + p.length > literal.length) continue;
      if (literal.substring(i, i + p.length) == p) return p.length;
    }
    return 0;
  }
}
