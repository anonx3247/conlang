import 'package:conlang_workbench/features/lexicon/presentation/dictionary/inspiration_panel.dart';
import 'package:conlang_workbench/features/phonology/data/phonotactic_providers.dart';
import 'package:conlang_workbench/features/phonology/data/romanization_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression test for Phase 3.2-04 UAT feedback:
// "the rewrite phonology rules need to only affect the phonetic
//  transcription, not the romanisation"
//
// Behavior contract: when the user taps a word candidate in the Inspiration
// panel, the tap handler must pass the RAW (phonemic) form to
// onWordSelected. Downstream, word_creation_form calls romanize() on the
// value — and romanize() expects phonemic input, not a surface form.
//
// Before the fix: onWordSelected received `gen.applyRewriteRules(raw)`,
// so a rule like `s -> z / V_V` would cause /asa/ to be inserted as "aza",
// and romanize("aza") would be wrong in projects with non-trivial mappings.

void main() {
  testWidgets(
    'InspirationPanel.onWordSelected receives raw phonemic form, not rewritten',
    (tester) async {
      // Minimal inventory that only generates /s/, /a/ — every generated
      // word will contain only these phonemes, so the CVC template below
      // yields words like "sas", "asa", etc.
      const inventory = PhonemeInventory(
        consonants: ['s'],
        vowels: ['a'],
        naturalClasses: {},
      );

      // A CVC template — combined with a 1-syllable constraint this yields
      // 3-char words drawn from /s/ and /a/ only: "sas", "asa", etc.
      final template = parseSyllableTemplate('CVC');
      expect(template.isValid, isTrue);

      // The canonical UAT rule: intervocalic s -> z.
      final parsedRule = parseRewriteRule('s -> z / V_V');
      expect(parsedRule.isValid, isTrue);
      final rewriteRules = [parsedRule.rule!];

      String? capturedWord;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phonemeInventoryProvider.overrideWithValue(inventory),
            parsedRewriteRulesProvider.overrideWithValue(rewriteRules),
            parsedTemplatesProvider.overrideWith(
              (ref) => Stream.value([template]),
            ),
            romanizeProvider.overrideWithValue((s) => s), // identity
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: InspirationPanel(
                  onWordSelected: (w) => capturedWord = w,
                ),
              ),
            ),
          ),
        ),
      );

      // Let the StreamProvider emit and layout settle.
      await tester.pumpAndSettle();

      // Find word candidates inside the ListView. Because the inventory
      // only has /s/ and /a/, every generated 3-char word drawn from CVC
      // will contain only these letters. Tap the first candidate.
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget,
          reason: 'InspirationPanel should render a ListView of candidates');
      final candidateInkWells = find.descendant(
        of: listView,
        matching: find.byType(InkWell),
      );
      expect(candidateInkWells, findsWidgets,
          reason:
              'InspirationPanel should render at least one word candidate '
              'given a valid template + inventory');
      await tester.tap(candidateInkWells.first);
      await tester.pumpAndSettle();

      expect(capturedWord, isNotNull,
          reason: 'onWordSelected should have been called');

      // Core assertion: the captured word must be drawn entirely from the
      // raw inventory /s/ and /a/. A "z" would appear ONLY if the rewrite
      // rule was (incorrectly) applied before passing to the callback.
      expect(capturedWord!.contains('z'), isFalse,
          reason:
              'Tap handler passed the REWRITTEN form to onWordSelected. '
              'Rewrite rules should only affect the displayed phonetic '
              'bracket, not the value sent downstream.');

      // And every character should be from the raw inventory.
      for (final char in capturedWord!.split('')) {
        expect(['s', 'a'].contains(char), isTrue,
            reason:
                'Captured word "$capturedWord" contains "$char", which is '
                'not in the raw inventory {s, a}. This means the rewrite '
                'rule was applied before the tap handler.');
      }
    },
  );

  testWidgets(
    'InspirationPanel displays phonetic bracket when rewrite rules fire',
    (tester) async {
      const inventory = PhonemeInventory(
        consonants: ['s'],
        vowels: ['a'],
        naturalClasses: {},
      );
      final template = parseSyllableTemplate('VCV'); // will generate /asa/
      final rule = parseRewriteRule('s -> z / V_V').rule!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phonemeInventoryProvider.overrideWithValue(inventory),
            parsedRewriteRulesProvider.overrideWithValue([rule]),
            parsedTemplatesProvider.overrideWith(
              (ref) => Stream.value([template]),
            ),
            romanizeProvider.overrideWithValue((s) => s), // identity
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: InspirationPanel(
                  onWordSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The panel should render each row as `asa [aza]` (identity romanize
      // shows the raw form as primary and the phonetic form in brackets).
      // Find at least one bracketed phonetic label.
      expect(find.textContaining('[aza]'), findsWidgets,
          reason:
              'With rule s->z/V_V and raw /asa/, the phonetic bracket '
              'should display [aza].');
      // And the raw "asa" text should appear as the primary label.
      expect(find.text('asa'), findsWidgets,
          reason:
              'Raw phonemic "asa" should be shown as the primary label '
              '(from identity romanization of the raw form).');
    },
  );
}
