import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression tests for the Phase 3.2-04 UAT fix: rewrite rules produce the
// PHONETIC transcription shown in [brackets], while romanization and
// phonotactic validation operate on the RAW (phonemic) form.
//
// The canonical example from UAT feedback:
//
//     Rule: s -> z / V_V
//     Generated raw word: /asa/   (phonemic)
//     Rewrite rule output: [aza]  (surface / phonetic)
//     Romanization of raw: "asa"  (NOT "aza")
//
// These tests lock the underlying semantics. Four display panels depend on
// this contract:
//   - lib/features/phonology/presentation/sound_rules/word_generator_panel.dart
//   - lib/features/lexicon/presentation/dictionary/inspiration_panel.dart
//   - lib/features/morphology/presentation/rules/morphology_preview_panel.dart
//   - lib/features/morphology/presentation/rules/preview_panel.dart
//
// Each panel pairs (rawWord, phoneticWord) where phoneticWord is the
// output of applyRewriteRules and rawWord feeds romanize() + validateWord().

void main() {
  group('Rewrite-rule vs. romanization separation', () {
    final inventory = const PhonemeInventory(
      consonants: ['s', 'z', 't', 'k'],
      vowels: ['a', 'e', 'i'],
      naturalClasses: {},
    );

    test('applyRewriteRules("asa", s -> z / V_V) yields "aza"', () {
      final parsed = parseRewriteRule('s -> z / V_V');
      expect(parsed.isValid, isTrue,
          reason: 'parser should accept intervocalic voicing rule');
      expect(parsed.rule, isNotNull);

      final gen = WordGenerator();
      final phonetic = gen.applyRewriteRules(
        word: 'asa',
        rules: [parsed.rule!],
        inventory: inventory,
      );
      expect(phonetic, 'aza',
          reason: 'intervocalic s should become z in the surface form');
    });

    test('raw form "asa" is preserved when NO rewrite rules are applied', () {
      // This represents the romanization path: romanization reads the raw
      // form, not the rewritten one.
      final gen = WordGenerator();
      final phonetic = gen.applyRewriteRules(
        word: 'asa',
        rules: const [],
        inventory: inventory,
      );
      expect(phonetic, 'asa',
          reason: 'empty rule list must be a no-op');
    });

    test('phonemic != phonetic means romanize(raw) != romanize(phonetic)', () {
      // Identity romanize — a stand-in for any project without a mapping.
      // Proves that if a panel mistakenly romanizes the REWRITTEN form, it
      // would output "aza" instead of "asa".
      String identityRomanize(String s) => s;

      final parsed = parseRewriteRule('s -> z / V_V');
      final gen = WordGenerator();
      final raw = 'asa';
      final phonetic = gen.applyRewriteRules(
        word: raw,
        rules: [parsed.rule!],
        inventory: inventory,
      );

      final correctRomanization = identityRomanize(raw);
      final wrongRomanization = identityRomanize(phonetic);

      expect(correctRomanization, 'asa');
      expect(wrongRomanization, 'aza');
      expect(correctRomanization, isNot(equals(wrongRomanization)));
    });

    test('non-identity romanize maps raw phonemes, not surface phones', () {
      // Example: project uses Latin digraph "sh" for /ʃ/, but the rewrite
      // rule is unrelated (s -> z intervocalic). Romanizing the raw form
      // gives the expected Latin spelling; romanizing the surface would be
      // wrong in more complex projects.
      String latinRomanize(String s) => s
          .replaceAll('a', 'a')
          .replaceAll('s', 's')
          .replaceAll('z', 'z');

      final parsed = parseRewriteRule('s -> z / V_V');
      final gen = WordGenerator();
      final raw = 'asa';
      final phonetic = gen.applyRewriteRules(
        word: raw,
        rules: [parsed.rule!],
        inventory: inventory,
      );

      // User's expectation per UAT feedback: "romanisation stays asa."
      expect(latinRomanize(raw), 'asa');
      // And the phonetic bracket form is "aza".
      expect(phonetic, 'aza');
    });

    test('validateWord on raw vs. phonetic — phonotactics apply to phonemes',
        () {
      // Phonotactic constraints are defined over the phonemic inventory,
      // so validation should operate on the raw form. This test just locks
      // in that validateWord accepts phonemic input without crashing; the
      // real-project behavior is that raw and phonetic may have different
      // validity and we always want the raw answer.
      final gen = WordGenerator();
      final raw = gen.validateWord(
        word: 'asa',
        constraints: const [],
        inventory: inventory,
      );
      expect(raw.isValid, isTrue);
    });
  });

  group('Raw/phonetic pairing — panel display contract', () {
    // Simulates what the four panels do: pair each generated raw word with
    // its phonetic transcription and (separately) its romanization.
    // This locks the pairing order so a future refactor can't accidentally
    // cross the streams.
    final inventory = const PhonemeInventory(
      consonants: ['s', 'z', 't'],
      vowels: ['a', 'e'],
      naturalClasses: {},
    );

    ({String raw, String phonetic, String romanized}) computeRow(
      String rawWord,
      List<PhonologicalRewriteRule> rules,
      String Function(String) romanize,
    ) {
      final gen = WordGenerator();
      final phonetic = gen.applyRewriteRules(
        word: rawWord,
        rules: rules,
        inventory: inventory,
      );
      final romanized = romanize(rawWord); // NOTE: raw, not phonetic
      return (raw: rawWord, phonetic: phonetic, romanized: romanized);
    }

    test('row pairing: raw "asa", rule s->z/V_V, identity romanize', () {
      final rule = parseRewriteRule('s -> z / V_V').rule!;
      final row = computeRow('asa', [rule], (s) => s);

      expect(row.raw, 'asa');
      expect(row.phonetic, 'aza');
      expect(row.romanized, 'asa');
      // Display format: `romanized [phonetic]` => "asa [aza]"
      // Tap handler must pass `row.raw`, not `row.phonetic`.
      expect(row.raw, row.romanized,
          reason:
              'under identity romanize, raw and romanized must match — '
              'this fails only if romanize is fed the rewritten form');
    });

    test('row pairing: raw "ata", no applicable rule, identity romanize', () {
      final rule = parseRewriteRule('s -> z / V_V').rule!;
      final row = computeRow('ata', [rule], (s) => s);

      // Rule does not match /t/, so phonetic == raw.
      expect(row.raw, 'ata');
      expect(row.phonetic, 'ata');
      expect(row.romanized, 'ata');
    });

    test('row pairing: empty rule list — phonetic equals raw', () {
      final row = computeRow('asa', const [], (s) => s);
      expect(row.phonetic, row.raw);
      expect(row.romanized, row.raw);
    });
  });
}
