// Plan 04-15 D-78: Unit tests for the shared pure notation helpers.
//
// These tests are pure-Dart — no Flutter binding, no database. They lock the
// dot-boundary semantics used by both the runtime providers and the v10
// migration against the canonical `(t, h, th)` fixture plus several other
// interesting cases.

import 'package:conlang_workbench/features/phonology/domain/notation_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

// Fixture A: the canonical D-78 case. The θ→th mapping collides with the
// naive concatenation of t + h, so `atha` is ambiguous without the dot.
final List<NotationMapping> fixtureA = <NotationMapping>[
  (ipaSymbol: 'a', latinMapping: 'a'),
  (ipaSymbol: 't', latinMapping: 't'),
  (ipaSymbol: 'h', latinMapping: 'h'),
  (ipaSymbol: 'θ', latinMapping: 'th'),
];

// Fixture B: s / ʃ / t / tʃ prefix collisions. Includes `h` so both sides
// of the sh vs s+h boundary are actual mapped phonemes (otherwise the
// segmenter would emit `h` as a pass-through class-ref lookalike and the
// boundary-insertion gate would skip it).
final List<NotationMapping> fixtureB = <NotationMapping>[
  (ipaSymbol: 'a', latinMapping: 'a'),
  (ipaSymbol: 's', latinMapping: 's'),
  (ipaSymbol: 'h', latinMapping: 'h'),
  (ipaSymbol: 'ʃ', latinMapping: 'sh'),
  (ipaSymbol: 't', latinMapping: 't'),
  (ipaSymbol: 'tʃ', latinMapping: 'ch'),
];

// Fixture C: class-ref lookalike — `V` (capital) is a class-ref token, not
// a phoneme, so it must flow through segmentation unchanged.
final List<NotationMapping> fixtureC = <NotationMapping>[
  (ipaSymbol: 'a', latinMapping: 'a'),
  (ipaSymbol: 't', latinMapping: 't'),
];

// Fixture D: genuinely non-bijective — two phonemes share a rom target.
final List<NotationMapping> fixtureD = <NotationMapping>[
  (ipaSymbol: 'a', latinMapping: 'a'),
  (ipaSymbol: 't', latinMapping: 't'),
  (ipaSymbol: 'h', latinMapping: 'h'),
  (ipaSymbol: 'θ', latinMapping: 't'), // collision with /t/
];

void main() {
  group('Fixture A — canonical D-78 (t, h, th)', () {
    test('dotAwareDeromanize("atha") → "aθa" (longest-match wins)', () {
      expect(dotAwareDeromanize('atha', fixtureA), equals('aθa'));
    });

    test('dotAwareDeromanize("at.ha") → "atha" (dot forces boundary)', () {
      // The dot is consumed and splits the longest-match scan, so `t` and
      // `h` stay as two separate phonemes instead of being absorbed into θ.
      expect(dotAwareDeromanize('at.ha', fixtureA), equals('atha'));
    });

    test('smartRomanize("atha") → "at.ha" (boundary inserted)', () {
      expect(smartRomanize('atha', fixtureA), equals('at.ha'));
    });

    test('smartRomanize("aθa") → "atha" (no boundary needed)', () {
      expect(smartRomanize('aθa', fixtureA), equals('atha'));
    });

    test('round-trip identity for each single phoneme + interesting pairs',
        () {
      final cases = <String>['a', 't', 'h', 'θ', 'atha', 'aθa', 'tθt', 'thθh'];
      for (final x in cases) {
        final rom = smartRomanize(x, fixtureA);
        final back = dotAwareDeromanize(rom, fixtureA);
        expect(back, equals(x), reason: 'round-trip failed for "$x": '
            'smartRomanize=$rom, deromanize=$back');
      }
    });
  });

  group('Fixture B — s / ʃ / t / tʃ prefix collisions', () {
    test('round-trip identity for every single phoneme', () {
      for (final m in fixtureB) {
        final rom = smartRomanize(m.ipaSymbol, fixtureB);
        final back = dotAwareDeromanize(rom, fixtureB);
        expect(back, equals(m.ipaSymbol),
            reason: 'round-trip failed for "${m.ipaSymbol}": rom=$rom');
      }
    });

    test('smartRomanize("sh") → "s.h" (disambiguates from ʃ)', () {
      // Two separate phonemes /s/ /h/ must be rendered with a dot so they
      // don't collapse back to /ʃ/ under longest-match deromanize.
      expect(smartRomanize('sh', fixtureB), equals('s.h'));
    });

    test('smartRomanize("ʃ") → "sh" (no boundary needed)', () {
      expect(smartRomanize('ʃ', fixtureB), equals('sh'));
    });

    test('round-trip for /sh/ vs /ʃ/ is disambiguated', () {
      final rom1 = smartRomanize('sh', fixtureB);
      final rom2 = smartRomanize('ʃ', fixtureB);
      expect(rom1, isNot(equals(rom2)));
      expect(dotAwareDeromanize(rom1, fixtureB), equals('sh'));
      expect(dotAwareDeromanize(rom2, fixtureB), equals('ʃ'));
    });
  });

  group('Fixture C — class-ref pass-through', () {
    test('phonemicSegmentation does not swallow class-ref letters', () {
      // `V` is not a mapping — the segmenter must emit it as a single
      // code-point segment and not try to absorb it into a phoneme scan.
      final segments = phonemicSegmentation('Vat', fixtureC);
      expect(segments, equals(<String>['V', 'a', 't']));
    });

    test('smartRomanize emits class-refs verbatim', () {
      // `V` has no rom form — it should flow through as `V`. No boundary
      // should be inserted adjacent to a class-ref per D-78 invariant.
      expect(smartRomanize('Vat', fixtureC), equals('Vat'));
      expect(smartRomanize('atV', fixtureC), equals('atV'));
    });

    test('dotAwareDeromanize passes class-refs through untouched', () {
      expect(dotAwareDeromanize('Vat', fixtureC), equals('Vat'));
      expect(dotAwareDeromanize('CVCV', fixtureC), equals('CVCV'));
    });
  });

  group('Fixture D — duplicate-rom target', () {
    test('isDotAwareBijection returns false when two phonemes share a rom',
        () {
      expect(isDotAwareBijection(fixtureD), isFalse);
    });
  });

  group('Empty + edge cases', () {
    test('empty mapping list acts as identity for both helpers', () {
      expect(dotAwareDeromanize('hello', const <NotationMapping>[]),
          equals('hello'));
      expect(smartRomanize('hello', const <NotationMapping>[]),
          equals('hello'));
      expect(phonemicSegmentation('hello', const <NotationMapping>[]),
          equals(<String>['h', 'e', 'l', 'l', 'o']));
    });

    test('empty input strings round-trip through both helpers', () {
      expect(smartRomanize('', fixtureA), equals(''));
      expect(dotAwareDeromanize('', fixtureA), equals(''));
      expect(phonemicSegmentation('', fixtureA), isEmpty);
    });

    test('isDotAwareBijection accepts empty mapping list', () {
      expect(isDotAwareBijection(const <NotationMapping>[]), isTrue);
    });

    test('isDotAwareBijection accepts canonical D-78 fixture A', () {
      expect(isDotAwareBijection(fixtureA), isTrue);
    });

    test('isDotAwareBijection accepts fixture B (s/ʃ/t/tʃ)', () {
      expect(isDotAwareBijection(fixtureB), isTrue);
    });
  });
}
