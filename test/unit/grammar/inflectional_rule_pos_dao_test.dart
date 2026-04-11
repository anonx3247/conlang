// Plan 04-11 Task 1 — InflectionalRulePOSDao unit tests.
//
// Exercises replaceForRule, the two stream queries, and ON DELETE CASCADE
// cleanup of junction rows when a parent MorphologicalRules row is deleted.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InflectionalRulePOSDao dao;
  late int nounId;
  late int verbId;
  late int adjId;
  late int ruleId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = InflectionalRulePOSDao(db);

    // Seed parts of speech — the junction FKs require real rows.
    nounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    adjId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Adjective', abbreviation: 'ADJ'),
        );

    // Seed one inflectional rule that the tests manipulate.
    ruleId = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'Plural',
        source: 'suffix: s',
      ),
      RuleKind.inflectional,
    );
  });

  tearDown(() async {
    await db.close();
  });

  // Convenience: read the full junction table for assertions.
  Future<List<InflectionalRulePOSRow>> allJunctionRows() {
    return db.select(db.inflectionalRulePOS).get();
  }

  group('replaceForRule', () {
    test('inserts one row per posId in the set', () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, verbId, adjId},
      );
      final rows = await allJunctionRows();
      expect(rows.length, 3);
      final pairs = rows.map((r) => (r.ruleId, r.posId)).toSet();
      expect(pairs, containsAll([
        (ruleId, nounId),
        (ruleId, verbId),
        (ruleId, adjId),
      ]));
    });

    test('clears stale rows before inserting the new set', () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, verbId, adjId},
      );
      // Now replace with a different set — the old rows must be gone.
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {verbId},
      );
      final rows = await allJunctionRows();
      expect(rows.length, 1);
      expect(rows.first.posId, verbId);
    });

    test('empty set clears all rows for the rule', () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, verbId},
      );
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: const <int>{},
      );
      final rows = await allJunctionRows();
      expect(rows, isEmpty);
    });

    test('does not disturb rows belonging to other rules', () async {
      final otherRuleId = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Past',
          source: 'suffix: ed',
        ),
        RuleKind.inflectional,
      );
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId},
      );
      await dao.replaceForRule(
        ruleId: otherRuleId,
        posIds: {verbId, adjId},
      );
      // Replacing rule A must leave rule B's rows intact.
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {verbId},
      );
      final rows = await allJunctionRows();
      final byRule = <int, Set<int>>{};
      for (final r in rows) {
        byRule.putIfAbsent(r.ruleId, () => <int>{}).add(r.posId);
      }
      expect(byRule[ruleId], equals({verbId}));
      expect(byRule[otherRuleId], equals({verbId, adjId}));
    });
  });

  group('watchPosSetForRule', () {
    test('emits the POS set after replaceForRule', () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, adjId},
      );
      final set = await dao.watchPosSetForRule(ruleId).first;
      expect(set, equals({nounId, adjId}));
    });

    test('emits empty set when the rule has no junction rows', () async {
      final set = await dao.watchPosSetForRule(ruleId).first;
      expect(set, isEmpty);
    });
  });

  group('watchAllPosSetsByRuleId', () {
    test('returns a map of every rule id to its POS set', () async {
      final secondRuleId = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Past',
          source: 'suffix: ed',
        ),
        RuleKind.inflectional,
      );
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, adjId},
      );
      await dao.replaceForRule(
        ruleId: secondRuleId,
        posIds: {verbId},
      );

      final map = await dao.watchAllPosSetsByRuleId().first;
      expect(map[ruleId], equals({nounId, adjId}));
      expect(map[secondRuleId], equals({verbId}));
    });

    test('omits rules with zero junction rows', () async {
      // ruleId has no junction rows; the map should not contain it.
      final map = await dao.watchAllPosSetsByRuleId().first;
      expect(map.containsKey(ruleId), isFalse);
    });
  });

  group('cascade on rule delete', () {
    test('junction rows are removed when the parent rule is deleted',
        () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, verbId},
      );
      expect((await allJunctionRows()).length, 2);

      // Delete the parent — ON DELETE CASCADE should clean up the junction.
      await db.morphologyDao.deleteRule(ruleId);

      final rows = await allJunctionRows();
      expect(rows.where((r) => r.ruleId == ruleId), isEmpty);
    });
  });

  group('deleteAllForRule', () {
    test('explicit cleanup removes every row for the rule', () async {
      await dao.replaceForRule(
        ruleId: ruleId,
        posIds: {nounId, verbId},
      );
      final removed = await dao.deleteAllForRule(ruleId);
      expect(removed, 2);
      expect((await allJunctionRows()), isEmpty);
    });
  });
}
