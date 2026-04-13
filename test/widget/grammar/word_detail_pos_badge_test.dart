// Plan 04-14 Task 2 — D-64 / G-15 POS badge rendering in the derivation
// tree widget.
//
// Locks:
//   - Test 1: a derived form row for a rule with outputPosId=Noun shows a
//     compact `[N]` badge next to the form.
//   - Test 2: a second derivational rule with outputPosId=Verb renders its
//     derived form with a `[V]` badge — proves the badge comes from the
//     rule's outputPos, not a hard-coded value.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/derivation_tree_widget.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int nounPosId;
  late int verbPosId;
  late int parentId;

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
    verbPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );

    parentId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kama',
            partOfSpeech: const Value('Noun'),
            meaning: const Value('to run'),
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
            body: SizedBox(width: 1000, height: 800, child: child),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
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

  group('D-64 POS badges on derivation tree rows', () {
    testWidgets(
      'Test 1 — rule with outputPosId=Noun produces a [N] badge next to the derived form',
      (tester) async {
        // Seed a derivational rule Noun -> Noun.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Actor',
            source: '+in',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.derivational,
        );

        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(
              rootIpa: 'kama',
              rootId: parentId,
            ),
          ),
        );
        await settle(tester);

        // The POS badge for a Noun-output rule must render `[N]` somewhere
        // in the widget tree (the N abbreviation comes from the rule's
        // outputPos row).
        expect(find.text('[N]'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — rule with outputPosId=Verb produces a [V] badge',
      (tester) async {
        // Seed a derivational rule Noun -> Verb (verbalizer).
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Verbalize',
            source: '+am',
            inputPosId: Value(nounPosId),
            outputPosId: Value(verbPosId),
          ),
          RuleKind.derivational,
        );

        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(
              rootIpa: 'kama',
              rootId: parentId,
            ),
          ),
        );
        await settle(tester);

        expect(find.text('[V]'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — a parent Noun with TWO rules (Noun -> Noun + Noun -> Verb) shows BOTH badges',
      (tester) async {
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Actor',
            source: '+in',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.derivational,
        );
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Verbalize',
            source: '+am',
            inputPosId: Value(nounPosId),
            outputPosId: Value(verbPosId),
          ),
          RuleKind.derivational,
        );

        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(
              rootIpa: 'kama',
              rootId: parentId,
            ),
          ),
        );
        await settle(tester);

        expect(find.text('[N]'), findsOneWidget);
        expect(find.text('[V]'), findsOneWidget);

        await teardownWidget(tester);
      },
    );
  });
}
