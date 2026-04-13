// Plan 04-12 Task 4 — LexemeParentsDao unit tests (D-62 data layer).
//
// Exercises CRUD + stream behavior of the `lexeme_parents` junction
// table (v9 schema, plan 04-08):
//   - insertParent adds a row
//   - watchParentsForChild / watchChildrenForParent emit the right rows
//   - multiple parents per child (compound etymology)
//   - deleteParent removes exactly one pair
//   - updateParent modifies relationship/notes
//   - ON DELETE CASCADE removes junction rows when a referenced lexeme
//     is deleted (either parent or child)

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/lexeme_parents_dao.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LexemeParentsDao dao;
  late int childId;
  late int parentAId;
  late int parentBId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = LexemeParentsDao(db);

    // Seed three lexemes — one child, two candidate parents (mimics a
    // compound word like sunflower: child "sunflower", parents "sun"
    // and "flower").
    childId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(ipa: 'sunflower'),
        );
    parentAId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(ipa: 'sun'),
        );
    parentBId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(ipa: 'flower'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<LexemeParentRow>> allRows() =>
      db.select(db.lexemeParents).get();

  group('LexemeParentsDao CRUD', () {
    test('Test 1 — insertParent adds a single row', () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      final rows = await allRows();
      expect(rows.length, 1);
      expect(rows.single.childLexemeId, equals(childId));
      expect(rows.single.parentLexemeId, equals(parentAId));
      expect(rows.single.relationship, equals('from'));
      expect(rows.single.notes, isNull);
    });

    test('Test 2 — watchParentsForChild emits the inserted parent',
        () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      final rows = await dao.watchParentsForChild(childId).first;
      expect(rows.length, 1);
      expect(rows.single.parentLexemeId, equals(parentAId));
    });

    test('Test 3 — watchChildrenForParent emits the child', () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      final rows = await dao.watchChildrenForParent(parentAId).first;
      expect(rows.length, 1);
      expect(rows.single.childLexemeId, equals(childId));
    });

    test(
        'Test 4 — multiple parents per child (compound word: sunflower <- sun + flower)',
        () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentBId,
        relationship: 'from',
      );

      final rows = await dao.watchParentsForChild(childId).first;
      expect(rows.length, 2);
      final parentIds = rows.map((r) => r.parentLexemeId).toSet();
      expect(parentIds, equals({parentAId, parentBId}));
    });

    test(
        'Test 5 — deleteParent removes only the targeted (child, parent) pair',
        () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentBId,
        relationship: 'from',
      );

      await dao.deleteParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
      );

      final rows = await allRows();
      expect(rows.length, 1);
      expect(rows.single.parentLexemeId, equals(parentBId),
          reason:
              'deleteParent must remove only the targeted pair, not the sibling');
    });

    test(
        'Test 6 — updateParent modifies relationship/notes on the existing row',
        () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      await dao.updateParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'via',
        notes: 'from an older form',
      );

      final rows = await dao.watchParentsForChild(childId).first;
      expect(rows.length, 1);
      expect(rows.single.relationship, equals('via'));
      expect(rows.single.notes, equals('from an older form'));
    });

    test(
        'Test 7 — ON DELETE CASCADE removes junction rows when a referenced lexeme is deleted',
        () async {
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentAId,
        relationship: 'from',
      );
      await dao.insertParent(
        childLexemeId: childId,
        parentLexemeId: parentBId,
        relationship: 'from',
      );

      // Delete parent A — its junction row must go away.
      await (db.delete(db.lexemes)..where((t) => t.id.equals(parentAId))).go();
      var rows = await allRows();
      expect(rows.length, 1,
          reason:
              'Deleting parent A must cascade to the (child, parentA) junction row');
      expect(rows.single.parentLexemeId, equals(parentBId));

      // Delete the child — the remaining (child, parentB) row must go
      // away.
      await (db.delete(db.lexemes)..where((t) => t.id.equals(childId))).go();
      rows = await allRows();
      expect(rows, isEmpty,
          reason:
              'Deleting the child must cascade to the remaining junction row');
    });
  });
}
