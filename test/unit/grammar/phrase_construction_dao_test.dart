import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/construction_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConstructionDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.constructionDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('PhraseConstructionDao', () {
    // -------------------------------------------------------------------------
    // Test 1: Insert a construction, verify it appears in watchAll()
    // -------------------------------------------------------------------------
    test('inserted construction appears in watchAll()', () async {
      await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'Negation',
          ordering: const Value(0),
        ),
      );

      final list = await dao.watchAll().first;
      expect(list, hasLength(1));
      expect(list.first.name, equals('Negation'));
      expect(list.first.ordering, equals(0));
    });

    // -------------------------------------------------------------------------
    // Test 2: Insert slots, verify they appear in correct order
    // -------------------------------------------------------------------------
    test('slots for a construction appear ordered by ordering column', () async {
      final constructionId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'Future',
          ordering: const Value(0),
        ),
      );

      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'gloss_tag',
          slotValue: 'AUX:FUT',
          ordering: const Value(0),
        ),
      );
      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'pos',
          slotValue: 'V',
          ordering: const Value(1),
        ),
      );

      final slots = await dao.watchSlotsFor(constructionId).first;
      expect(slots, hasLength(2));
      expect(slots[0].slotValue, equals('AUX:FUT'));
      expect(slots[0].ordering, equals(0));
      expect(slots[1].slotValue, equals('V'));
      expect(slots[1].ordering, equals(1));
    });

    // -------------------------------------------------------------------------
    // Test 3: Delete construction → cascade-deletes its slots
    // -------------------------------------------------------------------------
    test('deleting a construction cascade-deletes its slots', () async {
      final constructionId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'Negation',
          ordering: const Value(0),
        ),
      );

      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'gloss_tag',
          slotValue: 'NEG',
          ordering: const Value(0),
        ),
      );
      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'pos',
          slotValue: 'V',
          ordering: const Value(1),
        ),
      );

      // Verify slots exist before deletion.
      final slotsBefore = await dao.watchSlotsFor(constructionId).first;
      expect(slotsBefore, hasLength(2));

      // Delete the construction.
      await dao.deleteConstruction(constructionId);

      // Slots should be cascade-deleted.
      final slotsAfter = await dao.watchSlotsFor(constructionId).first;
      expect(slotsAfter, isEmpty);

      // The construction itself should be gone.
      final allConstructions = await dao.watchAll().first;
      expect(allConstructions, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 4: Reorder slots — swap first and last, verify new ordering persists
    // -------------------------------------------------------------------------
    test('reorderSlots persists new ordering for all slots', () async {
      final constructionId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'SVO',
          ordering: const Value(0),
        ),
      );

      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'pos',
          slotValue: 'N',
          ordering: const Value(0),
        ),
      );
      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'pos',
          slotValue: 'V',
          ordering: const Value(1),
        ),
      );
      await dao.insertSlot(
        ConstructionSlotsCompanion.insert(
          constructionId: constructionId,
          slotType: 'pos',
          slotValue: 'OBJ',
          ordering: const Value(2),
        ),
      );

      final original = await dao.watchSlotsFor(constructionId).first;
      expect(original.map((s) => s.slotValue), equals(['N', 'V', 'OBJ']));

      // Swap first and last: [OBJ, V, N]
      final reordered = [original[2], original[1], original[0]];
      await dao.reorderSlots(reordered);

      final updated = await dao.watchSlotsFor(constructionId).first;
      expect(updated.map((s) => s.slotValue), equals(['OBJ', 'V', 'N']));
      expect(updated[0].ordering, equals(0));
      expect(updated[1].ordering, equals(1));
      expect(updated[2].ordering, equals(2));
    });

    // -------------------------------------------------------------------------
    // Test 5: Multiple constructions ordered by ordering column
    // -------------------------------------------------------------------------
    test('watchAll returns constructions ordered by ordering column', () async {
      await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'Third',
          ordering: const Value(2),
        ),
      );
      await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'First',
          ordering: const Value(0),
        ),
      );
      await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(
          name: 'Second',
          ordering: const Value(1),
        ),
      );

      final list = await dao.watchAll().first;
      expect(list, hasLength(3));
      expect(list[0].name, equals('First'));
      expect(list[1].name, equals('Second'));
      expect(list[2].name, equals('Third'));
    });
  });
}
