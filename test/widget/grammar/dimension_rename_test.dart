// Regression tests for G-11 — DimensionEditorPanel rename affordance.
//
// Behaviors covered:
//   1. Each dimension card renders a rename IconButton (edit_outlined)
//      next to the delete button.
//   2. Tapping the rename icon opens an AlertDialog with a TextField
//      prefilled with the current dimension name.
//   3. Saving a new name calls GrammarDao.updateDimension and the
//      dimension row reflects the new name.
//   4. Saving an empty name shows an inline error and does NOT commit.
//
// Uses an in-memory AppDatabase overridden into currentDatabaseProvider,
// following the pattern in pos_dimensions_page_test.dart.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int posId;
  late int dimId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    dimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: DimensionEditorPanel(posId: posId),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> teardownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Dimension> fetchDim() async {
    return (db.select(db.dimensions)..where((t) => t.id.equals(dimId)))
        .getSingle();
  }

  // Finder for the dimension rename IconButton (the card-header edit
  // button with tooltip 'Rename dimension'). Disambiguates from the
  // per-level chip edit icons added in plan 04-16 D-79.
  Finder renameDimensionButton() => find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            w.tooltip == 'Rename dimension' &&
            w.icon is Icon &&
            (w.icon as Icon).icon == Icons.edit_outlined,
      );

  group('G-11 — rename dimension UI', () {
    testWidgets(
        'renders an edit_outlined rename IconButton on each dimension card',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Number'), findsOneWidget);
      // Exactly one 'Rename dimension' IconButton per card.
      expect(renameDimensionButton(), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets(
        'tapping rename opens AlertDialog with TextField prefilled with '
        'current name',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      await tester.tap(renameDimensionButton());
      await tester.pumpAndSettle();

      expect(find.text('Rename dimension'), findsOneWidget);
      // The rename dialog contains exactly one TextField (the
      // dimension name field). Disambiguated from the level editor
      // dialog which has two TextFields.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('Number'));

      await teardownWidget(tester);
    });

    testWidgets(
        'saving a new name persists via GrammarDao.updateDimension and '
        'updates the card',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      await tester.tap(renameDimensionButton());
      await tester.pumpAndSettle();

      // Clear the field and type the new name.
      await tester.enterText(find.byType(TextField), 'Grammatical Number');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await settle(tester);

      // DB row reflects the new name.
      final dim = await fetchDim();
      expect(dim.name, equals('Grammatical Number'));

      // Card text updates.
      expect(find.text('Grammatical Number'), findsOneWidget);
      expect(find.text('Number'), findsNothing);

      await teardownWidget(tester);
    });

    testWidgets(
        'saving empty name shows inline error and does NOT call DAO',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      await tester.tap(renameDimensionButton());
      await tester.pumpAndSettle();

      // Clear the text field.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Dialog still open.
      expect(find.text('Rename dimension'), findsOneWidget);
      // Inline error appears.
      expect(find.text('Name cannot be empty'), findsOneWidget);

      // DB still has the original name.
      final dim = await fetchDim();
      expect(dim.name, equals('Number'));

      // Dismiss dialog so teardown is clean.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await teardownWidget(tester);
    });
  });
}
