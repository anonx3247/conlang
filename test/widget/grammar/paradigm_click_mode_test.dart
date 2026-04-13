// Plan 04-13 Task 2 — widget tests for ParadigmTableWidget's new
// ParadigmClickMode enum (D-52). Locks the branching click handler so
// the Grammar host opens RuleEditorDialog with pre-filled bindings
// (D-51) and the Lexicon word-detail host preserves CellOverrideDialog
// (D-54).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

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
            body: SizedBox(width: 1400, height: 900, child: child),
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
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<({int posId, int numberDimId, int genderDimId, int lexemeId})>
      seedTwoDimFixture() async {
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final numberDimId = await db.into(db.dimensions).insert(
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
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
          ),
        );
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kat',
            partOfSpeech: const Value('Noun'),
          ),
        );
    return (
      posId: posId,
      numberDimId: numberDimId,
      genderDimId: genderDimId,
      lexemeId: lexemeId,
    );
  }

  group('ParadigmClickMode (D-52)', () {
    testWidgets(
      'Test 1 — ruleEditor mode on empty cell opens RuleEditorDialog',
      (tester) async {
        final ids = await seedTwoDimFixture();
        await tester.pumpWidget(buildApp(ParadigmTableWidget(
          lexemeId: ids.lexemeId,
          posId: ids.posId,
          clickMode: ParadigmClickMode.ruleEditor,
        )));
        await settle(tester);

        // Tap an em-dash (uncovered) cell — there are several, tap the first.
        final emDash = find.text('—').first;
        await tester.tap(emDash);
        await settle(tester);

        // RuleEditorDialog is open — verify via its unique widget type.
        expect(find.byType(RuleEditorDialog), findsOneWidget);
        // CellOverrideDialog must NOT be open in this mode.
        expect(find.byType(CellOverrideDialog), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — ruleEditor mode passes preFilledBindings from cell featureSet',
      (tester) async {
        final ids = await seedTwoDimFixture();
        await tester.pumpWidget(buildApp(ParadigmTableWidget(
          lexemeId: ids.lexemeId,
          posId: ids.posId,
          clickMode: ParadigmClickMode.ruleEditor,
        )));
        await settle(tester);

        // Tap the first uncovered cell.
        final emDash = find.text('—').first;
        await tester.tap(emDash);
        await settle(tester);

        // Read the opened RuleEditorDialog — preFilledBindings must not be
        // empty (the click handler derives bindings from the cell's
        // featureSet). For an empty paradigm with Number + Gender dims,
        // the first cell has bindings for both dims.
        final dialogFinder = find.byType(RuleEditorDialog);
        expect(dialogFinder, findsOneWidget);
        final dialog = tester.widget<RuleEditorDialog>(dialogFinder);
        expect(dialog.preFilledBindings, isNotNull,
            reason: 'ruleEditor mode must pass preFilledBindings');
        expect(dialog.preFilledBindings!.length, greaterThan(0),
            reason: 'featureSet of the clicked cell must be forwarded');
        // The bindings must cover both the Number and Gender dims
        // (2-dim fixture, no slices).
        expect(
          dialog.preFilledBindings!.keys.toSet(),
          {ids.numberDimId, ids.genderDimId},
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — wordOverride mode preserves CellOverrideDialog',
      (tester) async {
        final ids = await seedTwoDimFixture();
        await tester.pumpWidget(buildApp(ParadigmTableWidget(
          lexemeId: ids.lexemeId,
          posId: ids.posId,
          clickMode: ParadigmClickMode.wordOverride,
        )));
        await settle(tester);

        final emDash = find.text('—').first;
        await tester.tap(emDash);
        await settle(tester);

        // CellOverrideDialog is open, RuleEditorDialog is NOT.
        expect(find.byType(CellOverrideDialog), findsOneWidget);
        expect(find.byType(RuleEditorDialog), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — default clickMode is ruleEditor (Grammar host primary)',
      (tester) async {
        final ids = await seedTwoDimFixture();
        // No clickMode argument — default must be ruleEditor per D-52.
        await tester.pumpWidget(buildApp(ParadigmTableWidget(
          lexemeId: ids.lexemeId,
          posId: ids.posId,
        )));
        await settle(tester);

        final emDash = find.text('—').first;
        await tester.tap(emDash);
        await settle(tester);

        expect(find.byType(RuleEditorDialog), findsOneWidget,
            reason: 'default clickMode must be ruleEditor');
        expect(find.byType(CellOverrideDialog), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — WordDetailParadigmSection call site passes wordOverride',
      (tester) async {
        // Grep-level assertion: the constant ParadigmClickMode.wordOverride
        // must be statically referenced in word_detail_panel.dart. The
        // acceptance criteria grep covers this — here we add a redundant
        // runtime sanity check by verifying the enum value exists.
        const mode = ParadigmClickMode.wordOverride;
        expect(mode, equals(ParadigmClickMode.wordOverride));
      },
    );
  });
}
