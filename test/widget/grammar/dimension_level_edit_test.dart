// Plan 04-16 Task 2 — D-79 per-level rename + D-80 add-new-level
// widget tests for DimensionEditorPanel.
//
// Locks:
//   D-79: chip edit icon opens _LevelEditDialog pre-filled with
//         name + abbr; save calls GrammarDao.updateDimensionLevels
//         with the level id + ordering PRESERVED. Empty fields
//         rejected inline. The existing onDeleted chip affordance
//         still works independently.
//   D-80: trailing + chip is visible at the end of the levels Wrap
//         (also visible when the dimension has zero levels). Tap
//         opens the same dialog with empty fields. On save, appends
//         a new DimensionLevel with id = max(existing)+1 and
//         ordering = max(existing)+1. Empty fields rejected.
//
// Uses the same in-memory AppDatabase scaffold as
// dimension_rename_test.dart.

import 'dart:convert';

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

  void Function(FlutterErrorDetails)? previousOnError;

  setUpAll(() {
    previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('A RenderFlex overflowed by')) return;
      previousOnError?.call(details);
    };
  });

  tearDownAll(() {
    FlutterError.onError = previousOnError;
  });

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
              DimensionLevel(
                  id: 0, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(
                  id: 1, name: 'Plural', abbr: 'PL', ordering: 1),
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

  Future<List<DimensionLevel>> fetchLevels(int targetDimId) async {
    final row =
        await (db.select(db.dimensions)..where((t) => t.id.equals(targetDimId)))
            .getSingle();
    return decodeLevelsJson(row.levelsJson);
  }

  Future<void> seedDimensionWithLevels(
      int theDimId, List<DimensionLevel> levels) async {
    await (db.update(db.dimensions)..where((t) => t.id.equals(theDimId)))
        .write(DimensionsCompanion(levelsJson: Value(encodeLevelsJson(levels))));
  }

  // 04-18-02: Updated finders for the new _LevelChip structure.
  // Level chips are now custom Container-based widgets (not InputChip)
  // so each icon has its own hit-test area.

  // Finder for the edit InkWell in the _LevelChip for the level whose
  // text matches [labelSubstring]. The InkWell wraps a Padding > Icon(edit).
  Finder levelChipEditInkWellFor(String labelSubstring) {
    // Find the Container Row that contains the label text, then find the
    // InkWell whose child Padding > Icon is edit_outlined.
    return find.descendant(
      of: find.ancestor(
        of: find.text(labelSubstring),
        matching: find.byType(Row),
      ),
      matching: find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.child is Padding &&
            (w.child as Padding).child is Icon &&
            ((w.child as Padding).child as Icon).icon == Icons.edit_outlined,
      ),
    );
  }

  // Tap the edit affordance via a direct call to the InkWell's onTap
  // callback. With the new _LevelChip, the InkWell has its own hit-test
  // area (no parent chip absorbing taps), but we still invoke onTap
  // directly for test reliability.
  Future<void> tapLevelChipEditIcon(
      WidgetTester tester, String labelSubstring) async {
    final inkwell = tester.widget<InkWell>(
      levelChipEditInkWellFor(labelSubstring),
    );
    inkwell.onTap!();
    await tester.pumpAndSettle();
  }

  group('D-79 — per-level rename', () {
    // Helpers for reliably addressing the two TextFields in the
    // level editor dialog. Dialog layout order is [name, abbr], so
    // index 0 = name field, index 1 = abbr field.
    Finder dialogNameField() {
      return find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(0);
    }

    Finder dialogAbbrField() {
      return find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(1);
    }

    testWidgets(
      'D-79 Test 1 — level chip edit icon opens dialog pre-filled with name and abbr',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        // Tap the edit affordance on the 'Singular (SG)' chip.
        await tapLevelChipEditIcon(tester, 'Singular (SG)');

        // Dialog is the level edit dialog (title 'Edit level').
        expect(find.text('Edit level'), findsOneWidget);

        // Dialog TextFields pre-filled with the current values.
        final nameCtl =
            tester.widget<TextField>(dialogNameField()).controller;
        final abbrCtl =
            tester.widget<TextField>(dialogAbbrField()).controller;
        expect(nameCtl?.text, equals('Singular'));
        expect(abbrCtl?.text, equals('SG'));

        // Field labels visible inside the dialog.
        expect(find.text('Level name'), findsOneWidget);
        expect(find.text('Abbreviation'), findsOneWidget);

        // Dismiss.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-79 Test 2 — save rewrites name and abbr while preserving id and ordering',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tapLevelChipEditIcon(tester, 'Singular (SG)');

        await tester.enterText(dialogNameField(), 'Uno');
        await tester.enterText(dialogAbbrField(), 'U');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await settle(tester);

        // Verify DB state: level id 0 renamed to Uno/U, ordering preserved.
        final levels = await fetchLevels(dimId);
        expect(levels.length, 2);
        final sg = levels.firstWhere((l) => l.id == 0);
        expect(sg.name, 'Uno');
        expect(sg.abbr, 'U');
        expect(sg.ordering, 0); // preserved
        // Plural level unchanged.
        final pl = levels.firstWhere((l) => l.id == 1);
        expect(pl.name, 'Plural');
        expect(pl.abbr, 'PL');
        expect(pl.ordering, 1);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-79 Test 3 — empty name rejected with inline error, DAO NOT called',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tapLevelChipEditIcon(tester, 'Singular (SG)');

        await tester.enterText(dialogNameField(), '   ');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Dialog still open.
        expect(find.text('Edit level'), findsOneWidget);
        // Inline error on Name.
        expect(find.text('Name cannot be empty'), findsOneWidget);

        // DB unchanged.
        final levels = await fetchLevels(dimId);
        expect(levels.firstWhere((l) => l.id == 0).name, 'Singular');

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-79 Test 4 — empty abbr rejected with inline error, DAO NOT called',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tapLevelChipEditIcon(tester, 'Singular (SG)');

        await tester.enterText(dialogAbbrField(), '   ');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Dialog still open, abbr error visible.
        expect(find.text('Edit level'), findsOneWidget);
        expect(find.text('Abbreviation cannot be empty'), findsOneWidget);

        // DB unchanged.
        final levels = await fetchLevels(dimId);
        expect(levels.firstWhere((l) => l.id == 0).abbr, 'SG');

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-79 Test 5 — delete affordance works (04-18-02: via close InkWell + confirm dialog)',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        // 04-18-02: Level chips are now _LevelChip (not InputChip).
        // The delete affordance is an InkWell wrapping Icon(Icons.close).
        // Tapping it shows a confirmation dialog first (T-18-02-01).
        final closeInkWell = find.descendant(
          of: find.ancestor(
            of: find.text('Plural (PL)'),
            matching: find.byType(Row),
          ),
          matching: find.byWidgetPredicate(
            (w) =>
                w is InkWell &&
                w.child is Padding &&
                (w.child as Padding).child is Icon &&
                ((w.child as Padding).child as Icon).icon == Icons.close,
          ),
        );
        expect(closeInkWell, findsWidgets,
            reason: 'D-79 must have a close/delete affordance on level chips.');

        // Tap close icon — confirmation dialog appears first.
        final inkwell = tester.widget<InkWell>(closeInkWell.first);
        inkwell.onTap!();
        await tester.pumpAndSettle();

        // Confirmation dialog visible.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Delete level?'), findsOneWidget);

        // Confirm deletion.
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await settle(tester);

        // DB now has a single-element list: Singular only.
        final levels = await fetchLevels(dimId);
        expect(levels.length, 1);
        expect(levels.first.id, 0);
        expect(levels.first.name, 'Singular');

        await teardownWidget(tester);
      },
    );
  });

  group('D-80 — add new level', () {
    testWidgets(
      'D-80 Test 6 — trailing + chip visible at end of levels Wrap',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        // The + chip is an InputChip containing an Icon(Icons.add).
        final addIcon = find.byIcon(Icons.add);
        // There is also an "Add Dimension" TextButton.icon with
        // Icons.add at the top of the panel. We just need at least
        // one 'Add level' tooltip present.
        expect(addIcon.evaluate().length, greaterThanOrEqualTo(2));

        // Tooltip 'Add level' should exist.
        expect(
          find.byTooltip('Add level'),
          findsOneWidget,
          reason: 'D-80: trailing + chip must be tooltipped "Add level"',
        );

        await teardownWidget(tester);
      },
    );

    // Dialog-scoped field finders shared with D-80 add tests.
    Finder dialogNameField() {
      return find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(0);
    }

    Finder dialogAbbrField() {
      return find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .at(1);
    }

    testWidgets(
      'D-80 Test 7 — tapping + chip opens empty _LevelEditDialog',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.tap(find.byTooltip('Add level'));
        await tester.pumpAndSettle();

        // Dialog with 'Add level' title appears.
        expect(find.text('Add level'), findsOneWidget);

        // Both dialog TextFields are empty.
        final nameCtl =
            tester.widget<TextField>(dialogNameField()).controller;
        final abbrCtl =
            tester.widget<TextField>(dialogAbbrField()).controller;
        expect(nameCtl?.text, isEmpty);
        expect(abbrCtl?.text, isEmpty);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-80 Test 8 — saving a new level appends with max(id)+1 and max(ordering)+1 '
      '(deliberately sparse seed)',
      (tester) async {
        // Re-seed with sparse ids: [{id:0, ordering:0}, {id:3, ordering:5}].
        await seedDimensionWithLevels(dimId, const [
          DimensionLevel(id: 0, name: 'Alpha', abbr: 'A', ordering: 0),
          DimensionLevel(id: 3, name: 'Beta', abbr: 'B', ordering: 5),
        ]);

        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.tap(find.byTooltip('Add level'));
        await tester.pumpAndSettle();

        // Enter values via dialog-scoped finders.
        await tester.enterText(dialogNameField(), 'Dual');
        await tester.enterText(dialogAbbrField(), 'DU');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await settle(tester);

        // DB now has 3 levels, the new one with id=4 and ordering=6.
        final levels = await fetchLevels(dimId);
        expect(levels.length, 3);
        final dual = levels.firstWhere((l) => l.name == 'Dual');
        expect(dual.id, 4); // max(0,3)+1
        expect(dual.abbr, 'DU');
        expect(dual.ordering, 6); // max(0,5)+1

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-80 Test 9 — empty fields rejected in add-new flow',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await settle(tester);

        await tester.tap(find.byTooltip('Add level'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Dialog still open, both errors visible.
        expect(find.text('Add level'), findsOneWidget);
        expect(find.text('Name cannot be empty'), findsOneWidget);
        expect(find.text('Abbreviation cannot be empty'), findsOneWidget);

        // DB unchanged (still 2 levels).
        final levels = await fetchLevels(dimId);
        expect(levels.length, 2);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await teardownWidget(tester);
      },
    );

    testWidgets(
      'D-80 Test 10 — + chip works even when dimension has zero levels '
      '(first level via + affordance)',
      (tester) async {
        // Wipe the levels array.
        await (db.update(db.dimensions)..where((t) => t.id.equals(dimId)))
            .write(DimensionsCompanion(levelsJson: Value(jsonEncode(const []))));

        await tester.pumpWidget(buildApp());
        await settle(tester);

        // + chip is visible even with zero levels.
        expect(find.byTooltip('Add level'), findsOneWidget);

        await tester.tap(find.byTooltip('Add level'));
        await tester.pumpAndSettle();

        await tester.enterText(dialogNameField(), 'Singular');
        await tester.enterText(dialogAbbrField(), 'SG');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await settle(tester);

        // First level added with id=0, ordering=0.
        final levels = await fetchLevels(dimId);
        expect(levels.length, 1);
        expect(levels.first.id, 0);
        expect(levels.first.name, 'Singular');
        expect(levels.first.abbr, 'SG');
        expect(levels.first.ordering, 0);

        await teardownWidget(tester);
      },
    );
  });
}
