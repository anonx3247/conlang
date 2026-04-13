// Plan 04-11 Task 2 — MorphologyDao.watchInflectionalRulesForPos reads from
// the v9 junction table (D-55). These tests exercise the JOIN-based query:
// single-POS lookups, multi-POS rules surfacing in every query, kind filter,
// legacy input_pos_id is NOT consulted, and inactive rules still surface (the
// paradigm engine does its own isActive filter downstream).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/data/morphology_dao.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MorphologyDao dao;
  late InflectionalRulePOSDao junctionDao;
  late int nounId;
  late int verbId;
  late int adjId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.morphologyDao;
    junctionDao = InflectionalRulePOSDao(db);

    nounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    adjId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Adjective', abbreviation: 'ADJ'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // Helper: insert an inflectional rule and attach it to the given posIds via
  // the junction. Returns the rule id.
  Future<int> insertInflectional({
    required String name,
    required Set<int> posIds,
    bool isActive = true,
    int? legacyInputPosId,
  }) async {
    final id = await dao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: name,
        source: 'suffix: x',
        isActive: Value(isActive),
        inputPosId: Value(legacyInputPosId),
      ),
      RuleKind.inflectional,
    );
    await junctionDao.replaceForRule(ruleId: id, posIds: posIds);
    return id;
  }

  Future<int> insertDerivational({
    required String name,
    int? inputPosId,
  }) {
    return dao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: name,
        source: 'suffix: y',
        inputPosId: Value(inputPosId),
      ),
      RuleKind.derivational,
    );
  }

  group('watchInflectionalRulesForPos — junction-driven query', () {
    test('returns rules attached to the queried POS only (single POS)',
        () async {
      final plural = await insertInflectional(
        name: 'Plural',
        posIds: {nounId},
      );

      final forNoun = await dao.watchInflectionalRulesForPos(nounId).first;
      expect(forNoun.map((r) => r.id), [plural]);

      final forVerb = await dao.watchInflectionalRulesForPos(verbId).first;
      expect(forVerb, isEmpty);
    });

    test('multi-POS rule surfaces in every matching POS query', () async {
      final agr = await insertInflectional(
        name: 'NumberAgr',
        posIds: {nounId, adjId},
      );

      final forNoun = await dao.watchInflectionalRulesForPos(nounId).first;
      final forAdj = await dao.watchInflectionalRulesForPos(adjId).first;
      final forVerb = await dao.watchInflectionalRulesForPos(verbId).first;

      expect(forNoun.map((r) => r.id), [agr]);
      expect(forAdj.map((r) => r.id), [agr]);
      expect(forVerb, isEmpty);
    });

    test('derivational rules are excluded even with a junction row', () async {
      // Edge case — in practice derivational rules shouldn't have junction
      // rows, but the query must still filter them out by kind.
      final derivId = await insertDerivational(
        name: 'Agentive',
        inputPosId: nounId,
      );
      // Hand-insert a junction row as if something backfilled incorrectly.
      await junctionDao.replaceForRule(ruleId: derivId, posIds: {nounId});

      final forNoun = await dao.watchInflectionalRulesForPos(nounId).first;
      expect(forNoun.any((r) => r.id == derivId), isFalse);
    });

    test('inactive rules are still returned (contract preserved)', () async {
      final past = await insertInflectional(
        name: 'Past',
        posIds: {verbId},
        isActive: false,
      );
      final forVerb = await dao.watchInflectionalRulesForPos(verbId).first;
      expect(forVerb.map((r) => r.id), [past]);
      expect(forVerb.single.isActive, isFalse);
    });

    test('backfilled-shape rule (one junction row per inputPosId) works',
        () async {
      // Simulate the v9 migration backfill: legacy input_pos_id is still
      // populated AND the junction has one row matching it.
      final ruleId = await insertInflectional(
        name: 'Plural',
        posIds: {nounId},
        legacyInputPosId: nounId,
      );
      final forNoun = await dao.watchInflectionalRulesForPos(nounId).first;
      expect(forNoun.map((r) => r.id), [ruleId]);
    });

    test('legacy input_pos_id is NOT consulted without a junction row',
        () async {
      // Rule has legacy inputPosId=nounId but no junction row — it must NOT
      // surface in a query for nounId. The junction is authoritative in v9+.
      final id = await dao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'OrphanRule',
          source: 'suffix: q',
          inputPosId: Value(nounId),
        ),
        RuleKind.inflectional,
      );
      final forNoun = await dao.watchInflectionalRulesForPos(nounId).first;
      expect(forNoun.any((r) => r.id == id), isFalse,
          reason: 'v9+: legacy input_pos_id must not surface rules without '
              'matching junction rows');
    });
  });
}
