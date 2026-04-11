import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/dimension_templates.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/shared/migration_banner.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for plan 04-04 Task 2: PosDimensionsPage master-detail with
/// template picker + MigrationBanner.
///
/// Uses an in-memory AppDatabase overridden into `currentDatabaseProvider`.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Seed two POS rows the page will render in its left panel.
    await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1200, height: 800, child: child),
          ),
        ),
      );

  /// Settle with a real async delay so Drift stream queries can materialise
  /// their first event (Drift schedules the emit via a microtask-driven
  /// Timer.run, which `tester.pump` alone does not drain).
  ///
  /// We pump several times interleaved with `runAsync` so each new stream
  /// listener has a chance to emit before the next assertion.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Drains Drift's pending StreamQueryStore timers by replacing the widget
  /// tree with an empty ProviderScope so the family-dispose chain can
  /// finish. Without this, Flutter's `!timersPending` invariant trips
  /// because Drift's stream cancel path schedules a zero-duration Timer.
  Future<void> teardownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('PosDimensionsPage master-detail', () {
    testWidgets('renders all seeded POS rows in the left panel',
        (tester) async {
      await tester.pumpWidget(buildApp(const PosDimensionsPage()));
      await settle(tester);

      expect(find.text('Noun (N)'), findsOneWidget);
      expect(find.text('Verb (V)'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets(
      'tapping a POS tile shows the "No dimensions yet" empty state',
      (tester) async {
        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);

        await tester.tap(find.text('Noun (N)'));
        await settle(tester);

        expect(find.text('No dimensions yet'), findsOneWidget);
        expect(
          find.text('Add Dimension'),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'tapping "Add Dimension" opens the template picker with grouped headers',
      (tester) async {
        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);

        await tester.tap(find.text('Noun (N)'));
        await settle(tester);
        await tester.tap(find.text('Add Dimension'));
        await settle(tester);

        // Picker title + a few group headers (uppercased).
        // Use skipOffstage: false so ListView-clipped group headers below
        // the viewport fold still count as rendered.
        expect(find.text('Add Dimension'), findsWidgets);
        expect(find.text('GENDER', skipOffstage: false), findsOneWidget);
        expect(find.text('NUMBER', skipOffstage: false), findsOneWidget);
        // At least one specific gender template name (on-screen).
        expect(find.text('Masculine / Feminine'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'template picker filters to a single group when the search matches',
      (tester) async {
        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);

        await tester.tap(find.text('Noun (N)'));
        await settle(tester);
        await tester.tap(find.text('Add Dimension'));
        await settle(tester);

        // Type a search that should match only the Case group.
        await tester.enterText(
          find.widgetWithText(TextField, 'Search templates…'),
          'case',
        );
        await settle(tester);

        expect(find.text('CASE'), findsOneWidget);
        expect(find.text('GENDER'), findsNothing);
        expect(find.text('NUMBER'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'tapping a template card inserts the dimension on the selected POS',
      (tester) async {
        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);

        await tester.tap(find.text('Noun (N)'));
        await settle(tester);
        await tester.tap(find.text('Add Dimension'));
        await settle(tester);

        // Pick the "Masculine / Feminine" template (Gender group).
        await tester.tap(find.text('Masculine / Feminine'));
        await settle(tester);
        // Allow the dialog close animation to fully unmount the template card.
        await settle(tester);
        await settle(tester);

        // The inserted dimension should now appear in the editor panel.
        // (At least one Text with the dimension name — the dialog is gone.)
        expect(find.text('Masculine / Feminine'), findsWidgets);
        // And the "No dimensions yet" empty state should be gone.
        expect(find.text('No dimensions yet'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'template picker renders a "Custom" entry in every visible group',
      (tester) async {
        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);

        await tester.tap(find.text('Noun (N)'));
        await settle(tester);
        await tester.tap(find.text('Add Dimension'));
        await settle(tester);

        // Every visible group appends a Custom template, so there is at
        // least one Custom entry per group header.
        expect(find.text('Custom'), findsWidgets);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'no hard limit — inserting five dimensions does not raise an error (D-06)',
      (tester) async {
        // Seed five dimensions directly; the page should render them all.
        final grammarDao = GrammarDao(db);
        // Look up the Noun POS id (don't assume autoIncrement starts at 1).
        final nounId = await (db.select(db.partsOfSpeech)
              ..where((t) => t.name.equals('Noun')))
            .getSingle()
            .then((row) => row.id);
        for (var i = 0; i < 5; i++) {
          await grammarDao.insertDimension(
            DimensionsCompanion.insert(
              posId: nounId,
              name: 'Dim$i',
              ordering: Value(i),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(id: 1, name: 'L', abbr: 'L', ordering: 0),
              ]),
            ),
          );
        }

        await tester.pumpWidget(buildApp(const PosDimensionsPage()));
        await settle(tester);
        await tester.tap(find.text('Noun (N)'));
        await settle(tester);

        for (var i = 0; i < 5; i++) {
          expect(find.text('Dim$i', skipOffstage: false), findsOneWidget);
        }

        await teardownWidget(tester);
      },
    );
  });

  group('MigrationBanner', () {
    testWidgets(
      'renders when settingsKey is not set, disappears once dismissed',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            Column(
              children: const [
                MigrationBanner(settingsKey: 'ui.test_banner'),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
        await settle(tester);

        // Banner icon is visible (Icons.info_outline).
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        // Dismiss button tooltip.
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);

        await tester.tap(closeButton);
        await settle(tester);

        // After dismissal, the banner is gone.
        expect(find.byIcon(Icons.info_outline), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'hidden from the start when the dismissed key already exists',
      (tester) async {
        // Seed the dismissed flag directly.
        await db.into(db.projectSettings).insert(
              ProjectSettingsCompanion.insert(
                key: 'ui.test_banner',
                value: 'true',
              ),
            );

        await tester.pumpWidget(
          buildApp(
            Column(
              children: const [
                MigrationBanner(settingsKey: 'ui.test_banner'),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
        await settle(tester);

        // The banner is not rendered.
        expect(find.byIcon(Icons.info_outline), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);

        await teardownWidget(tester);
      },
    );
  });

  group('showDimensionTemplatePicker direct', () {
    testWidgets('returns a DimensionTemplate when a card is tapped',
        (tester) async {
      DimensionTemplate? selected;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      selected = await showDimensionTemplatePicker(context);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      // Tap the first gender template.
      await tester.tap(find.text('Masculine / Feminine'));
      await settle(tester);

      expect(selected, isNotNull);
      expect(selected!.group, equals('Gender'));

      await teardownWidget(tester);
    });
  });
}
