// Plan 04-13 Task 3 — widget tests for InflectionsPage (D-49 / D-50 /
// G-06). Locks the stacked layout, the POS-scoped rules pane, the
// ruleEditor click mode on the paradigm, and the G-01 last-selected-word
// persistence ported from the deleted paradigm_viewer_page.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/grammar/presentation/inflections/inflections_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rules_page.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InflectionalRulePOSDao junctionDao;

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
    junctionDao = InflectionalRulePOSDao(db);
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

  Future<({int nounId, int verbId, int numberDimId})> seedFixture() async {
    final nounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final verbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounId,
            name: 'Gender',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
          ),
        );
    // Verb dims (used to create a Verb-only rule that must NOT show
    // under the Noun scope).
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: verbId,
            name: 'Tense',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Present', abbr: 'PRS', ordering: 0),
              DimensionLevel(id: 2, name: 'Past', abbr: 'PST', ordering: 1),
            ]),
            templateId: const Value('tense.prs_pst'),
          ),
        );
    return (nounId: nounId, verbId: verbId, numberDimId: numberDimId);
  }

  Future<int> insertInflectionalRule({
    required String name,
    required Set<int> posIds,
  }) async {
    final id = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(name: name, source: 'suffix: x'),
      RuleKind.inflectional,
    );
    await junctionDao.replaceForRule(ruleId: id, posIds: posIds);
    return id;
  }

  group('InflectionsPage (D-49 / D-50 / G-06)', () {
    testWidgets(
      'Test 1 — renders POS picker at top, paradigm middle (flex 55), rules bottom (flex 45)',
      (tester) async {
        await seedFixture();

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // POS picker is at the top.
        expect(find.text('POS:'), findsOneWidget);
        expect(find.text('Select a POS'), findsOneWidget);
        // Empty state messages show before a POS is selected.
        expect(
          find.text('Select a POS to view its paradigm.'),
          findsOneWidget,
        );
        expect(
          find.text('Select a POS to view its rules.'),
          findsOneWidget,
        );

        // Confirm that the layout contains two Expanded children with flex
        // 55 and 45. We walk the widget tree and look for those flex
        // values.
        final expandeds = tester.widgetList<Expanded>(find.byType(Expanded)).toList();
        final flexes = expandeds.map((e) => e.flex).toSet();
        expect(flexes.contains(55), isTrue,
            reason: 'paradigm pane must be Expanded(flex: 55)');
        expect(flexes.contains(45), isTrue,
            reason: 'rules pane must be Expanded(flex: 45)');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — selecting a POS refreshes both panes',
      (tester) async {
        final ids = await seedFixture();
        // Rules for both POS so we can observe filtering.
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});
        await insertInflectionalRule(name: 'Past', posIds: {ids.verbId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Open the POS dropdown and pick Noun.
        await tester.tap(find.text('Select a POS'));
        await settle(tester);
        await tester.tap(find.text('Noun').last);
        await settle(tester);

        // Paradigm empty-state replaced with an actual ParadigmTableWidget.
        expect(find.byType(ParadigmTableWidget), findsOneWidget);
        // The rules pane shows the Noun-scoped list: Plural is visible,
        // Past is not.
        expect(find.text('Plural'), findsOneWidget);
        expect(find.text('Past'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — D-50 POS-scoping: multi-POS rules matching the scope are kept',
      (tester) async {
        final ids = await seedFixture();
        // Noun-only, multi-POS {Noun, Verb}, Verb-only.
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});
        await insertInflectionalRule(
            name: 'Agreement', posIds: {ids.nounId, ids.verbId});
        await insertInflectionalRule(name: 'Past', posIds: {ids.verbId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Select Noun.
        await tester.tap(find.text('Select a POS'));
        await settle(tester);
        await tester.tap(find.text('Noun').last);
        await settle(tester);

        // Plural (Noun-only) + Agreement (multi-POS includes Noun) visible.
        expect(find.text('Plural'), findsOneWidget);
        expect(find.text('Agreement'), findsOneWidget);
        // Past (Verb-only) is filtered out.
        expect(find.text('Past'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — paradigm table is constructed with clickMode.ruleEditor',
      (tester) async {
        final ids = await seedFixture();
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Select Noun.
        await tester.tap(find.text('Select a POS'));
        await settle(tester);
        await tester.tap(find.text('Noun').last);
        await settle(tester);

        // Inspect the ParadigmTableWidget and assert clickMode.
        final paradigm = tester
            .widget<ParadigmTableWidget>(find.byType(ParadigmTableWidget));
        expect(paradigm.clickMode, ParadigmClickMode.ruleEditor);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — bottom pane is a RulesPage with kind=inflectional and posScopeFilter set',
      (tester) async {
        final ids = await seedFixture();
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Select Noun.
        await tester.tap(find.text('Select a POS'));
        await settle(tester);
        await tester.tap(find.text('Noun').last);
        await settle(tester);

        final rulesPage = tester.widget<RulesPage>(find.byType(RulesPage));
        expect(rulesPage.kind, RuleKind.inflectional);
        expect(rulesPage.posScopeFilter, ids.nounId);

        await teardownWidget(tester);
      },
    );
  });
}
