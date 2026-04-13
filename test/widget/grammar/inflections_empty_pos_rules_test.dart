// Plan 04-16 Task 1 — D-78 / G-06 widget test: the Inflections sub-tab
// must render the full inflectional rules list when no POS is selected,
// not the "Select a POS to view its rules." empty-state placeholder.
//
// Locks three invariants:
//   - No POS: rules pane is a RulesPage (kind=inflectional,
//     posScopeFilter=null) and the old placeholder text is GONE.
//   - No POS: the paradigm pane placeholder is UNCHANGED
//     ("Select a POS to view its paradigm.").
//   - With a POS selected: RulesPage still renders with
//     posScopeFilter = selected POS id (non-null), proving the
//     non-null branch is preserved.
//
// Uses the same in-memory AppDatabase scaffold as inflections_page_test.dart.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/grammar/presentation/inflections/inflections_page.dart';
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

  Future<({int nounId, int verbId})> seedFixture() async {
    final nounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final verbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    await db.into(db.dimensions).insert(
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
    return (nounId: nounId, verbId: verbId);
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

  group('InflectionsPage empty-POS rules pane (D-78 / plan 04-16)', () {
    testWidgets(
      'Test 1 — empty POS selection renders RulesPage (not placeholder)',
      (tester) async {
        final ids = await seedFixture();
        // Seed 3 rules: noun-only, verb-only, multi-POS.
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});
        await insertInflectionalRule(name: 'Past', posIds: {ids.verbId});
        await insertInflectionalRule(
            name: 'Agreement', posIds: {ids.nounId, ids.verbId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Placeholder must be gone.
        expect(
          find.text('Select a POS to view its rules.'),
          findsNothing,
          reason:
              'D-78: the rules pane no longer shows a placeholder before a '
              'POS is selected — it renders the full inflectional rules list.',
        );

        // RulesPage is mounted.
        expect(find.byType(RulesPage), findsOneWidget);

        // RulesPage has kind=inflectional and posScopeFilter=null.
        final rulesPage = tester.widget<RulesPage>(find.byType(RulesPage));
        expect(rulesPage.kind, RuleKind.inflectional);
        expect(rulesPage.posScopeFilter, isNull);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — paradigm pane placeholder is UNCHANGED when no POS selected',
      (tester) async {
        await seedFixture();

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // The paradigm pane still shows its own placeholder because the
        // paradigm genuinely requires a POS.
        expect(
          find.text('Select a POS to view its paradigm.'),
          findsOneWidget,
          reason:
              'D-78: only the rules pane empty-state is removed. The '
              'paradigm pane _emptyState helper must still be called with '
              'the "Select a POS to view its paradigm." message.',
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — selecting a POS preserves posScopeFilter scoping (non-null branch unchanged)',
      (tester) async {
        final ids = await seedFixture();
        await insertInflectionalRule(name: 'Plural', posIds: {ids.nounId});

        await tester.pumpWidget(buildApp(const InflectionsPage()));
        await settle(tester);

        // Open the POS dropdown and pick Noun.
        await tester.tap(find.text('Select a POS'));
        await settle(tester);
        await tester.tap(find.text('Noun').last);
        await settle(tester);

        // RulesPage remains mounted with kind=inflectional and
        // posScopeFilter=nounId (non-null branch preserved).
        final rulesPage = tester.widget<RulesPage>(find.byType(RulesPage));
        expect(rulesPage.kind, RuleKind.inflectional);
        expect(rulesPage.posScopeFilter, ids.nounId);

        await teardownWidget(tester);
      },
    );
  });
}
