// Plan 04-11 Task 4 — rules_page.dart POS-set grouping for inflectional
// mode (D-56). These tests lock the grouping algorithm + the rendered
// header order: single-POS groups first (alphabetic), then multi-POS groups
// (alphabetic), then 'Unattached' last. Multi-POS rules must appear
// EXACTLY ONCE (in their own POS-set group).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
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
  late int nounId;
  late int verbId;
  late int adjId;

  // Suppress the shared ~165px op-row overflow warning for all pumps.
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

    adjId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(
              name: 'Adjective', abbreviation: 'ADJ'),
        );
    nounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbId = await db.into(db.partsOfSpeech).insert(
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

  Future<int> insertInflectional({
    required String name,
    required Set<int> posIds,
  }) async {
    final id = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: name,
        source: 'suffix: x',
      ),
      RuleKind.inflectional,
    );
    await junctionDao.replaceForRule(ruleId: id, posIds: posIds);
    return id;
  }

  group('groupInflectionalRulesByPosSet (pure)', () {
    test('single-POS groups first then multi-POS alphabetized within tier',
        () async {
      // Insertion order is intentionally different from expected grouping
      // order — the algorithm must not rely on it.
      await insertInflectional(name: 'Plural', posIds: {nounId});
      await insertInflectional(name: 'Past', posIds: {verbId});
      await insertInflectional(name: 'Agreement', posIds: {nounId, adjId});

      final rulesList = await db.select(db.morphologicalRules).get();
      final posSetByRuleId = await junctionDao.watchAllPosSetsByRuleId().first;
      final posList = await db.select(db.partsOfSpeech).get();
      final groups = groupInflectionalRulesByPosSet(
        rules: rulesList,
        posSetByRuleId: posSetByRuleId,
        posList: posList,
      );
      // Expected order: Noun, Verb, then "Adjective + Noun"
      expect(groups.map((g) => g.header).toList(), [
        'Noun',
        'Verb',
        'Adjective + Noun',
      ]);
    });

    test('rules with no junction rows land in Unattached last', () async {
      // Insert a rule without any junction row.
      final orphanId = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Orphan',
          source: 'suffix: z',
        ),
        RuleKind.inflectional,
      );
      await insertInflectional(name: 'Plural', posIds: {nounId});

      final rules = await db.select(db.morphologicalRules).get();
      final posSetByRuleId = await junctionDao.watchAllPosSetsByRuleId().first;
      final posList = await db.select(db.partsOfSpeech).get();
      final groups = groupInflectionalRulesByPosSet(
        rules: rules,
        posSetByRuleId: posSetByRuleId,
        posList: posList,
      );

      expect(groups.last.header, 'Unattached');
      expect(groups.last.rules.map((r) => r.id), contains(orphanId));
    });
  });

  group('RulesPage inflectional mode — rendered grouping (D-56)', () {
    testWidgets(
      'Test 1 — single-POS rule renders under a single POS header',
      (tester) async {
        await insertInflectional(name: 'Plural', posIds: {nounId});

        await tester.pumpWidget(
          buildApp(const RulesPage(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        expect(find.text('NOUN'), findsOneWidget);
        expect(find.text('Plural'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — multi-POS rule renders once in its own POS-set group',
      (tester) async {
        await insertInflectional(
            name: 'Agreement', posIds: {nounId, adjId});

        await tester.pumpWidget(
          buildApp(const RulesPage(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        // Header is alphabetic by POS NAME.
        expect(find.text('ADJECTIVE + NOUN'), findsOneWidget);
        // Multi-POS rule appears EXACTLY ONCE.
        expect(find.text('Agreement'), findsOneWidget);
        // It does NOT appear under 'NOUN' or 'ADJECTIVE' single headers.
        expect(find.text('NOUN'), findsNothing);
        expect(find.text('ADJECTIVE'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — order: single-POS groups first alphabetized, then multi-POS',
      (tester) async {
        // Create rules in an order unrelated to expected header order.
        await insertInflectional(
            name: 'NumberAgr', posIds: {nounId, verbId});
        await insertInflectional(name: 'Past', posIds: {verbId});
        await insertInflectional(name: 'Plural', posIds: {nounId});
        await insertInflectional(name: 'AdjAgr', posIds: {adjId});

        await tester.pumpWidget(
          buildApp(const RulesPage(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        // Find Text widgets matching each expected header and read their
        // global rect y-coordinate to assert the visual order.
        double headerTop(String header) {
          final finder = find.text(header);
          expect(finder, findsOneWidget,
              reason: 'header "$header" should be rendered');
          return tester.getTopLeft(finder).dy;
        }

        final adjTop = headerTop('ADJECTIVE');
        final nounTop = headerTop('NOUN');
        final verbTop = headerTop('VERB');
        final multiTop = headerTop('NOUN + VERB');

        // Single-POS tier alphabetic: ADJECTIVE < NOUN < VERB
        expect(adjTop, lessThan(nounTop));
        expect(nounTop, lessThan(verbTop));
        // Multi-POS tier is after all single-POS groups.
        expect(verbTop, lessThan(multiTop));

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — Unattached group renders at the bottom for rules with no POS',
      (tester) async {
        await insertInflectional(name: 'Plural', posIds: {nounId});
        // Orphan rule with no junction rows.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Orphan',
            source: 'suffix: z',
          ),
          RuleKind.inflectional,
        );

        await tester.pumpWidget(
          buildApp(const RulesPage(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        final nounTop = tester.getTopLeft(find.text('NOUN')).dy;
        final unattachedTop =
            tester.getTopLeft(find.text('UNATTACHED')).dy;
        expect(nounTop, lessThan(unattachedTop));
        expect(find.text('Orphan'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4b — posScopeFilter restricts groups to ones containing the scope POS (D-50)',
      (tester) async {
        // Three rules: Noun-only, {Noun, Adjective}, Verb-only.
        // Scoping to Noun should show Noun + "Adjective + Noun" groups
        // and hide the Verb group entirely.
        await insertInflectional(name: 'Plural', posIds: {nounId});
        await insertInflectional(
            name: 'Agreement', posIds: {nounId, adjId});
        await insertInflectional(name: 'Past', posIds: {verbId});

        await tester.pumpWidget(
          buildApp(RulesPage(
            kind: RuleKind.inflectional,
            posScopeFilter: nounId,
          )),
        );
        await settle(tester);

        // Noun-only group + multi-POS {Adjective, Noun} group are visible.
        expect(find.text('NOUN'), findsOneWidget);
        expect(find.text('ADJECTIVE + NOUN'), findsOneWidget);
        // The Verb-only group is filtered out.
        expect(find.text('VERB'), findsNothing);
        // Plural (Noun-only) and Agreement (multi-POS) rules are visible.
        expect(find.text('Plural'), findsOneWidget);
        expect(find.text('Agreement'), findsOneWidget);
        // Past (Verb-only) is filtered out.
        expect(find.text('Past'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — derivational mode uses the existing flat list (unchanged)',
      (tester) async {
        // Insert a derivational rule with legacy posIds CSV so it's still
        // visible in the legacy path.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Agentive',
            source: 'suffix: er',
            posIds: Value('$nounId'),
          ),
          RuleKind.derivational,
        );

        await tester.pumpWidget(
          buildApp(const RulesPage(kind: RuleKind.derivational)),
        );
        await settle(tester);

        expect(find.text('Agentive'), findsOneWidget);
        // The legacy "Filter by POS" dropdown is present (unchanged).
        expect(find.text('Filter by POS:'), findsOneWidget);
        // Grouped-mode headers must NOT be present in derivational mode.
        expect(find.text('NOUN'), findsNothing);

        await teardownWidget(tester);
      },
    );
  });
}
