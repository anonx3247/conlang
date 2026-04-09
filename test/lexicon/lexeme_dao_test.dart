import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/lexicon/data/lexeme_dao.dart';

/// Creates an in-memory AppDatabase for testing.
AppDatabase openTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;
  late LexemeDao dao;

  setUp(() {
    db = openTestDatabase();
    dao = db.lexemeDao;
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // Test 1: watchRoots returns only lexemes where rootId IS NULL
  // -------------------------------------------------------------------------
  test('watchRoots returns only root lexemes (rootId IS NULL) ordered by ipa',
      () async {
    // Insert a root
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('bana'),
        meaning: const Value('tree'),
        partOfSpeech: const Value('noun'),
      ),
    );
    // Insert a derived form (has rootId)
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('banakin'),
        rootId: const Value('1'),
        meaning: const Value('little tree'),
        partOfSpeech: const Value('noun'),
      ),
    );
    // Insert another root
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('aka'),
        meaning: const Value('water'),
        partOfSpeech: const Value('noun'),
      ),
    );

    final roots = await dao.watchRoots().first;
    expect(roots.length, 2);
    // Should be ordered by IPA ascending: 'aka' before 'bana'
    expect(roots[0].ipa, 'aka');
    expect(roots[1].ipa, 'bana');
  });

  // -------------------------------------------------------------------------
  // Test 2: watchDerivedForms returns forms with matching rootId
  // -------------------------------------------------------------------------
  test('watchDerivedForms returns only lexemes with matching rootId', () async {
    final rootId = await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('kal'),
        meaning: const Value('run'),
        partOfSpeech: const Value('verb'),
      ),
    );

    // Derived from root
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('kalas'),
        rootId: Value(rootId.toString()),
        meaning: const Value('runner'),
        partOfSpeech: const Value('noun'),
      ),
    );
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('kaling'),
        rootId: Value(rootId.toString()),
        meaning: const Value('running'),
        partOfSpeech: const Value('noun'),
      ),
    );
    // Unrelated lexeme
    await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('mati'),
        meaning: const Value('stone'),
        partOfSpeech: const Value('noun'),
      ),
    );

    final derived = await dao.watchDerivedForms(rootId.toString()).first;
    expect(derived.length, 2);
    expect(derived.map((l) => l.ipa).toSet(), {'kalas', 'kaling'});
  });

  // -------------------------------------------------------------------------
  // Test 3: insertLexeme returns auto-incremented ID
  // -------------------------------------------------------------------------
  test('insertLexeme inserts and returns auto-incremented ID', () async {
    final id1 = await dao.insertLexeme(
      LexemesCompanion(ipa: const Value('sol'), meaning: const Value('sun')),
    );
    final id2 = await dao.insertLexeme(
      LexemesCompanion(ipa: const Value('luna'), meaning: const Value('moon')),
    );

    expect(id1, greaterThan(0));
    expect(id2, greaterThan(id1));
  });

  // -------------------------------------------------------------------------
  // Test 4: updateLexeme round-trips changes
  // -------------------------------------------------------------------------
  test('updateLexeme round-trips changes correctly', () async {
    final id = await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('tamu'),
        meaning: const Value('old gloss'),
        partOfSpeech: const Value('adjective'),
      ),
    );

    final original = await (db.select(db.lexemes)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    final updated = original.copyWith(meaning: const Value('new gloss'));
    final success = await dao.updateLexeme(updated);
    expect(success, isTrue);

    final fetched = await (db.select(db.lexemes)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(fetched.meaning, 'new gloss');
    expect(fetched.ipa, 'tamu'); // ipa unchanged
  });

  // -------------------------------------------------------------------------
  // Test 5: deleteLexeme removes the row
  // -------------------------------------------------------------------------
  test('deleteLexeme removes the row', () async {
    final id = await dao.insertLexeme(
      LexemesCompanion(
        ipa: const Value('pira'),
        meaning: const Value('fire'),
      ),
    );

    final deleted = await dao.deleteLexeme(id);
    expect(deleted, 1);

    final remaining = await dao.watchRoots().first;
    expect(remaining.any((l) => l.id == id), isFalse);
  });
}
