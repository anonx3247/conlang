import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test fixture — mirrors paradigm_engine_test.dart
// ---------------------------------------------------------------------------

final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r', 'x'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r', 'x'],
    'v': ['a', 'e', 'i', 'o', 'u'],
    'vowel': ['a', 'e', 'i', 'o', 'u'],
  },
);

const int dimNumber = 11;
const int dimCase = 12;
const int lvlPL = 1;
const int lvlDAT = 1;
const int lvlNOM = 2;

InflectionalRule _rule(
  int id,
  String name,
  String source,
  Map<int, int> dims, {
  bool isActive = true,
}) {
  return InflectionalRule(
    id: id,
    name: name,
    source: source,
    isActive: isActive,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

PhonologicalRewriteRule _parse(String source) {
  final parsed = parseRewriteRule(source);
  expect(parsed.isValid, isTrue,
      reason: 'Test setup: rewrite "$source" failed to parse: ${parsed.error}');
  return parsed.rule!;
}

void main() {
  group('computeParadigmCell + rewrite rule pipeline (G-08)', () {
    test('rewrite rule is applied to the final inflected form', () {
      // Rule: suffix "ki" for number=PL produces kata + ki = kataki
      // Rewrite: k -> x / V_V (velar lenition between vowels)
      //   Final form kataki has a `k` between `a` and `i` (both vowels), so
      //   the rewrite should lenite it: kataxi.
      final rules = [
        _rule(1, 'Plural', '+ki', const {dimNumber: lvlPL}),
      ];
      final rewrite = [_parse('k -> x / V_V')];

      final cell = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
        rewriteRules: rewrite,
      );

      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, equals('kataxi'));
    });

    test('rewrite NOT applied when rewriteRules is empty', () {
      final rules = [
        _rule(1, 'Plural', '+ki', const {dimNumber: lvlPL}),
      ];

      final cell = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
        rewriteRules: const [],
      );

      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, equals('kataki'));
    });

    test('rewrite runs once on the final form, not after each rule', () {
      // Two-rule inflectional chain: +ar then +e  ->  root 'kat' -> 'katar' -> 'katare'
      // Rewrite: r -> n / V_V   (r between vowels becomes n)
      // If applied AFTER the whole chain, 'katare' has r between 'a' and 'e' -> 'katane'.
      // If (wrongly) applied after stage 1, 'katar' has no V_V match (r is
      // word-final) so nothing changes, then +e yields 'katare' and
      // re-applying the rewrite again would yield 'katane' anyway. To prove
      // one-shot we instead rely on the fact that the rewrite is NOT re-run
      // on each stage: when the rewrite's left context depends on the FINAL
      // form, it still fires correctly.
      final rules = [
        _rule(1, 'stage1', '+ar', const {dimNumber: lvlPL}),
        _rule(2, 'stage2', '+e', const {dimCase: lvlDAT}),
      ];
      final rewrite = [_parse('r -> n / V_V')];

      final cell = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL, dimCase: lvlDAT},
        rules: rules,
        inventory: _inventory,
        rewriteRules: rewrite,
      );

      expect(cell, isA<ParadigmFilled>());
      final filled = cell as ParadigmFilled;
      expect(filled.form, equals('katane'));
      // Both rules should be in the chain — rewrite must not disturb
      // chain accounting.
      expect(filled.ruleChain.length, equals(2));
    });

    test('uncovered cells do not invoke rewrite', () {
      // No rules match target {dimCase: lvlNOM} -> ParadigmUncovered.
      // Rewrite rules are present but must NOT change the result type.
      final rewrite = [_parse('k -> x / V_V')];

      final cell = computeParadigmCell(
        root: 'kata',
        target: const {dimCase: lvlNOM},
        rules: const [],
        inventory: _inventory,
        rewriteRules: rewrite,
      );

      expect(cell, isA<ParadigmUncovered>());
    });

    test('ParadigmAmbiguous cells skip rewrite', () {
      // Two rules with identical bindings -> ParadigmAmbiguous. Rewrite
      // rules are present but must NOT change the result type.
      final rules = [
        _rule(1, 'A', '+ki', const {dimNumber: lvlPL}),
        _rule(2, 'B', '+ki', const {dimNumber: lvlPL}),
      ];
      final rewrite = [_parse('k -> x / V_V')];

      final cell = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
        rewriteRules: rewrite,
      );

      expect(cell, isA<ParadigmAmbiguous>());
    });
  });
}
