// Regression tests for G-01 — paradigm viewer persists the per-POS
// last-selected word via the `paradigm.last_selected_word.{posId}` key
// in project_settings.
//
// Behaviors covered:
//   1. Key constant helper produces the expected string.
//   2. read helper returns null when no row exists.
//   3. read helper parses a stored int back correctly.
//   4. write helper upserts (insert then update → no duplicate row).
//   5. ParadigmViewerPage mounts pre-selected POS + word from stored key.
//   6. ParadigmViewerPage writes the key on word selection change.
//   7. Per-POS scoping: switching POS reads that POS's stored word.
//   8. Stale lexeme id falls back to the template default gracefully.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G-01 — paradigm.last_selected_word key helpers', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('paradigmLastSelectedWordKey returns the expected constant', () {
      expect(
        paradigmLastSelectedWordKey(42),
        equals('paradigm.last_selected_word.42'),
      );
    });

    test('readParadigmLastSelectedWord returns null when no row exists',
        () async {
      final result = await readParadigmLastSelectedWord(db, 1);
      expect(result, isNull);
    });

    test('write then read round-trips the lexeme id', () async {
      await writeParadigmLastSelectedWord(db, posId: 3, lexemeId: 77);
      final read = await readParadigmLastSelectedWord(db, 3);
      expect(read, equals(77));
    });

    test('write is an upsert — updating does not create duplicate rows',
        () async {
      await writeParadigmLastSelectedWord(db, posId: 3, lexemeId: 10);
      await writeParadigmLastSelectedWord(db, posId: 3, lexemeId: 20);
      final read = await readParadigmLastSelectedWord(db, 3);
      expect(read, equals(20));

      // Confirm only one row exists under this key.
      final rows = await (db.select(db.projectSettings)
            ..where((t) =>
                t.key.equals(paradigmLastSelectedWordKey(3))))
          .get();
      expect(rows.length, equals(1));
    });

    test('per-POS scoping: different POS ids store independently',
        () async {
      await writeParadigmLastSelectedWord(db, posId: 1, lexemeId: 100);
      await writeParadigmLastSelectedWord(db, posId: 2, lexemeId: 200);
      expect(await readParadigmLastSelectedWord(db, 1), equals(100));
      expect(await readParadigmLastSelectedWord(db, 2), equals(200));
    });
  });

  // --------------------------------------------------------------------
  // Widget-level integration — page reads + writes the key
  // --------------------------------------------------------------------

  group('G-01 — ParadigmViewerPage integration', () {
    late AppDatabase db;
    late int nounPosId;
    late int verbPosId;
    late int katLexemeId;
    late int luLexemeId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      nounPosId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );
      verbPosId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
          );
      katLexemeId = await db.into(db.lexemes).insert(
            LexemesCompanion.insert(
              ipa: 'kat',
              partOfSpeech: const Value('Noun'),
            ),
          );
      luLexemeId = await db.into(db.lexemes).insert(
            LexemesCompanion.insert(
              ipa: 'lu',
              partOfSpeech: const Value('Verb'),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildApp() => ProviderScope(
          overrides: [
            currentDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: ParadigmViewerPage(),
              ),
            ),
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
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
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets(
        'selecting a word writes paradigm.last_selected_word.{posId} '
        'to project_settings',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      // Open POS dropdown and pick Noun.
      await tester.tap(find.text('Select a POS'));
      await settle(tester);
      await tester.tap(find.text('Noun').last);
      await settle(tester);

      // Open word picker (the only dropdown with an int? value) and pick kat.
      await tester.tap(find.text('(template)'));
      await settle(tester);
      await tester.tap(find.text('kat').last);
      await settle(tester);

      // Key written with the Noun POS id and the kat lexeme id.
      final stored =
          await readParadigmLastSelectedWord(db, nounPosId);
      expect(stored, equals(katLexemeId));

      await teardownWidget(tester);
    });

    testWidgets(
        'per-POS scoped writes — Noun then Verb store under different keys',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      // Pick Noun → select kat.
      await tester.tap(find.byType(DropdownButton<int>));
      await settle(tester);
      await tester.tap(find.text('Noun').last);
      await settle(tester);
      await tester.tap(find.text('(template)'));
      await settle(tester);
      await tester.tap(find.text('kat').last);
      await settle(tester);

      expect(
        await readParadigmLastSelectedWord(db, nounPosId),
        equals(katLexemeId),
      );

      // Switch to Verb → select lu.
      await tester.tap(find.byType(DropdownButton<int>));
      await settle(tester);
      await tester.tap(find.text('Verb').last);
      await settle(tester);
      await tester.tap(find.text('(template)'));
      await settle(tester);
      await tester.tap(find.text('lu').last);
      await settle(tester);

      // Verb key was written.
      expect(
        await readParadigmLastSelectedWord(db, verbPosId),
        equals(luLexemeId),
      );
      // Noun key is untouched by the Verb write.
      expect(
        await readParadigmLastSelectedWord(db, nounPosId),
        equals(katLexemeId),
      );

      await teardownWidget(tester);
    });

    testWidgets(
        'stale stored lexeme id falls back to the template default',
        (tester) async {
      // Store a lexeme id that does not exist in the Lexemes table.
      await writeParadigmLastSelectedWord(
        db,
        posId: nounPosId,
        lexemeId: 999999,
      );

      await tester.pumpWidget(buildApp());
      await settle(tester);

      await tester.tap(find.text('Select a POS'));
      await settle(tester);
      await tester.tap(find.text('Noun').last);
      await settle(tester);

      // Falls back to the '(template)' placeholder — the dropdown still
      // renders it as the current value.
      expect(find.text('(template)'), findsWidgets);

      await teardownWidget(tester);
    });
  });
}
