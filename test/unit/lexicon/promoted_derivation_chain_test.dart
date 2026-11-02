// Plan 11-01 — Bug fix: multi-level promoted derivation chain.
//
// Bug: promotedDerivedFormProvider for word C (derived from B via R2, where B
// is derived from A via R1) was applying R2 to A's raw IPA instead of B's
// computed IPA. Fix: when the parent is itself a promoted derivation, use
// promotedDerivedFormProvider(parent.id) to get B's correctly computed IPA.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/lexicon/data/lexeme_providers.dart';
import 'package:conlang_workbench/features/morphology/data/morphology_providers.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int nounPosId;
  late int rootId; // word A: 'kama'
  late int ruleR1Id; // rule R1: +in  (A -> kamain = B)
  late int ruleR2Id; // rule R2: +ar  (B -> kamainar = C)
  late int wordBId; // promoted derivation of A via R1
  late int wordCId; // promoted derivation of B via R2

  // Helper: pump ticks so Drift stream emissions reach Riverpod.
  Future<void> pumpTicks() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
    );

    // Subscribe to upstream providers to keep them alive.
    final ruleSub = container.listen(morphologicalRuleListProvider, (_, _) {});
    final lexemesSub = container.listen(allLexemeListProvider, (_, _) {});
    addTearDown(ruleSub.close);
    addTearDown(lexemesSub.close);

    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );

    // Root word A: ipa = 'kama'
    rootId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kama',
            partOfSpeech: const Value('Noun'),
            meaning: const Value('to run'),
          ),
        );

    // Rule R1: +in  (kama -> kamain)
    ruleR1Id = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'Actor',
        source: '+in',
        inputPosId: Value(nounPosId),
        outputPosId: Value(nounPosId),
      ),
      RuleKind.derivational,
    );

    // Rule R2: +ar  (kamain -> kamainar)
    ruleR2Id = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'Agentive',
        source: '+ar',
        inputPosId: Value(nounPosId),
        outputPosId: Value(nounPosId),
      ),
      RuleKind.derivational,
    );

    // B = promoted derivation of A via R1; stored ipa = A.ipa = 'kama' (placeholder)
    wordBId = await db.lexemeDao.promoteDerivation(
      parentId: rootId,
      ruleId: ruleR1Id,
      gloss: 'runner',
    );

    // C = promoted derivation of B via R2; stored ipa = B.ipa = 'kama' (placeholder)
    wordCId = await db.lexemeDao.promoteDerivation(
      parentId: wordBId,
      ruleId: ruleR2Id,
      gloss: 'super-runner',
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<PromotedDerivedForm?> readPromoted(int lexemeId) async {
    // Subscribe and pump twice to settle the multi-level chain.
    final pSub = container.listen(
      promotedDerivedFormProvider(lexemeId),
      (_, _) {},
    );
    addTearDown(pSub.close);
    await pumpTicks();
    await pumpTicks();
    return container.read(promotedDerivedFormProvider(lexemeId));
  }

  group('Multi-level promoted derivation chain (Bug 1 fix)', () {
    test(
        'B = R1(A.ipa) — single-level derivation still returns correct form (regression)',
        () async {
      final result = await readPromoted(wordBId);
      expect(result, isNotNull,
          reason: 'B must compute as a promoted derivation of A via R1');
      expect(result!.ipa, equals('kamain'),
          reason: 'R1 (+in) applied to kama must yield kamain');
    });

    test(
        'C = R2(R1(A.ipa)) — multi-level: R2 must be applied to B computed form, not A raw ipa',
        () async {
      final result = await readPromoted(wordCId);
      expect(result, isNotNull,
          reason: 'C must compute as a promoted derivation of B via R2');
      // Correct: R2(+ar) applied to B's computed form 'kamain' = 'kamainar'
      // Bug: R2(+ar) applied to A's raw ipa 'kama' = 'kamacar' — WRONG
      expect(result!.ipa, equals('kamainar'),
          reason:
              'R2 (+ar) must be applied to B\'s computed form (kamain), not A\'s raw ipa (kama)');
    });

    test(
        'Three-level chain D = R3(R2(R1(A.ipa))) computes correct final form',
        () async {
      // Rule R3: +ir  (kamainar -> kamainarsir... actually: kamainar+ir = kamainari)
      final ruleR3Id = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Diminutive',
          source: '+i',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.derivational,
      );

      // D = promoted derivation of C via R3
      final wordDId = await db.lexemeDao.promoteDerivation(
        parentId: wordCId,
        ruleId: ruleR3Id,
        gloss: 'little-super-runner',
      );

      final rSub = container.listen(morphologicalRuleListProvider, (_, _) {});
      final lSub = container.listen(allLexemeListProvider, (_, _) {});
      addTearDown(rSub.close);
      addTearDown(lSub.close);

      final result = await readPromoted(wordDId);
      expect(result, isNotNull);
      // kamainar + i = kamainari
      expect(result!.ipa, equals('kamainari'),
          reason: 'Three-level chain must apply R3 to C\'s computed form');
    });
  });
}
