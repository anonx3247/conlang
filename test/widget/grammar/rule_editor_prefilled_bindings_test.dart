// Plan 04-13 Task 1 — widget tests for RuleEditorDialog.preFilledBindings
// (D-51). When a user clicks a paradigm cell in the Grammar > Inflections
// sub-tab, the RuleEditorDialog opens pre-seeded with the cell's feature
// bindings so "new rule for this cell" is a one-click affordance.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int nounPosId;
  late int numberDimId;
  const int sgLevelId = 1;
  const int plLevelId = 2;

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
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: sgLevelId, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(
                  id: plLevelId, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
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

  group('RuleEditorDialog.preFilledBindings (D-51)', () {
    testWidgets(
      'Test 1 — preFilledBindings seeds _featureBindings on new rule',
      (tester) async {
        // Open dialog with preFilledBindings for PL on the Number dim.
        // The dialog should auto-select Noun (already selected via the
        // pre-fill path in Task 2 — but here we only verify the chip state
        // for the inflectional dimension chip picker). Since Task 1 only
        // seeds _featureBindings on mount, we pump with the Noun chip
        // already tapped to expose the chip rows, then assert the PL chip
        // is selected without any user interaction.
        await tester.pumpWidget(
          buildApp(
            RuleEditorDialog(
              kind: RuleKind.inflectional,
              preFilledBindings: {numberDimId: plLevelId},
            ),
          ),
        );
        await settle(tester);

        // Select the Noun POS chip so the dimension chip rows become visible.
        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);

        // The PL chip should be pre-selected (isSelected == true).
        final plChipFinder = find.widgetWithText(FilterChip, 'PL');
        expect(plChipFinder, findsOneWidget);
        final plChip = tester.widget<FilterChip>(plChipFinder);
        expect(plChip.selected, isTrue,
            reason: 'PL chip should be pre-selected from preFilledBindings');

        // The SG chip should NOT be pre-selected.
        final sgChip =
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'SG'));
        expect(sgChip.selected, isFalse);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — preFilledBindings ignored when existing is non-null',
      (tester) async {
        // Seed an existing rule with SG binding.
        final ruleId = await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Existing SG',
            source: 'suffix: s',
            featureBindings: Value(
              FeatureBindings(
                  pos: [nounPosId], dims: {numberDimId: sgLevelId}),
            ),
          ),
          RuleKind.inflectional,
        );
        final row = await (db.select(db.morphologicalRules)
              ..where((t) => t.id.equals(ruleId)))
            .getSingle();

        // Open dialog with BOTH existing and preFilledBindings. Existing
        // should win — SG is selected, PL is NOT.
        await tester.pumpWidget(
          buildApp(
            RuleEditorDialog(
              kind: RuleKind.inflectional,
              existing: row,
              preFilledBindings: {numberDimId: plLevelId},
            ),
          ),
        );
        await settle(tester);

        final sgChip =
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'SG'));
        final plChip =
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'PL'));
        expect(sgChip.selected, isTrue,
            reason: 'existing rule bindings win over preFilledBindings');
        expect(plChip.selected, isFalse,
            reason: 'preFilledBindings must be ignored in edit mode');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — preFilledBindings ignored for derivational kind',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            RuleEditorDialog(
              kind: RuleKind.derivational,
              preFilledBindings: {numberDimId: plLevelId},
            ),
          ),
        );
        await settle(tester);

        // Derivational mode has no chip rows — the Input/Output POS
        // dropdowns are shown instead.
        expect(find.text('Input POS'), findsOneWidget);
        expect(find.text('Output POS'), findsOneWidget);
        // SG/PL chips should not be rendered at all in derivational mode.
        expect(find.widgetWithText(FilterChip, 'SG'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'PL'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — null preFilledBindings preserves legacy behavior',
      (tester) async {
        // This is the pre-Task-1 code path: no pre-fill at all. The dialog
        // opens with no POS selected, no chips visible until the user taps
        // a POS chip, and no bindings seeded.
        await tester.pumpWidget(
          buildApp(
            const RuleEditorDialog(kind: RuleKind.inflectional),
          ),
        );
        await settle(tester);

        // Select the Noun POS chip to expose the dimension chip rows.
        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);

        // Neither SG nor PL should be pre-selected without a pre-fill.
        final sgChip =
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'SG'));
        final plChip =
            tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'PL'));
        expect(sgChip.selected, isFalse);
        expect(plChip.selected, isFalse);

        await teardownWidget(tester);
      },
    );
  });
}
