// Plan 04-15 D-74 / Task 3 — unit tests for the DSL-parse-aware notation
// classify helper that the v9→v10 migration uses.
//
// These tests lock the classify semantics against the critical regression
// from a dropped earlier attempt: the string-level approach silently rewrote
// ablaut flag segments (e.g. `e1` → `ε1`), flipping direction from fromEnd
// to fromStart. Fixture 4 below is the regression lock.
//
// They also cover: pure affix rewrite, condition+affix (condition untouched
// by WARN-1 deferral), unparseable fallback, D-78 dot-separator in an affix,
// template/redup structural ops left alone, class-ref passthrough, empty
// source.

import 'package:conlang_workbench/db/migration_notation_classify.dart';
import 'package:conlang_workbench/features/phonology/domain/notation_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Shared fixture: a small bijective mapping set used across most tests.
  // Chosen so that `c → k`, `o → ø`, `e → ε` are the rewrites that matter.
  final mapping = <NotationMapping>[
    (ipaSymbol: 'k', latinMapping: 'c'),
    (ipaSymbol: 'ø', latinMapping: 'o'),
    (ipaSymbol: 'ε', latinMapping: 'e'),
    (ipaSymbol: 'æ', latinMapping: 'a'),
    (ipaSymbol: 'm', latinMapping: 'm'),
    (ipaSymbol: 'i', latinMapping: 'i'),
    (ipaSymbol: 's', latinMapping: 's'),
  ];

  // D-78 canonical (t, h, θ→th) mapping for dot-separator cases.
  final tthMapping = <NotationMapping>[
    (ipaSymbol: 'a', latinMapping: 'a'),
    (ipaSymbol: 't', latinMapping: 't'),
    (ipaSymbol: 'h', latinMapping: 'h'),
    (ipaSymbol: 'θ', latinMapping: 'th'),
  ];

  group('classifySingleLiteral', () {
    test('Fixture 1 — pure phonological literal rewrites to phonemic', () {
      // `moc` under {m→m, o→ø, c→k} should rewrite to `møk`.
      expect(classifySingleLiteral('moc', mapping), equals('møk'));
    });

    test('Fixture 11 — single uppercase class ref passes through', () {
      expect(classifySingleLiteral('V', mapping), equals('V'));
      expect(classifySingleLiteral('C', mapping), equals('C'));
      expect(classifySingleLiteral('F', mapping), equals('F'));
    });

    test('bracket-wrapped class ref passes through', () {
      expect(classifySingleLiteral('[nasal]', mapping), equals('[nasal]'));
      expect(classifySingleLiteral('[stop]', mapping), equals('[stop]'));
    });

    test('Fixture 12 — empty literal passes through', () {
      expect(classifySingleLiteral('', mapping), equals(''));
    });

    test('already-phonemic literal left unchanged (non-roundtrip)', () {
      // `møk` under the mapping: deromanize→`møk` (no rom glyphs match),
      // smartRomanize→`moc`. roundTrip (`moc`) != literal (`møk`), so leave
      // alone.
      expect(classifySingleLiteral('møk', mapping), equals('møk'));
    });

    test('class-ref-embedded literal left alone (non-roundtrip)', () {
      // `k` is a phoneme (ipa symbol), not a latin mapping → passes through
      // deromanize unchanged, then smartRomanize emits `c`. Non-roundtrip.
      expect(classifySingleLiteral('k', mapping), equals('k'));
    });
  });

  group('classifyAndRewriteRuleSource', () {
    test('Fixture 1 — pure suffix, rom→phonemic rewrite', () {
      final out = classifyAndRewriteRuleSource('+moc', mapping);
      expect(out.rewrote, isTrue);
      expect(out.reason, equals('rewritten'));
      expect(out.newSource, equals('+møk'));
    });

    test('Fixture 2 — pure suffix, already phonemic, left alone', () {
      final out = classifyAndRewriteRuleSource('+møk', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_phonemic'));
    });

    test('Fixture 3 — condition + suffix: condition untouched, suffix rewritten',
        () {
      // `"V"$ +moc` — the condition `"V"$` (endsWith class V) must NOT be
      // rewritten (WARN-1 condition deferral). The affix `moc` rewrites to
      // `møk`. Expected serialized form: `"V"$ +møk`.
      final out = classifyAndRewriteRuleSource(r'"V"$ +moc', mapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals(r'"V"$ +møk'));
    });

    test('Fixture 4 — ABLAUT FROM/TO rewritten, FLAGS PRESERVED (regression lock)',
        () {
      // `"V"$ /V/o/e1 | "C"$ +o` under a mapping containing `e → ε`.
      // CRITICAL: the ablaut flag `e1` contains ASCII `e` which a string-
      // level classify would silently rewrite to `ε1`, flipping direction
      // from fromEnd to fromStart. The DSL-parse-aware classify must
      // rewrite ONLY the FROM/TO fields (V→V class-ref, o→ø phoneme) and
      // preserve `e1` as ASCII.
      final out =
          classifyAndRewriteRuleSource(r'"V"$ /V/o/e1 | "C"$ +o', mapping);
      expect(out.rewrote, isTrue);
      // The serialized output has ASCII `e` in the flag, not `ε`.
      expect(out.newSource, equals(r'"V"$ /V/ø/e1 | "C"$ +ø'));
      // Explicit regression lock: the flag segment must contain ASCII `e`.
      expect(out.newSource!.contains('/e1'), isTrue,
          reason:
              'ablaut flag must preserve ASCII `e` — a string-level classify would have rewritten to `ε1`');
      expect(out.newSource!.contains('ε1'), isFalse,
          reason: 'ablaut flag must NOT be rewritten to `ε1`');
    });

    test('Fixture 5 — ablaut fromEnd count=2 flag preserved', () {
      final out = classifyAndRewriteRuleSource('/V/o/e2', mapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals('/V/ø/e2'));
    });

    test('Fixture 6 — ablaut fromStart default flag (no flag segment)', () {
      // The serializer omits the flag segment when direction is fromStart
      // with count=null (the default). Source `/V/o/` parses as fromStart
      // count=null, and re-serializes as `/V/ø/` (still flagless).
      final out = classifyAndRewriteRuleSource('/V/o/', mapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals('/V/ø/'));
    });

    test('Fixture 7 — condition with literal phoneme, left alone (non-roundtrip)',
        () {
      // `"k"$ +i | +ki` — the `k` is a phoneme (not rom), the affix `i`
      // is an identity mapping. Neither rewrite round-trips. Left alone.
      final out = classifyAndRewriteRuleSource(r'"k"$ +i | +ki', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_phonemic'));
    });

    test('Fixture 8 — unparseable source left alone', () {
      final out =
          classifyAndRewriteRuleSource(')))unparseable(((', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_unparseable'));
      expect(out.newSource, isNull);
    });

    test('Fixture 9 — D-78 dot separator in an affix rewrites to phonemic', () {
      // Under {a→a, t→t, h→h, θ→th}, `+at.ha` is rom for /atha/ (three
      // separate phonemes, dot consumed). The migration must rewrite it to
      // the phonemic form `+atha`.
      final out = classifyAndRewriteRuleSource('+at.ha', tthMapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals('+atha'));
    });

    test('Fixture 9b — D-78 inverse: undotted rom rewrites to θ reading', () {
      // `+atha` (no dot) under the same mapping deromanizes as `+aθa` —
      // longest-match prefers `th`. Migration rewrites to `+aθa`.
      final out = classifyAndRewriteRuleSource('+atha', tthMapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals('+aθa'));
    });

    test('Fixture 10 — RedupOp structural, left untouched', () {
      // redup:CV:prefix is a structural op (WARN-1 deferral). Classify must
      // leave it alone — serialized output identical to source.
      final out = classifyAndRewriteRuleSource('redup:CV:prefix', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_phonemic'));
    });

    test('Fixture 10b — InfixOp structural, left untouched', () {
      final out = classifyAndRewriteRuleSource('infix:an:2', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_phonemic'));
    });

    test('Fixture 11 — class-ref affix (+V) left alone via passthrough', () {
      // `+V` parses as SuffixOp(affix="V"). classifySingleLiteral("V", …)
      // returns `V` (single uppercase). Serialized output identical.
      final out = classifyAndRewriteRuleSource('+V', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_phonemic'));
    });

    test('Fixture 12 — empty source returns left_alone_empty', () {
      final out = classifyAndRewriteRuleSource('', mapping);
      expect(out.rewrote, isFalse);
      expect(out.reason, equals('left_alone_empty'));
    });

    test('prefix op rewrite (rule 9 Habitual shape)', () {
      // `ca+` parses as PrefixOp(affix="ca"). Under the mapping c→k, a→æ,
      // rewrites to `kæ+`.
      final out = classifyAndRewriteRuleSource('ca+', mapping);
      expect(out.rewrote, isTrue);
      expect(out.newSource, equals('kæ+'));
    });
  });
}
