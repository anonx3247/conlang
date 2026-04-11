// Plan 04-14 Task 2 — D-57 / G-14 per-derivation meaning field in the
// derivation tree widget.
//
// Locks:
//   - Test 1: a computed-only derivation row shows an empty meaning TextField
//     with the placeholder hint "Add meaning to save…".
//   - Test 2: typing a meaning + onSubmitted triggers
//     LexemeDao.promoteDerivation — a Lexeme row with
//     derivedFromLexemeId=parent AND derivedViaRuleId=rule exists afterwards.
//   - Test 3: editing meaning on an already-promoted row does NOT touch
//     derivedViaRuleId (the rule link stays intact — see the implicit-detach
//     test suite for the form-edit detach path).

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
  late int parentId;
  late int ruleId;

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

    parentId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kama',
            partOfSpeech: const Value('Noun'),
            meaning: const Value('to run'),
          ),
        );

    ruleId = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'Actor',
        source: '+in',
        inputPosId: Value(nounPosId),
        outputPosId: Value(nounPosId),
      ),
      RuleKind.derivational,
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

  group('D-57 per-derivation meaning field', () {
    testWidgets(
      'Test 1 — computed-only row shows the "Add meaning to save…" hint',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(rootIpa: 'kama', rootId: parentId),
          ),
        );
        await settle(tester);

        // The hint text is rendered inside the inline meaning TextField for
        // computed (unpromoted) derivation rows.
        expect(find.text('Add meaning to save…'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — typing a meaning + submit promotes the derivation via LexemeDao',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(rootIpa: 'kama', rootId: parentId),
          ),
        );
        await settle(tester);

        // Find the meaning TextField by hint and enter a value.
        final field = find.widgetWithText(TextField, 'Add meaning to save…');
        expect(field, findsOneWidget);
        await tester.enterText(field, 'runner');
        await settle(tester);
        // Trigger onSubmitted.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        // Verify: a new Lexeme row exists with the derivedFromLexemeId +
        // derivedViaRuleId linkage and meaning="runner".
        final rows = await (db.select(db.lexemes)
              ..where((t) =>
                  t.derivedFromLexemeId.equals(parentId) &
                  t.derivedViaRuleId.equals(ruleId)))
            .get();
        expect(rows.length, 1,
            reason:
                'typing a meaning into the empty field should promote the '
                'computed derivation to a full Lexeme row');
        expect(rows.first.meaning, equals('runner'));

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — editing meaning on an already-promoted row does NOT null derivedViaRuleId',
      (tester) async {
        // Pre-promote a row.
        final promotedId = await db.lexemeDao.promoteDerivation(
          parentId: parentId,
          ruleId: ruleId,
          gloss: 'runner',
        );

        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(rootIpa: 'kama', rootId: parentId),
          ),
        );
        await settle(tester);

        // Find all TextFields in the tree; the meaning field for a promoted
        // row should contain 'runner' as its current text.
        final runnerField = find.widgetWithText(TextField, 'runner');
        expect(runnerField, findsOneWidget);
        await tester.enterText(runnerField, 'sprinter');
        await settle(tester);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        final row = await (db.select(db.lexemes)
              ..where((t) => t.id.equals(promotedId)))
            .getSingle();
        expect(row.meaning, equals('sprinter'));
        expect(row.derivedViaRuleId, equals(ruleId),
            reason:
                'meaning-only edits must never implicitly detach from the rule');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — clearing a promoted row\'s meaning opens a demote confirmation dialog',
      (tester) async {
        await db.lexemeDao.promoteDerivation(
          parentId: parentId,
          ruleId: ruleId,
          gloss: 'runner',
        );

        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(rootIpa: 'kama', rootId: parentId),
          ),
        );
        await settle(tester);

        final runnerField = find.widgetWithText(TextField, 'runner');
        expect(runnerField, findsOneWidget);
        await tester.enterText(runnerField, '');
        await settle(tester);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        // A confirmation dialog should appear asking whether to demote.
        expect(
          find.textContaining('Remove this derivation'),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );
  });
}
