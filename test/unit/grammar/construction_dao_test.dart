import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/construction_dao.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('ConstructionDao', () {
    late AppDatabase db;
    late ConstructionDao dao;

    setUp(() {
      db = _openDb();
      dao = db.constructionDao;
    });

    tearDown(() => db.close());

    // Test 4: insert + read back
    test('insertConstruction + watchAll returns inserted row', () async {
      final id = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(name: 'S V O'),
      );
      expect(id, greaterThan(0));

      final all = await dao.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.name, equals('S V O'));
      expect(all.single.ordering, equals(0));
    });

    // Test 5: insert 3 slots, watch them, verify order + FK
    test('insertSlot + watchSlotsFor returns slots ordered by ordering',
        () async {
      final constructionId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(name: 'NP VP'),
      );

      await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: constructionId,
        slotType: 'pos',
        slotValue: 'N',
        ordering: const Value(0),
        label: const Value('Subject'),
      ));
      await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: constructionId,
        slotType: 'pos',
        slotValue: 'V',
        ordering: const Value(1),
        label: const Value('Predicate'),
      ));
      await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: constructionId,
        slotType: 'gloss_tag',
        slotValue: 'NEG',
        ordering: const Value(2),
      ));

      final slots = await dao.watchSlotsFor(constructionId).first;
      expect(slots, hasLength(3));
      expect(slots[0].slotType, equals('pos'));
      expect(slots[0].slotValue, equals('N'));
      expect(slots[1].slotValue, equals('V'));
      expect(slots[2].slotType, equals('gloss_tag'));
      expect(slots[2].label, isNull);
      // All slots belong to same construction
      expect(slots.map((s) => s.constructionId).toSet(), {constructionId});
    });

    // Test 6: cascade delete
    test('deleteConstruction cascades to construction_slots', () async {
      final cId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(name: 'X Y'),
      );
      await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: cId,
        slotType: 'pos',
        slotValue: 'N',
      ));
      await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: cId,
        slotType: 'pos',
        slotValue: 'V',
      ));

      // Verify slots exist
      final beforeDelete = await dao.watchSlotsFor(cId).first;
      expect(beforeDelete, hasLength(2));

      // Delete construction
      await dao.deleteConstruction(cId);

      // Slots should be gone (cascade)
      final afterDelete = await dao.watchSlotsFor(cId).first;
      expect(afterDelete, isEmpty);

      // Construction should be gone too
      final constructions = await dao.watchAll().first;
      expect(constructions, isEmpty);
    });

    // Test 7: reorder slots
    test('reorderSlots updates ordering column correctly', () async {
      final cId = await dao.insertConstruction(
        PhraseConstructionsCompanion.insert(name: 'Reorder Test'),
      );
      final id1 = await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: cId,
        slotType: 'pos',
        slotValue: 'N',
        ordering: const Value(0),
      ));
      final id2 = await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: cId,
        slotType: 'pos',
        slotValue: 'V',
        ordering: const Value(1),
      ));
      final id3 = await dao.insertSlot(ConstructionSlotsCompanion.insert(
        constructionId: cId,
        slotType: 'gloss_tag',
        slotValue: 'NEG',
        ordering: const Value(2),
      ));

      // Get the actual slot objects from DB
      final originalSlots = await dao.watchSlotsFor(cId).first;
      expect(originalSlots.map((s) => s.slotValue).toList(),
          ['N', 'V', 'NEG']);

      // Reorder: reverse the list
      final reversed = originalSlots.reversed.toList();
      await dao.reorderSlots(reversed);

      final reordered = await dao.watchSlotsFor(cId).first;
      expect(reordered.map((s) => s.slotValue).toList(), ['NEG', 'V', 'N']);

      // Suppress unused variable warnings
      expect([id1, id2, id3].every((i) => i > 0), isTrue);
    });
  });
}
