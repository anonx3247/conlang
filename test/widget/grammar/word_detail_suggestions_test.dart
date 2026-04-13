// Plan 04-14 Task 3 — D-60 / G-19 Suggestions chips in the word detail
// panel.
//
// Locks:
//   - Test 1: the Suggestions section header renders above the chip list.
//   - Test 2: the chip list matches `autoApply=false` derivational rules
//     whose inputPosId equals the lexeme's POS. `autoApply=true` rules are
//     excluded (they are already auto-promoted). Rules for a different POS
//     are excluded too.
//   - Test 3: after a chip is clicked, it promotes the derivation and the
//     chip disappears from the suggestion list on the next rebuild (a
//     promoted Lexeme row exists for the (parent, rule) pair).
//   - Test 4: clicking a chip calls `LexemeDao.promoteDerivation` with an
//     empty gloss — the user then fills in the meaning via the derivation
//     tree row's meaning field (Task 2 flow).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_detail_panel.dart';
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

  Future<Lexeme> loadLexeme(int id) async {
    return (db.select(db.lexemes)..where((t) => t.id.equals(id))).getSingle();
  }

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

  group('D-60 Suggestions section', () {
    testWidgets(
      'Test 1 — Suggestions header visible when at least one matching autoApply=false rule exists',
      (tester) async {
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Actor',
            source: '+in',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
            autoApply: const Value(false),
          ),
          RuleKind.derivational,
        );

        final parent = await loadLexeme(parentId);
        await tester.pumpWidget(
          buildApp(WordDetailSuggestionsSection(lexeme: parent)),
        );
        await settle(tester);

        expect(find.text('Suggestions'), findsOneWidget);
        // The chip for the Actor rule must be visible.
        expect(
          find.widgetWithText(ActionChip, 'Actor'),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — autoApply=true rules and wrong-POS rules are excluded',
      (tester) async {
        // Rule A: Noun + autoApply=false -> appears.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Actor',
            source: '+in',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
            autoApply: const Value(false),
          ),
          RuleKind.derivational,
        );
        // Rule B: Noun + autoApply=true -> excluded (already auto-promoted).
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'AutoB',
            source: '+ot',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
            autoApply: const Value(true),
          ),
          RuleKind.derivational,
        );
        // Rule C: Verb + autoApply=false -> excluded (wrong POS).
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'VerbOnly',
            source: '+at',
            inputPosId: Value(verbPosId),
            outputPosId: Value(verbPosId),
            autoApply: const Value(false),
          ),
          RuleKind.derivational,
        );

        final parent = await loadLexeme(parentId);
        await tester.pumpWidget(
          buildApp(WordDetailSuggestionsSection(lexeme: parent)),
        );
        await settle(tester);

        expect(find.widgetWithText(ActionChip, 'Actor'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, 'AutoB'), findsNothing);
        expect(find.widgetWithText(ActionChip, 'VerbOnly'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — clicking a chip promotes with empty gloss and the chip disappears',
      (tester) async {
        final ruleId = await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Actor',
            source: '+in',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
            autoApply: const Value(false),
          ),
          RuleKind.derivational,
        );

        final parent = await loadLexeme(parentId);
        await tester.pumpWidget(
          buildApp(WordDetailSuggestionsSection(lexeme: parent)),
        );
        await settle(tester);

        await tester.tap(find.widgetWithText(ActionChip, 'Actor'));
        await settle(tester);

        // A new Lexeme row with the linkage must exist.
        final promoted = await (db.select(db.lexemes)
              ..where((t) =>
                  t.derivedFromLexemeId.equals(parentId) &
                  t.derivedViaRuleId.equals(ruleId)))
            .get();
        expect(promoted.length, 1);
        expect(promoted.first.meaning ?? '', isEmpty,
            reason: 'D-60: chip click promotes with empty gloss — the user '
                'fills in the meaning via the derivation tree row');

        // After the promotion the chip must disappear on the next rebuild.
        expect(find.widgetWithText(ActionChip, 'Actor'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — when zero matching rules exist, the Suggestions section is hidden',
      (tester) async {
        final parent = await loadLexeme(parentId);
        await tester.pumpWidget(
          buildApp(WordDetailSuggestionsSection(lexeme: parent)),
        );
        await settle(tester);

        expect(find.text('Suggestions'), findsNothing);

        await teardownWidget(tester);
      },
    );
  });
}
