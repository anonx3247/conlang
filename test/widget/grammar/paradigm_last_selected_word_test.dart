// Regression tests for G-01 — paradigm host persists the per-POS
// last-selected word via the `paradigm.last_selected_word.{posId}` key
// in project_settings.
//
// Behaviors covered:
//   1. Key constant helper produces the expected string.
//   2. read helper returns null when no row exists.
//   3. read helper parses a stored int back correctly.
//   4. write helper upserts (insert then update → no duplicate row).
//
// Plan 04-13 note: the former ParadigmViewerPage integration group (tests
// 5-8) was deleted along with paradigm_viewer_page.dart. The equivalent
// integration coverage lives in inflections_page_test.dart (the successor
// host for the paradigm rendering + last-selected-word persistence).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
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

  // Plan 04-13 — the former ParadigmViewerPage integration group was
  // deleted along with the page. The paradigm host is now InflectionsPage
  // and its G-01 coverage lives in inflections_page_test.dart.
}
