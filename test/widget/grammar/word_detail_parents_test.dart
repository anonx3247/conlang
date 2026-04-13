// Plan 04-14 Task 3 — D-62 / G-17 Parents / Etymology section in the word
// detail panel.
//
// Locks:
//   - Test 1: when `LexemeParents` rows exist for the child, the Parents
//     section header renders with one row per parent (romanization + gloss).
//   - Test 2: a parent row with a non-null `relationship` column surfaces
//     the relationship label.
//   - Test 3: a lexeme with ZERO parent links does NOT render the Parents
//     section (header hidden to avoid empty-section clutter).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/lexeme_parents_dao.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_detail_panel.dart';
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

  Future<Lexeme> insertLexeme({
    required String ipa,
    String? romanization,
    String? meaning,
    String? pos,
  }) async {
    final id = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: ipa,
            romanization: Value(romanization),
            meaning: Value(meaning),
            partOfSpeech: Value(pos),
          ),
        );
    return (db.select(db.lexemes)..where((t) => t.id.equals(id))).getSingle();
  }

  group('D-62 Parents / Etymology section', () {
    testWidgets(
      'Test 1 — Parents header + parent rows render for a child with LexemeParents rows',
      (tester) async {
        final p1 = await insertLexeme(
            ipa: 'kama', romanization: 'kama', meaning: 'to run');
        final p2 = await insertLexeme(
            ipa: 'lir', romanization: 'lir', meaning: 'fast');
        final child = await insertLexeme(
            ipa: 'kamalir',
            romanization: 'kamalir',
            meaning: 'sprinter');

        final parentsDao = LexemeParentsDao(db);
        await parentsDao.insertParent(
            childLexemeId: child.id, parentLexemeId: p1.id);
        await parentsDao.insertParent(
            childLexemeId: child.id, parentLexemeId: p2.id);

        await tester.pumpWidget(
          buildApp(WordDetailParentsSection(lexeme: child)),
        );
        await settle(tester);

        expect(find.text('Parents'), findsOneWidget);
        expect(find.textContaining('kama'), findsWidgets);
        expect(find.textContaining('lir'), findsWidgets);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — a parent row with a non-null relationship label surfaces the label',
      (tester) async {
        final parent = await insertLexeme(
            ipa: 'kama', romanization: 'kama', meaning: 'to run');
        final child = await insertLexeme(
            ipa: 'kamain',
            romanization: 'kamain',
            meaning: 'runner');

        final parentsDao = LexemeParentsDao(db);
        await parentsDao.insertParent(
          childLexemeId: child.id,
          parentLexemeId: parent.id,
          relationship: 'borrowing',
        );

        await tester.pumpWidget(
          buildApp(WordDetailParentsSection(lexeme: child)),
        );
        await settle(tester);

        expect(find.textContaining('borrowing'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — child with ZERO parent rows hides the Parents header',
      (tester) async {
        final child = await insertLexeme(
            ipa: 'root', romanization: 'root', meaning: 'root');

        await tester.pumpWidget(
          buildApp(WordDetailParentsSection(lexeme: child)),
        );
        await settle(tester);

        expect(find.text('Parents'), findsNothing);

        await teardownWidget(tester);
      },
    );
  });
}
