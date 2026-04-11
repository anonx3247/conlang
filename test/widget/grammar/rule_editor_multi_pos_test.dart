// Plan 04-11 Task 3 — widget tests for the multi-POS picker in the
// inflectional mode of RuleEditorDialog + the junction-writing save path.
//
// These lock the D-55 contract: the dialog lets users pick MULTIPLE POS for
// a single inflectional rule, dimension chip rows show the intersection
// across the selected POS, saving writes the junction via
// InflectionalRulePOSDao.replaceForRule, and an empty POS set is a
// validation error.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
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
  late int adjPosId;
  late int numberDimNounId;
  late int numberDimAdjId;
  late int genderDimNounId; // Noun-only dimension (not in adjective's set)
  const int sgLevelId = 1;
  const int plLevelId = 2;

  // Suppress pre-existing ~165px op-row overflow warning so the kind-aware
  // behavior assertions run unobstructed. Same pattern as
  // rule_editor_dialog_kind_test.dart.
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

  Future<void> seedNounAndAdjWithNumber({bool addGenderToNoun = false}) async {
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    adjPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(
              name: 'Adjective', abbreviation: 'ADJ'),
        );

    final numberLevels = encodeLevelsJson(const [
      DimensionLevel(id: sgLevelId, name: 'Singular', abbr: 'SG', ordering: 0),
      DimensionLevel(id: plLevelId, name: 'Plural', abbr: 'PL', ordering: 1),
    ]);

    numberDimNounId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: numberLevels,
            templateId: const Value('number.sg_pl'),
          ),
        );
    numberDimAdjId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: adjPosId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: numberLevels,
            templateId: const Value('number.sg_pl'),
          ),
        );

    if (addGenderToNoun) {
      final genderLevels = encodeLevelsJson(const [
        DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
        DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
      ]);
      genderDimNounId = await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounPosId,
              name: 'Gender',
              ordering: const Value(1),
              levelsJson: genderLevels,
              templateId: const Value('gender.mf'),
            ),
          );
    }
  }

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

  group('RuleEditorDialog multi-POS picker (D-55)', () {
    testWidgets(
      'Test 1 — new inflectional rule: picker renders chips, none selected',
      (tester) async {
        await seedNounAndAdjWithNumber();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        // The multi-POS picker renders a FilterChip per POS.
        expect(find.widgetWithText(FilterChip, 'Noun (N)'), findsOneWidget);
        expect(
          find.widgetWithText(FilterChip, 'Adjective (ADJ)'),
          findsOneWidget,
        );
        // None selected initially — inline hint shown.
        expect(find.text('Select at least one POS above.'), findsOneWidget);
        // No dimension chip row is rendered (no POS selected).
        expect(find.widgetWithText(FilterChip, 'SG'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'PL'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — edit existing rule: POS set hydrated from junction',
      (tester) async {
        await seedNounAndAdjWithNumber();

        // Seed a rule attached to BOTH Noun and Adjective via the junction.
        final ruleId = await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Plural',
            source: 'suffix: s',
            featureBindings: Value(
              FeatureBindings(
                pos: [nounPosId, adjPosId],
                dims: {numberDimNounId: plLevelId},
              ),
            ),
          ),
          RuleKind.inflectional,
        );
        final junctionDao = InflectionalRulePOSDao(db);
        await junctionDao
            .replaceForRule(ruleId: ruleId, posIds: {nounPosId, adjPosId});

        final rule = await (db.select(db.morphologicalRules)
              ..where((t) => t.id.equals(ruleId)))
            .getSingle();

        await tester.pumpWidget(
          buildApp(
            RuleEditorDialog(
                kind: RuleKind.inflectional, existing: rule),
          ),
        );
        await settle(tester);
        // One more settle cycle to let the async hydration post-frame
        // callback run.
        await settle(tester);

        // Both POS chips are selected.
        final nounChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Noun (N)'),
        );
        final adjChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Adjective (ADJ)'),
        );
        expect(nounChip.selected, isTrue);
        expect(adjChip.selected, isTrue);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — tapping multiple POS chips accumulates selections',
      (tester) async {
        await seedNounAndAdjWithNumber();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);
        await tester
            .tap(find.widgetWithText(FilterChip, 'Adjective (ADJ)'));
        await settle(tester);

        final nounChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Noun (N)'),
        );
        final adjChip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Adjective (ADJ)'),
        );
        expect(nounChip.selected, isTrue);
        expect(adjChip.selected, isTrue);

        // Dimension chip rows now render — both POS share a Number dim.
        expect(find.widgetWithText(FilterChip, 'SG'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'PL'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — save with multi-POS writes junction rows for every POS in the set',
      (tester) async {
        await seedNounAndAdjWithNumber();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        // Select BOTH POS.
        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);
        await tester
            .tap(find.widgetWithText(FilterChip, 'Adjective (ADJ)'));
        await settle(tester);

        // Rule name.
        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Plural',
        );
        await settle(tester);

        // Bind Number=PL on the intersected dim row.
        await tester.tap(find.widgetWithText(FilterChip, 'PL'));
        await settle(tester);

        // Suffix value (reuse the final EditableText idiom from the existing
        // kind test — IpaTextField descendants).
        final editableTexts = find.byType(EditableText);
        await tester.enterText(editableTexts.last, 's');
        await settle(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        // Verify DB state: one rule row + TWO junction rows.
        final rules = await db.select(db.morphologicalRules).get();
        expect(rules.length, 1);
        final ruleId = rules.first.id;
        final junction = await db.select(db.inflectionalRulePOS).get();
        final pairs = junction.map((r) => (r.ruleId, r.posId)).toSet();
        expect(pairs, equals({
          (ruleId, nounPosId),
          (ruleId, adjPosId),
        }));

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — save populates legacy input_pos_id with the first selected POS',
      (tester) async {
        await seedNounAndAdjWithNumber();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);
        await tester
            .tap(find.widgetWithText(FilterChip, 'Adjective (ADJ)'));
        await settle(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Plural',
        );
        await settle(tester);
        await tester.tap(find.widgetWithText(FilterChip, 'PL'));
        await settle(tester);
        final editableTexts = find.byType(EditableText);
        await tester.enterText(editableTexts.last, 's');
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        final rule = (await db.select(db.morphologicalRules).get()).single;
        // First selected POS is written to the legacy cache. Sort order is
        // ascending (id), so whichever POS has the smaller id is expected.
        final firstSorted = ({nounPosId, adjPosId}.toList()..sort()).first;
        expect(rule.inputPosId, equals(firstSorted));

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 6 — save with empty POS set shows validation error and inserts nothing',
      (tester) async {
        await seedNounAndAdjWithNumber();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Empty',
        );
        await settle(tester);

        // Tap Save without selecting any POS.
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(
          find.textContaining(
              'At least one POS must be selected for inflectional rules'),
          findsAtLeastNWidgets(1),
        );
        final rules = await db.select(db.morphologicalRules).get();
        expect(rules, isEmpty);
        final junction = await db.select(db.inflectionalRulePOS).get();
        expect(junction, isEmpty);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 7 — intersected dimensions: Noun has Gender, Adj does not, '
      'so Gender is hidden when both are selected',
      (tester) async {
        await seedNounAndAdjWithNumber(addGenderToNoun: true);
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        // Select only Noun — Gender IS in the chip row.
        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);
        expect(find.widgetWithText(FilterChip, 'M'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'F'), findsOneWidget);

        // Add Adjective — Gender is no longer shared, so it disappears.
        await tester
            .tap(find.widgetWithText(FilterChip, 'Adjective (ADJ)'));
        await settle(tester);
        expect(find.widgetWithText(FilterChip, 'M'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'F'), findsNothing);
        // Number remains because both POS share it.
        expect(find.widgetWithText(FilterChip, 'SG'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'PL'), findsOneWidget);

        // Reference the gender dim id to keep the variable exported by the
        // seeding helper used — the test would be sufficient without this,
        // but silencing the unused-variable analyzer warning is cheap.
        expect(genderDimNounId, greaterThan(0));
        // Noun's Number dim id differs from Adjective's, but both names
        // match — the intersection shows the first-POS row (Noun).
        expect(numberDimNounId, isNot(equals(numberDimAdjId)));

        await teardownWidget(tester);
      },
    );
  });
}
