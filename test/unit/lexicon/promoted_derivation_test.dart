// Plan 04-12 Task 2 — D-57 + D-58 promoted-derivation path tests.
//
// The core invariant: promoted Lexeme rows (created by
// `lexemeDao.promoteDerivation`) have `derivedFromLexemeId` and
// `derivedViaRuleId` set but `romanization` null — their displayed form
// is computed at render time via `promotedDerivedFormProvider` by
// applying the rule to the parent's ipa. The computation is reactive:
// editing the rule's DSL flows through Riverpod streams so 100 rows
// update without a manual re-save (D-58's 100-lexeme constraint).
//
// Implicit detach (D-58): `detachFromRule` writes the new rom/ipa AND
// nulls `derivedViaRuleId` — the reactive link is severed. The parent
// link (derivedFromLexemeId) is preserved.
//
// Demotion (D-57): `demoteDerivation` deletes the row. Non-promoted
// rows are a no-op (returns false).

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
  late int parentId;
  late int ruleId;

  // Helper: pump real ticks so Drift stream emits reach Riverpod.
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

    final ruleSub = container.listen(
      morphologicalRuleListProvider,
      (_, _) {},
    );
    final posSub = container.listen(
      posListProvider,
      (_, _) {},
    );
    final lexemesSub = container.listen(
      allLexemeListProvider,
      (_, _) {},
    );
    addTearDown(ruleSub.close);
    addTearDown(posSub.close);
    addTearDown(lexemesSub.close);

    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );

    // Parent lexeme `kama` (Noun, meaning "to run" — unusual but matches
    // the D-59 user example in plan 04-CONTEXT-GAPS).
    parentId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kama',
            partOfSpeech: const Value('Noun'),
            meaning: const Value('to run'),
          ),
        );

    // Derivational rule `+in` (e.g. Actor nominalizer).
    ruleId = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'Actor',
        source: '+in',
        inputPosId: Value(nounPosId),
        outputPosId: Value(nounPosId),
      ),
      RuleKind.derivational,
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<PromotedDerivedForm?> readPromoted(int lexemeId) async {
    final lexSub = container.listen(
      lexemeByIdProvider(lexemeId),
      (_, _) {},
    );
    addTearDown(lexSub.close);
    await pumpTicks();
    return container.read(promotedDerivedFormProvider(lexemeId));
  }

  group('LexemeDao.promoteDerivation / detachFromRule / demoteDerivation',
      () {
    test(
        'Test 1 — promoteDerivation creates a Lexeme row with rule linkage and null rom/ipa-dependent fields',
        () async {
      final promotedId = await db.lexemeDao.promoteDerivation(
        parentId: parentId,
        ruleId: ruleId,
        gloss: 'runner',
      );

      final row = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(promotedId)))
          .getSingle();

      expect(row.derivedFromLexemeId, equals(parentId));
      expect(row.derivedViaRuleId, equals(ruleId));
      expect(row.meaning, equals('runner'));
      // Romanization must be null — form is computed at render time.
      expect(row.romanization, isNull);
      // partOfSpeech is set from the rule's output POS (resolved to name).
      expect(row.partOfSpeech, equals('Noun'));
    });

    test(
        'Test 2 — promotedDerivedFormProvider computes the form at render time from rule + parent',
        () async {
      final promotedId = await db.lexemeDao.promoteDerivation(
        parentId: parentId,
        ruleId: ruleId,
        gloss: 'runner',
      );

      final result = await readPromoted(promotedId);
      expect(result, isNotNull);
      expect(result!.ipa, equals('kamain'));
    });

    test(
        'Test 3 — D-58 100-lexeme rule-edit constraint: editing rule +in -> +il updates all 100 rows reactively',
        () async {
      // Promote 100 rows all pointing at the same parent and rule.
      final ids = <int>[];
      for (var i = 0; i < 100; i++) {
        final id = await db.lexemeDao.promoteDerivation(
          parentId: parentId,
          ruleId: ruleId,
          gloss: 'runner-$i',
        );
        ids.add(id);
      }

      // Subscribe to each promoted provider so Riverpod creates them and
      // keeps them live across the rule update.
      for (final id in ids) {
        final sub = container.listen(
          lexemeByIdProvider(id),
          (_, _) {},
        );
        addTearDown(sub.close);
        final psub = container.listen(
          promotedDerivedFormProvider(id),
          (_, _) {},
        );
        addTearDown(psub.close);
      }

      await pumpTicks();

      // Initial read: every row computes `kamain`.
      for (final id in ids) {
        final pre = container.read(promotedDerivedFormProvider(id));
        expect(pre, isNotNull);
        expect(pre!.ipa, equals('kamain'));
      }

      // Edit the rule source from +in to +il. No manual re-save on the
      // 100 rows — the reactive Riverpod chain must pick it up.
      final rule = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(ruleId)))
          .getSingle();
      await db.morphologyDao.updateRule(
        rule.copyWith(source: '+il'),
      );

      await pumpTicks();

      // Post-edit read: every row now computes `kamail`.
      for (final id in ids) {
        final post = container.read(promotedDerivedFormProvider(id));
        expect(post, isNotNull);
        expect(post!.ipa, equals('kamail'),
            reason:
                'D-58: rule edit must flow to all 100 promoted lexemes via the reactive stream');
      }
    });

    test(
        'Test 4 — detachFromRule writes new rom/ipa AND nulls derivedViaRuleId; parent link preserved',
        () async {
      final promotedId = await db.lexemeDao.promoteDerivation(
        parentId: parentId,
        ruleId: ruleId,
        gloss: 'runner',
      );

      await db.lexemeDao.detachFromRule(
        lexemeId: promotedId,
        newIpa: 'kamajr',
        newRom: 'kamair',
      );

      final row = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(promotedId)))
          .getSingle();

      expect(row.ipa, equals('kamajr'));
      expect(row.romanization, equals('kamair'));
      expect(row.derivedViaRuleId, isNull,
          reason:
              'detachFromRule must sever the rule link (implicit detach gesture)');
      expect(row.derivedFromLexemeId, equals(parentId),
          reason: 'parent link must be preserved by detach');
    });

    test(
        'Test 5 — meaning/notes edit via replace does NOT touch derivedViaRuleId (only detachFromRule does)',
        () async {
      final promotedId = await db.lexemeDao.promoteDerivation(
        parentId: parentId,
        ruleId: ruleId,
        gloss: 'runner',
      );

      // Update meaning using the normal update path.
      await (db.update(db.lexemes)..where((t) => t.id.equals(promotedId)))
          .write(const LexemesCompanion(
        meaning: Value('sprinter'),
      ));

      final row = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(promotedId)))
          .getSingle();

      expect(row.meaning, equals('sprinter'));
      expect(row.derivedViaRuleId, equals(ruleId),
          reason: 'Editing meaning must NOT implicitly detach from the rule');
    });

    test('Test 6 — demoteDerivation deletes the promoted row', () async {
      final promotedId = await db.lexemeDao.promoteDerivation(
        parentId: parentId,
        ruleId: ruleId,
        gloss: 'runner',
      );

      final demoted = await db.lexemeDao.demoteDerivation(
        lexemeId: promotedId,
      );
      expect(demoted, isTrue);

      final row = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(promotedId)))
          .getSingleOrNull();
      expect(row, isNull, reason: 'Promoted row must be deleted by demote');
    });

    test(
        'Test 7 — demoteDerivation on a non-promoted lexeme is a no-op (returns false)',
        () async {
      // parentId points to a root lexeme — not rule-linked.
      final demoted = await db.lexemeDao.demoteDerivation(
        lexemeId: parentId,
      );
      expect(demoted, isFalse,
          reason:
              'A row with derivedViaRuleId == null is already standalone');

      // The parent still exists.
      final row = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(parentId)))
          .getSingleOrNull();
      expect(row, isNotNull,
          reason:
              'demoteDerivation must NOT delete non-promoted rows — it returns false instead');
    });
  });
}
