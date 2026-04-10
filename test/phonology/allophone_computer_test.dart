// test/phonology/allophone_computer_test.dart
//
// Unit coverage for the pure allophone computation module (Phase 3.2 Plan 03).
//
// Parser probe notes (executed before writing tests — see plan read_first):
//   1. parseRewriteRule('st -> ʃt / #_') parses as isValid=true but returns a
//      SINGLE-slot input with literalPhoneme='st' (the literal parser captures
//      consecutive IPA chars as one multi-char literal). That means Path A from
//      the plan's fixture fork CANNOT exercise the r.input.length != 1 cluster
//      skip — we must use Path B (raw PhonologicalRewriteRule constructor with
//      a hand-built two-slot List<Slot>) to construct a genuine cluster rule
//      for Test 3. Path B is explicitly permitted by the plan's acceptance
//      criterion ("fixture-agnostic — filter r.input.length != 1 is under test,
//      not the parser's multi-segment LHS acceptance").
//   2. parseRewriteRule('[stop] -> b / V_V') parses with input[0].classReference='stop'.
//   3. parseRewriteRule('V -> [+nasal] / _n') parses with output='[+nasal]'.
//   4. parseRewriteRule('S -> b / V_V') parses with input[0].classReference='S'
//      (the single-letter parser routes uppercase single letters into the
//      classReference field, not literalPhoneme — so the alias path IS exercised
//      via the resolver chain).

import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/phonology/domain/allophone_computer.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';

/// Constructs a parsed rewrite rule fixture from a DSL source string, throwing
/// a StateError on parse failure so test authors notice broken fixtures fast.
PhonologicalRewriteRule _rule(String source) {
  final parsed = parseRewriteRule(source);
  if (!parsed.isValid || parsed.rule == null) {
    throw StateError(
      'Test fixture parse failed for: $source\n${parsed.error}',
    );
  }
  return parsed.rule!;
}

// Minimal inventory for resolver tests. We construct directly rather than via
// buildInventory because these tests focus on computeAllophones semantics, not
// default-class merge behavior. The 'stop' user class is included so the
// alias-class test (Test 11) has a control — it verifies that the resolver
// wrapper (NaturalClassResolver -> resolvePhonemeClass) actually delegates to
// the Plan 02 alias path, which checks `S` BEFORE falling through to any
// lowercased class lookup.
const _testInventory = PhonemeInventory(
  consonants: ['p', 't', 'k', 's', 'ʃ', 'z', 'b', 'd', 'g', 'm', 'n'],
  vowels: ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: {
    'c': ['p', 't', 'k', 's', 'ʃ', 'z', 'b', 'd', 'g', 'm', 'n'],
    'v': ['a', 'e', 'i', 'o', 'u'],
    'stop': ['p', 't', 'k', 'b', 'd', 'g'],
  },
);

final _resolver = NaturalClassResolver(_testInventory);

void main() {
  group('computeAllophones', () {
    test('Case A: literal match returns the rule output', () {
      final rules = [_rule('s -> ʃ / _i')];
      final result = computeAllophones('s', rules, _resolver);
      expect(result, hasLength(1));
      expect(result[0].output, equals('ʃ'));
      expect(result[0].isFeatureBundle, isFalse);
      expect(result[0].ruleSource, equals('s -> ʃ / _i'));
    });

    test('Case B: class reference match returns the rule output', () {
      // [stop] -> b / V_V ; phoneme /p/ is in the user 'stop' class.
      final rules = [_rule('[stop] -> b / V_V')];
      final result = computeAllophones('p', rules, _resolver);
      expect(result, hasLength(1));
      expect(result[0].output, equals('b'));
    });

    test('Case C: multi-segment cluster input is skipped', () {
      // Path B (raw constructor) — the parser coalesces 'st' into a single
      // literal slot, so we must construct the two-slot fixture directly to
      // exercise the r.input.length != 1 filter.
      const clusterRule = PhonologicalRewriteRule(
        input: [
          Slot(literalPhoneme: 's'),
          Slot(literalPhoneme: 't'),
        ],
        output: 'ʃt',
        leftContext: [Slot(literalPhoneme: '#')],
        rightContext: [],
        source: 'st -> ʃt / #_',
      );
      final result = computeAllophones('s', [clusterRule], _resolver);
      expect(result, isEmpty);
    });

    test('identity rule is skipped', () {
      final rules = [_rule('a -> a / _e')];
      final result = computeAllophones('a', rules, _resolver);
      expect(result, isEmpty);
    });

    test('duplicate outputs are deduplicated', () {
      final rules = [
        _rule('s -> z / V_V'),
        _rule('s -> z / _#'),
      ];
      final result = computeAllophones('s', rules, _resolver);
      expect(result, hasLength(1));
      expect(result[0].output, equals('z'));
    });

    test('unrelated rule does not match', () {
      final rules = [_rule('k -> x / V_V')];
      final result = computeAllophones('s', rules, _resolver);
      expect(result, isEmpty);
    });

    test('feature-bundle output is flagged', () {
      // V -> [+nasal] / _n — matches phoneme /a/ via the V shortcut which
      // resolves (through Plan 02's resolvePhonemeClass) to inventory.vowels.
      final rules = [_rule('V -> [+nasal] / _n')];
      final result = computeAllophones('a', rules, _resolver);
      expect(result, hasLength(1));
      expect(result[0].output, equals('[+nasal]'));
      expect(result[0].isFeatureBundle, isTrue);
    });

    test('non-bundle output has isFeatureBundle false', () {
      final rules = [_rule('s -> ʃ / _i')];
      final result = computeAllophones('s', rules, _resolver);
      expect(result[0].isFeatureBundle, isFalse);
    });

    test('ordering follows input list iteration', () {
      final rules = [
        _rule('s -> z / V_V'),
        _rule('s -> ʃ / _i'),
      ];
      final result = computeAllophones('s', rules, _resolver);
      expect(result, hasLength(2));
      expect(result[0].output, equals('z'));
      expect(result[1].output, equals('ʃ'));
    });

    test('empty rules list returns empty realizations', () {
      final result = computeAllophones('s', const [], _resolver);
      expect(result, isEmpty);
    });

    test('alias class reference S matches stop phoneme /p/', () {
      // Plan 02's resolvePhonemeClass handles the 'S' alias case-sensitively,
      // returning defaultNaturalClassAliases['S'] (the default stop list).
      // /p/ is in that list, so this rule affects /p/.
      //
      // The test inventory's user 'stop' class also contains 'p', but the
      // alias path runs BEFORE the lowercased user-class path, so the
      // realization flows through the alias tier. We add a direct resolver
      // assertion below to make the alias path unambiguous.
      expect(_resolver.resolve('S'), contains('p'),
          reason: 'alias path must resolve S to default stops containing /p/');
      final rules = [_rule('S -> b / V_V')];
      final result = computeAllophones('p', rules, _resolver);
      expect(result, hasLength(1));
      expect(result[0].output, equals('b'));
    });
  });

  group('AllophoneRealization', () {
    test('equality is based on output only (for dedup)', () {
      const a = AllophoneRealization(
        output: 'ʃ',
        ruleSource: 'rule-one',
        isFeatureBundle: false,
      );
      const b = AllophoneRealization(
        output: 'ʃ',
        ruleSource: 'rule-two',
        isFeatureBundle: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
