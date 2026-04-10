import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/phonology/domain/default_natural_classes.dart';

// Unit tests for the D-07 default natural classes catalog.
//
// These tests lock the IPA member lists defined in:
//   .planning/phases/03.2-phonology-enhancements-inserted/03.2-RESEARCH.md
//     §"Example 1: Default class catalog"
// and 03.2-CONTEXT.md §D-07 / §F-3 / §A5 / §A1.
//
// Changes to the default classes MUST update these tests deliberately —
// they are the spec, not a drift detector.

void main() {
  group('defaultNaturalClasses catalog', () {
    test('contains exactly the 9 canonical keys', () {
      expect(
        defaultNaturalClasses.keys.toSet(),
        equals({
          'stop',
          'nasal',
          'fricative',
          'liquid',
          'rhotic',
          'obstruent',
          'sonorant',
          'approximant',
          'affricate',
        }),
      );
      expect(defaultNaturalClasses.length, equals(9));
    });

    test('every default class is non-empty', () {
      for (final entry in defaultNaturalClasses.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'defaultNaturalClasses[${entry.key}] must not be empty',
        );
      }
    });

    test("'stop' equals the locked 13-entry list (includes ʔ per A4)", () {
      expect(
        defaultNaturalClasses['stop'],
        equals(const [
          'p', 'b', 't', 'd', 'ʈ', 'ɖ', 'c', 'ɟ', 'k', 'ɡ', 'q', 'ɢ', 'ʔ',
        ]),
      );
    });

    test("'nasal' equals the locked 7-entry list", () {
      expect(
        defaultNaturalClasses['nasal'],
        equals(const ['m', 'ɱ', 'n', 'ɳ', 'ɲ', 'ŋ', 'ɴ']),
      );
    });

    test("'fricative' contains ɬ and ɮ (F-3 / A5 lateral-fricative additions)",
        () {
      final fricatives = defaultNaturalClasses['fricative']!;
      expect(fricatives, contains('ɬ'));
      expect(fricatives, contains('ɮ'));
    });

    test("'obstruent' equals stop + fricative + affricate (concat order)", () {
      final expected = <String>[
        ...defaultNaturalClasses['stop']!,
        ...defaultNaturalClasses['fricative']!,
        ...defaultNaturalClasses['affricate']!,
      ];
      expect(defaultNaturalClasses['obstruent'], equals(expected));
    });

    test("'sonorant' contains no vowel characters (A1: consonant-only)", () {
      final sonorants = defaultNaturalClasses['sonorant']!;
      for (final v in const ['a', 'e', 'i', 'o', 'u']) {
        expect(
          sonorants,
          isNot(contains(v)),
          reason:
              "Vowel '$v' must not appear in sonorant — A1 keeps sonorant consonant-only",
        );
      }
    });
  });

  group('defaultNaturalClassAliases', () {
    test('has exactly 5 single-letter keys', () {
      expect(
        defaultNaturalClassAliases.keys.toSet(),
        equals({'S', 'N', 'F', 'L', 'R'}),
      );
      expect(defaultNaturalClassAliases.length, equals(5));
    });

    test("'S' deep-equals defaultNaturalClasses['stop']", () {
      expect(
        defaultNaturalClassAliases['S'],
        equals(defaultNaturalClasses['stop']),
      );
    });

    test('all 5 aliases deep-equal their full-name counterparts', () {
      expect(
        defaultNaturalClassAliases['S'],
        equals(defaultNaturalClasses['stop']),
      );
      expect(
        defaultNaturalClassAliases['N'],
        equals(defaultNaturalClasses['nasal']),
      );
      expect(
        defaultNaturalClassAliases['F'],
        equals(defaultNaturalClasses['fricative']),
      );
      expect(
        defaultNaturalClassAliases['L'],
        equals(defaultNaturalClasses['liquid']),
      );
      expect(
        defaultNaturalClassAliases['R'],
        equals(defaultNaturalClasses['rhotic']),
      );
    });

    test('no lowercase alias keys exist (uppercase-only by convention)', () {
      for (final k in const ['s', 'n', 'f', 'l', 'r']) {
        expect(
          defaultNaturalClassAliases.containsKey(k),
          isFalse,
          reason:
              "Lowercase alias '$k' must not exist — aliases are uppercase-only to avoid shadowing literal phonemes",
        );
      }
    });
  });
}
