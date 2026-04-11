// Plan 04-14 Task 2 — D-58 / G-14 implicit-detach warning on the derivation
// tree widget.
//
// Locks:
//   - Test 1: promoted + rule-linked rows show a "linked to rule" affordance
//     (tooltip / icon) tied to the source rule's name.
//   - Test 2: tapping the rom/ipa edit icon on a promoted + rule-linked row
//     opens an AlertDialog containing the phrase "Unlink from rule".
//   - Test 3: confirming the detach dialog + entering a new ipa calls
//     LexemeDao.detachFromRule — the row's derivedViaRuleId becomes null
//     AND the new ipa is persisted.
//   - Test 4: editing meaning on a promoted row does NOT show the detach
//     warning and does NOT null derivedViaRuleId (the negative case — locks
//     the behavioral boundary between meaning and form edits).
//   - Test 5: D-58 100-lexeme-constraint surface — when a rule's DSL changes,
//     the derivation tree widget re-renders with the new computed form.

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

  group('D-58 implicit-detach warning + meaning-safety', () {
    testWidgets(
      'Test 1 — promoted+rule-linked rows surface a "linked to rule" affordance',
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

        // The link affordance (Tooltip message or visible text) contains
        // the substring "linked to rule".
        expect(
          find.byWidgetPredicate((w) =>
              w is Tooltip && (w.message ?? '').contains('linked to rule')),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — tapping the form-edit icon on a promoted+rule-linked row opens the Unlink dialog',
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

        // The form-edit icon is an Icons.edit IconButton on the promoted row.
        final editBtns = find.byTooltip('Edit form');
        expect(editBtns, findsOneWidget);
        await tester.tap(editBtns);
        await settle(tester);

        // The detach warning dialog contains "Unlink from rule".
        expect(find.textContaining('Unlink from rule'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — confirming the detach warning + entering a new IPA nulls derivedViaRuleId and persists the new form',
      (tester) async {
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

        // Open the form-edit affordance.
        await tester.tap(find.byTooltip('Edit form'));
        await settle(tester);

        // Confirm the detach warning.
        await tester.tap(find.widgetWithText(FilledButton, 'Unlink and edit'));
        await settle(tester);

        // The form-edit dialog should now be open with IPA + rom fields.
        final ipaField = find.widgetWithText(TextField, 'IPA');
        expect(ipaField, findsOneWidget);
        await tester.enterText(ipaField, 'kamajr');
        await settle(tester);

        // Save the form edit.
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        final row = await (db.select(db.lexemes)
              ..where((t) => t.id.equals(promotedId)))
            .getSingle();
        expect(row.ipa, equals('kamajr'));
        expect(row.derivedViaRuleId, isNull,
            reason: 'confirmed detach must null derivedViaRuleId');
        expect(row.derivedFromLexemeId, equals(parentId),
            reason: 'parent link must be preserved');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — meaning edit on a promoted row does NOT trigger the detach warning and does NOT null derivedViaRuleId',
      (tester) async {
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

        // Edit the meaning field directly — no detach warning must appear.
        final runnerField = find.widgetWithText(TextField, 'runner');
        expect(runnerField, findsOneWidget);
        await tester.enterText(runnerField, 'sprinter');
        await settle(tester);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        // No Unlink dialog must be visible.
        expect(find.textContaining('Unlink from rule'), findsNothing);

        final row = await (db.select(db.lexemes)
              ..where((t) => t.id.equals(promotedId)))
            .getSingle();
        expect(row.meaning, equals('sprinter'));
        expect(row.derivedViaRuleId, equals(ruleId),
            reason: 'meaning edits must NOT implicitly detach from the rule');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — rule DSL edit propagates reactively to the derivation tree widget',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            DerivationTreeWidget(rootIpa: 'kama', rootId: parentId),
          ),
        );
        await settle(tester);

        // Initial computed derived form: "kamain" (kama + suffix:in).
        expect(find.textContaining('kamain'), findsOneWidget);

        // Edit the rule: replace 'in' with 'il'.
        final rule = await (db.select(db.morphologicalRules)
              ..where((t) => t.id.equals(ruleId)))
            .getSingle();
        await db.morphologyDao.updateRule(rule.copyWith(source: '+il'));
        await settle(tester);

        // The widget should re-render with the new computed form "kamail".
        expect(find.textContaining('kamail'), findsOneWidget);

        await teardownWidget(tester);
      },
    );
  });
}
