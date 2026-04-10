import 'package:conlang_workbench/features/phonology/data/allophone_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/allophone_computer.dart';
import 'package:conlang_workbench/features/phonology/presentation/inventory/phoneme_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests for the private _AllophoneSection inside phoneme_edit_dialog.dart.
//
// The test file accesses the private widget via the top-level
// @visibleForTesting buildAllophoneSectionForTesting helper. The
// allophoneMapProvider is overridden via ProviderScope to inject fake
// realization maps without needing a real project database.
//
// Covers Phase 3.2 D-14 (section renders in dialog), D-18 (empty state
// renders nothing), D-19 (`/symbol/ → [r1, r2]` format).

void main() {
  group('_AllophoneSection', () {
    Widget buildScaffold({
      required Map<String, List<AllophoneRealization>> overrideMap,
      required String phonemeSymbol,
    }) {
      return ProviderScope(
        overrides: [
          allophoneMapProvider.overrideWithValue(overrideMap),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: buildAllophoneSectionForTesting(phonemeSymbol),
          ),
        ),
      );
    }

    testWidgets('renders nothing when symbol has no realizations',
        (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {},
        phonemeSymbol: 's',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsNothing);
    });

    testWidgets('renders nothing when symbol is in map with empty list',
        (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {'s': <AllophoneRealization>[]},
        phonemeSymbol: 's',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsNothing);
    });

    testWidgets('renders nothing when phonemeSymbol is empty', (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {
          's': [
            AllophoneRealization(
              output: 'ʃ',
              ruleSource: 's -> ʃ / _i',
              isFeatureBundle: false,
            ),
          ],
        },
        phonemeSymbol: '',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsNothing);
    });

    testWidgets('renders D-19 format for one realization', (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {
          's': [
            AllophoneRealization(
              output: 'ʃ',
              ruleSource: 's -> ʃ / _i',
              isFeatureBundle: false,
            ),
          ],
        },
        phonemeSymbol: 's',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsOneWidget);
      expect(find.textContaining('/s/'), findsOneWidget);
      expect(find.textContaining('ʃ'), findsOneWidget);
    });

    testWidgets('renders comma-separated list for multiple realizations',
        (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
            AllophoneRealization(
                output: 'z', ruleSource: '', isFeatureBundle: false),
          ],
        },
        phonemeSymbol: 's',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsOneWidget);
      // D-19 format uses `/symbol/ → [a, b]` with comma+space separator.
      expect(find.textContaining('[ʃ, z]'), findsOneWidget);
    });

    testWidgets('missing symbol in map renders nothing (D-18 parity)',
        (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {
          's': [
            AllophoneRealization(
                output: 'ʃ', ruleSource: '', isFeatureBundle: false),
          ],
        },
        phonemeSymbol: 'k', // not in map
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsNothing);
    });

    testWidgets('feature-bundle output is rendered verbatim', (tester) async {
      await tester.pumpWidget(buildScaffold(
        overrideMap: const {
          'a': [
            AllophoneRealization(
              output: '[+nasal]',
              ruleSource: 'V -> [+nasal] / _n',
              isFeatureBundle: true,
            ),
          ],
        },
        phonemeSymbol: 'a',
      ));
      expect(find.byKey(const ValueKey('allophone-section')), findsOneWidget);
      expect(find.textContaining('[+nasal]'), findsOneWidget);
    });
  });
}
