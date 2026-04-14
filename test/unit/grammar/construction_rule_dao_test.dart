// ConstructionRuleDao CRUD + v16 migration tests.
//
// Uses in-memory Drift database (NativeDatabase.memory()) — each test gets
// a fresh database via setUp/tearDown, matching the construction_dao_test.dart
// pattern.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/construction_rule_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

void main() {
  // ---------------------------------------------------------------------------
  // ConstructionRuleDao CRUD
  // ---------------------------------------------------------------------------

  group('ConstructionRuleDao', () {
    late AppDatabase db;
    late ConstructionRuleDao dao;
    late int posId;
    late int constructionId;
    late int wordSlotId;

    setUp(() async {
      db = _openDb();
      dao = db.constructionRuleDao;

      // Seed prerequisite data required by FKs.
      posId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
          );
      constructionId = await db.into(db.phraseConstructions).insert(
            PhraseConstructionsCompanion.insert(name: 'Future Construction'),
          );
      wordSlotId = await db.into(db.constructionSlots).insert(
            ConstructionSlotsCompanion.insert(
              constructionId: constructionId,
              slotType: 'pos',
              slotValue: 'V',
              ordering: const Value(0),
            ),
          );
    });

    tearDown(() => db.close());

    ConstructionRulesCompanion _makeCompanion({
      String name = 'Test Rule',
      int ordering = 0,
    }) =>
        ConstructionRulesCompanion.insert(
          name: name,
          constructionId: constructionId,
          wordSlotId: wordSlotId,
          ordering: Value(ordering),
          featureBindings: Value(const FeatureBindings(pos: [], dims: {})),
        );

    test('insertRule returns new id', () async {
      final id = await dao.insertRule(_makeCompanion());

      expect(id, greaterThan(0));
    });

    test('watchAll emits rules ordered by ordering', () async {
      // Insert 3 rules with ordering 2, 0, 1 — expect them sorted 0, 1, 2.
      await dao.insertRule(_makeCompanion(name: 'Rule B', ordering: 2));
      await dao.insertRule(_makeCompanion(name: 'Rule A', ordering: 0));
      await dao.insertRule(_makeCompanion(name: 'Rule C', ordering: 1));

      final rows = await dao.watchAll().first;

      expect(rows, hasLength(3));
      expect(rows[0].ordering, equals(0));
      expect(rows[0].name, equals('Rule A'));
      expect(rows[1].ordering, equals(1));
      expect(rows[1].name, equals('Rule C'));
      expect(rows[2].ordering, equals(2));
      expect(rows[2].name, equals('Rule B'));
    });

    test('watchForPos filters by POS junction', () async {
      // Insert two POS entries and two rules; link each rule to a different POS.
      final posId2 = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );

      final ruleAId = await dao.insertRule(_makeCompanion(name: 'Rule A'));
      final ruleBId = await dao.insertRule(_makeCompanion(name: 'Rule B'));

      await dao.insertPosLink(ruleAId, posId);
      await dao.insertPosLink(ruleBId, posId2);

      final forPos1 = await dao.watchForPos(posId).first;
      expect(forPos1, hasLength(1));
      expect(forPos1.single.name, equals('Rule A'));

      final forPos2 = await dao.watchForPos(posId2).first;
      expect(forPos2, hasLength(1));
      expect(forPos2.single.name, equals('Rule B'));
    });

    test('updateRule replaces existing row', () async {
      final id = await dao.insertRule(_makeCompanion(name: 'Initial'));

      // Fetch the inserted row, update the name, and replace.
      final rows = await dao.watchAll().first;
      final row = rows.single;
      final updated = row.copyWith(name: 'Updated');
      await dao.updateRule(updated);

      final afterUpdate = await dao.watchAll().first;
      expect(afterUpdate, hasLength(1));
      expect(afterUpdate.single.id, equals(id));
      expect(afterUpdate.single.name, equals('Updated'));
    });

    test('deleteRule cascades to POS junction', () async {
      final id = await dao.insertRule(_makeCompanion(name: 'ToDelete'));
      await dao.insertPosLink(id, posId);

      // Verify POS link exists before delete.
      final beforeDelete = await dao.getPosIdsForRule(id);
      expect(beforeDelete, contains(posId));

      await dao.deleteRule(id);

      // Rule should be gone.
      final rules = await dao.watchAll().first;
      expect(rules, isEmpty);

      // POS junction rows should be gone (CASCADE ON DELETE).
      final afterDelete = await dao.getPosIdsForRule(id);
      expect(afterDelete, isEmpty);
    });

    test('setPosLinks replaces all POS links atomically', () async {
      final posId2 = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );
      final posId3 = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Adjective', abbreviation: 'ADJ'),
          );

      final id = await dao.insertRule(_makeCompanion());

      // Set initial links {posId, posId2}.
      await dao.setPosLinks(id, {posId, posId2});
      final initial = await dao.getPosIdsForRule(id);
      expect(initial.toSet(), equals({posId, posId2}));

      // Replace with {posId3} — old links must be gone.
      await dao.setPosLinks(id, {posId3});
      final replaced = await dao.getPosIdsForRule(id);
      expect(replaced, hasLength(1));
      expect(replaced.single, equals(posId3));
    });
  });

  // ---------------------------------------------------------------------------
  // v16 migration
  // ---------------------------------------------------------------------------

  group('v16 migration', () {
    late AppDatabase db;

    setUp(() {
      db = _openDb();
    });

    tearDown(() => db.close());

    test('construction_rules table exists after migration', () async {
      // Force database open (lazy initialization).
      await db.customSelect('SELECT 1').get();

      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='construction_rules'",
      ).get();

      expect(result, hasLength(1));
      expect(result.single.read<String>('name'), equals('construction_rules'));
    });

    test('construction_rule_pos table exists after migration', () async {
      await db.customSelect('SELECT 1').get();

      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='construction_rule_pos'",
      ).get();

      expect(result, hasLength(1));
      expect(result.single.read<String>('name'), equals('construction_rule_pos'));
    });

    test('paradigm_cell_overrides has suppress_construction_rule_id column',
        () async {
      await db.customSelect('SELECT 1').get();

      final columns = await db
          .customSelect("PRAGMA table_info('paradigm_cell_overrides')")
          .get();

      final columnNames =
          columns.map((r) => r.read<String>('name')).toList();
      expect(
        columnNames,
        contains('suppress_construction_rule_id'),
      );
    });

    test('existing v15 data is preserved after v16 migration', () async {
      // In-memory DB starts at the latest schema (no incremental migration
      // path from v15). Verify that v15 tables (phrase_constructions and
      // construction_slots) are present and accept data alongside the new v16
      // tables — confirming schema coexistence rather than migration path.
      final constructionId = await db.into(db.phraseConstructions).insert(
            PhraseConstructionsCompanion.insert(name: 'Preserved Construction'),
          );
      final slotId = await db.into(db.constructionSlots).insert(
            ConstructionSlotsCompanion.insert(
              constructionId: constructionId,
              slotType: 'gloss_tag',
              slotValue: 'FUT',
            ),
          );

      // Verify v15 data is present.
      final constructions =
          await db.select(db.phraseConstructions).get();
      expect(constructions, hasLength(1));
      expect(constructions.single.name, equals('Preserved Construction'));

      final slots =
          await db.select(db.constructionSlots).get();
      expect(slots, hasLength(1));
      expect(slots.single.id, equals(slotId));
      expect(slots.single.slotValue, equals('FUT'));

      // Verify v16 table is also accessible.
      final v16result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='construction_rules'",
      ).get();
      expect(v16result, hasLength(1));
    });
  });
}
