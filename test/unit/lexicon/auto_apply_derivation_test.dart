// Plan 04-12 Task 3 — D-59 auto-apply derivation reconcile service tests.
//
// `DerivationPromotionService.reconcile()` walks every derivational rule
// with `autoApply = true` and creates a promoted Lexeme row for every
// matching-POS parent that has a non-null meaning, using the templated
// gloss `"{parent.meaning} ({rule.name})"` exactly as the user example
// in 04-CONTEXT-GAPS §D-59 spells out:
//
//     parent kama (Noun) meaning "to run"
//     rule Actor (autoApply=true, outputPos=Noun)
//     -> derived lexeme kamain with gloss "to run (Actor)"
//
// Reconcile is idempotent — running twice yields exactly one row per
// (parent, rule) pair. It defers promotion when the parent's meaning is
// null/empty (no "null (Actor)" ghost rows) and respects kind /
// isActive / POS filters.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/application/derivation_promotion_service.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DerivationPromotionService service;
  late int nounPosId;
  late int verbPosId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
    );
    service = container.read(derivationPromotionServiceProvider);

    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> seedLexeme({
    required String ipa,
    required String partOfSpeech,
    String? meaning,
  }) {
    return db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: ipa,
            partOfSpeech: Value(partOfSpeech),
            meaning: Value(meaning),
          ),
        );
  }

  Future<int> seedRule({
    required String name,
    required String source,
    required int inputPosId,
    required int outputPosId,
    required RuleKind kind,
    bool autoApply = false,
    bool isActive = true,
  }) {
    return db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: name,
        source: source,
        inputPosId: Value(inputPosId),
        outputPosId: Value(outputPosId),
        autoApply: Value(autoApply),
        isActive: Value(isActive),
      ),
      kind,
    );
  }

  group('DerivationPromotionService.reconcile (D-59)', () {
    test(
        'Test 1 — user example: kama "to run" + Actor autoApply=true -> promoted row with gloss "to run (Actor)"',
        () async {
      final kamaId = await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: 'to run',
      );
      final actorRuleId = await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: true,
      );

      final created = await service.reconcile();
      expect(created, 1, reason: 'Exactly one row should be created');

      final rows = await (db.select(db.lexemes)
            ..where((t) =>
                t.derivedFromLexemeId.equals(kamaId) &
                t.derivedViaRuleId.equals(actorRuleId)))
          .get();
      expect(rows.length, 1);
      expect(rows.single.meaning, equals('to run (Actor)'),
          reason:
              'D-59 templated gloss must match the user example exactly');
    });

    test(
        'Test 2 — auto-apply respects POS filter (Noun-scoped rule does NOT promote Verbs)',
        () async {
      await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: 'to run',
      );
      final taraId = await seedLexeme(
        ipa: 'tara',
        partOfSpeech: 'Verb',
        meaning: 'to sing',
      );
      await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: true,
      );

      await service.reconcile();

      // The Verb tara should NOT be promoted.
      final verbDerivatives = await (db.select(db.lexemes)
            ..where((t) => t.derivedFromLexemeId.equals(taraId)))
          .get();
      expect(verbDerivatives, isEmpty,
          reason:
              'Noun-scoped auto-apply rule must not promote Verb parents');
    });

    test(
        'Test 3 — parent without meaning defers promotion (no "null (Actor)" ghost rows)',
        () async {
      // Parent has meaning = null.
      final kamaId = await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: null,
      );
      await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: true,
      );

      var created = await service.reconcile();
      expect(created, 0,
          reason:
              'No rows should be created while the parent meaning is null');

      // Now set kama.meaning and re-run.
      await (db.update(db.lexemes)..where((t) => t.id.equals(kamaId)))
          .write(const LexemesCompanion(meaning: Value('to run')));

      created = await service.reconcile();
      expect(created, 1,
          reason: 'After meaning is set, the next reconcile must promote');

      final rows = await (db.select(db.lexemes)
            ..where((t) => t.derivedFromLexemeId.equals(kamaId)))
          .get();
      expect(rows.length, 1);
      expect(rows.single.meaning, equals('to run (Actor)'));
    });

    test(
        'Test 4 — autoApply=false rules are dormant (no promotions)',
        () async {
      await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: 'to run',
      );
      await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: false,
      );

      final created = await service.reconcile();
      expect(created, 0);

      final promotedRows = await (db.select(db.lexemes)
            ..where((t) => t.derivedViaRuleId.isNotNull()))
          .get();
      expect(promotedRows, isEmpty);
    });

    test('Test 5 — idempotent: running reconcile twice creates no duplicates',
        () async {
      await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: 'to run',
      );
      await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: true,
      );

      final firstRun = await service.reconcile();
      final secondRun = await service.reconcile();
      expect(firstRun, 1);
      expect(secondRun, 0, reason: 'Second run must not create duplicates');

      final rows = await (db.select(db.lexemes)
            ..where((t) => t.derivedViaRuleId.isNotNull()))
          .get();
      expect(rows.length, 1,
          reason:
              'Exactly one (parent, rule) promoted row after two reconciles');
    });

    test('Test 6 — inactive rules are skipped', () async {
      await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Noun',
        meaning: 'to run',
      );
      await seedRule(
        name: 'Actor',
        source: '+in',
        inputPosId: nounPosId,
        outputPosId: nounPosId,
        kind: RuleKind.derivational,
        autoApply: true,
        isActive: false,
      );

      final created = await service.reconcile();
      expect(created, 0,
          reason: 'Inactive rules must not auto-promote');
    });

    test(
        'Test 7 — inflectional rules with autoApply=true are ignored (derivational-only)',
        () async {
      await seedLexeme(
        ipa: 'kama',
        partOfSpeech: 'Verb',
        meaning: 'to run',
      );
      await seedRule(
        name: 'Plural',
        source: '+s',
        inputPosId: verbPosId,
        outputPosId: verbPosId,
        kind: RuleKind.inflectional,
        autoApply: true,
      );

      final created = await service.reconcile();
      expect(created, 0,
          reason:
              'Inflectional rules are out of scope for auto-apply — deriving paradigms via auto-promote would be wrong');
    });
  });
}
