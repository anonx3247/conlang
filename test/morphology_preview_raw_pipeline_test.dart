import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression test for Phase 3.2-04 UAT feedback:
// "the rewrite phonology rules need to only affect the phonetic
//  transcription, not the romanisation"
//
// Morphology preview panels (morphology_preview_panel.dart and
// preview_panel.dart) display rows of (root -> derived). Before this fix,
// the panels fed REWRITTEN words into the morphology engine and then
// romanized the rewritten output — which corrupted both the derived form
// and the romanization.
//
// Correct pipeline (this test locks it in):
//
//   1. Generate phonemic words:      "asa"
//   2. Feed phonemic -> morphology:  "asa" + suffix "-ti" -> "asati"
//   3. Romanize phonemic derived:    romanize("asati") = "asati"
//   4. Phonetic bracket (display):   applyRewriteRules("asati") = "azati"
//      (rule: s -> z / V_V fires on the intervocalic s in "asati")
//
// The test mirrors the computation in morphology_preview_panel.dart's
// ListView.builder and preview_panel.dart's _evaluate() to prove the
// data flow is correct.

void main() {
  const inventory = PhonemeInventory(
    consonants: ['s', 'z', 't'],
    vowels: ['a', 'i'],
    naturalClasses: {},
  );

  String identityRomanize(String s) => s;

  test('morphology operates on phonemic form, rewrite applies after', () {
    // Simple suffix rule: append "-ti" to any root.
    final parsedMorph = parseMorphDsl('+ti', name: 'suffix-ti');
    expect(parsedMorph.isValid, isTrue, reason: parsedMorph.error);
    final morphRule = parsedMorph.rule!;

    final rewriteParsed = parseRewriteRule('s -> z / V_V');
    expect(rewriteParsed.isValid, isTrue);
    final rewriteRules = [rewriteParsed.rule!];

    final engine = const MorphologyEngine();
    final gen = WordGenerator();

    // Step 1: raw phonemic root.
    const rawRoot = 'asa';

    // Step 2: apply morphology to the phonemic form.
    final result = engine.applyRule(morphRule, rawRoot, inventory);
    expect(result, isA<MorphSuccess>());
    final rawDerived = (result as MorphSuccess).form;
    expect(rawDerived, 'asati',
        reason:
            'morphology engine should append "ti" to the phonemic root, '
            'yielding "asati"');

    // Step 3: romanize the phonemic derived form.
    final romanizedDerived = identityRomanize(rawDerived);
    expect(romanizedDerived, 'asati',
        reason:
            'romanization must use the phonemic (raw) derived form — '
            'under identity romanize that means it equals rawDerived');

    // Step 4: phonetic bracket is the rewrite-rule output.
    final phoneticDerived = gen.applyRewriteRules(
      word: rawDerived,
      rules: rewriteRules,
      inventory: inventory,
    );
    // Intervocalic /s/ in "asati" — the first 's' is between /a/ and /a/,
    // so it becomes /z/: "azati".
    expect(phoneticDerived, 'azati',
        reason:
            'rewrite rule s->z/V_V should fire on the intervocalic s in '
            '"asati", producing the surface form "azati"');

    // Core contract: the phonetic and romanized forms MUST differ for
    // this test input, otherwise the bug wouldn't be observable.
    expect(romanizedDerived, isNot(equals(phoneticDerived)));
  });

  test('feeding rewritten word to morphology engine changes the derived output',
      () {
    // This is the BUG the fix prevents. If a panel applies rewrite rules
    // BEFORE morphology, the engine operates on the wrong string.
    //
    // Here we prove the buggy pipeline yields a different answer from the
    // correct one — so the correct pipeline is observably distinguishable.
    final morphRule = parseMorphDsl('+sa', name: 'suffix-sa').rule!;
    final rewriteRule = parseRewriteRule('s -> z / V_V').rule!;

    final engine = const MorphologyEngine();
    final gen = WordGenerator();

    const rawRoot = 'asa';

    // CORRECT pipeline: phonemic -> morph -> rewrite.
    final correctDerivedRaw =
        (engine.applyRule(morphRule, rawRoot, inventory) as MorphSuccess)
            .form;
    expect(correctDerivedRaw, 'asasa');
    final correctPhonetic = gen.applyRewriteRules(
      word: correctDerivedRaw,
      rules: [rewriteRule],
      inventory: inventory,
    );
    // "asasa" has two intervocalic s positions (1 and 3). Both become z.
    expect(correctPhonetic, 'azaza');

    // The romanization of the correct (phonemic) derived form:
    expect(identityRomanize(correctDerivedRaw), 'asasa');

    // BUGGY pipeline: rewrite -> morph.
    final buggyRewrittenFirst = gen.applyRewriteRules(
      word: rawRoot,
      rules: [rewriteRule],
      inventory: inventory,
    );
    expect(buggyRewrittenFirst, 'aza');
    final buggyDerivedFromRewritten =
        (engine.applyRule(morphRule, buggyRewrittenFirst, inventory)
                as MorphSuccess)
            .form;
    expect(buggyDerivedFromRewritten, 'azasa',
        reason:
            'the buggy pipeline operates on the wrong string: the morph '
            'engine sees "aza" instead of "asa" and appends "sa" to give '
            '"azasa", which is a different token sequence from the '
            'correct "asasa"');

    // Prove the two pipelines produce observably different romanizations.
    expect(
      identityRomanize(correctDerivedRaw),
      isNot(equals(identityRomanize(buggyDerivedFromRewritten))),
      reason:
          'romanizing the buggy pipeline output yields "azasa", not the '
          'correct "asasa" — this is the exact UAT complaint.',
    );
  });

  test('no rewrite rules — raw and phonetic are identical (regression guard)',
      () {
    // When no rewrite rules exist, the display should be unchanged from
    // pre-fix behavior: romanize(raw) as primary, no phonetic bracket
    // difference.
    final morphRule = parseMorphDsl('+ti', name: 'suffix-ti').rule!;
    final engine = const MorphologyEngine();
    final gen = WordGenerator();

    const rawRoot = 'asa';
    final rawDerived =
        (engine.applyRule(morphRule, rawRoot, inventory) as MorphSuccess)
            .form;
    final phoneticDerived = gen.applyRewriteRules(
      word: rawDerived,
      rules: const [],
      inventory: inventory,
    );
    expect(rawDerived, phoneticDerived,
        reason:
            'with no rewrite rules, phonetic must equal raw — guards '
            'against regressions in the empty-rule-list branch');
  });
}
