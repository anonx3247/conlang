import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/phonology/data/allophone_providers.dart';
import 'package:conlang_workbench/features/phonology/data/romanization_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/allophone_computer.dart';
import 'package:conlang_workbench/features/phonology/presentation/inventory/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests for _PhonemeChip's inline allophone suffix (Phase 3.2 D-15).
//
// Uses the @visibleForTesting buildPhonemeChipForTesting helper to access
// the private widget. allophoneMapProvider + romanizeProvider are overridden
// via ProviderScope so no real project database is required.
//
// Phoneme fixture uses Drift's generated const constructor directly; the
// minimum required fields are id, symbol, and type (all others are
// nullable per the Drift-generated class in app_database.g.dart).

Phoneme _testPhoneme(String symbol) => Phoneme(
      id: 1,
      symbol: symbol,
      type: 'consonant',
    );

void main() {
  group('_PhonemeChip allophone suffix', () {
    Widget scaffold({
      required Phoneme phoneme,
      required bool isAltHeld,
      Map<String, List<AllophoneRealization>> allophoneMap = const {},
    }) {
      return ProviderScope(
        overrides: [
          allophoneMapProvider.overrideWithValue(allophoneMap),
          // Identity romanization so the chip doesn't need a real project.
          romanizeProvider.overrideWithValue((String ipa) => ipa),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: buildPhonemeChipForTesting(
              phoneme: phoneme,
              isAltHeld: isAltHeld,
            ),
          ),
        ),
      );
    }

    testWidgets('no suffix when isAltHeld is false', (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('s'),
        isAltHeld: false,
        allophoneMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
          ],
        },
      ));
      expect(find.byKey(const ValueKey('allophone-suffix')), findsNothing);
    });

    testWidgets(
        'no suffix when isAltHeld is true but phoneme has no realizations (D-18)',
        (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('k'),
        isAltHeld: true,
        allophoneMap: const {},
      ));
      expect(find.byKey(const ValueKey('allophone-suffix')), findsNothing);
    });

    testWidgets('suffix appears when isAltHeld is true and realizations exist',
        (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('s'),
        isAltHeld: true,
        allophoneMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
          ],
        },
      ));
      expect(find.byKey(const ValueKey('allophone-suffix')), findsOneWidget);
      // The suffix includes the arrow + bracketed output.
      expect(find.textContaining('[ʃ]'), findsOneWidget);
    });

    testWidgets(
        'multiple realizations render comma-separated without spaces (dense format)',
        (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('s'),
        isAltHeld: true,
        allophoneMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
            AllophoneRealization(
                output: 'z', ruleSource: '', isFeatureBundle: false),
          ],
        },
      ));
      // Inline suffix uses comma-without-space to minimize chip width (D-16).
      expect(find.textContaining('[ʃ,z]'), findsOneWidget);
    });

    testWidgets(
        'tooltip contains full list with spaces as fallback for truncation',
        (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('s'),
        isAltHeld: true,
        allophoneMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
            AllophoneRealization(
                output: 'z', ruleSource: '', isFeatureBundle: false),
          ],
        },
      ));
      // The chip has a Tooltip; its message should list both outputs and
      // use the D-19 spaced format so the hover-fallback is readable.
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('ʃ'));
      expect(tooltip.message, contains('z'));
      expect(tooltip.message, contains('/s/'));
      // Spaces separator (D-19) preferred in the tooltip vs the dense
      // inline suffix.
      expect(tooltip.message, contains('ʃ, z'));
    });

    testWidgets('suffix has TextOverflow.ellipsis for truncation',
        (tester) async {
      await tester.pumpWidget(scaffold(
        phoneme: _testPhoneme('s'),
        isAltHeld: true,
        allophoneMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
          ],
        },
      ));
      final suffixText =
          tester.widget<Text>(find.byKey(const ValueKey('allophone-suffix')));
      expect(suffixText.overflow, TextOverflow.ellipsis);
      expect(suffixText.maxLines, 1);
    });
  });
}
