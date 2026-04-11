// Plan 04-07 Task 2 — unit tests locking the kind filter on
// `computedDerivedFormsProvider`.
//
// Pitfall #9 (from 04-RESEARCH.md): the pre-plan-04-07 implementation of
// `computedDerivedFormsProvider` iterated over ALL active morphological
// rules, which is wrong once schema v8 introduces the kind column —
// inflectional rules would pollute the lexicon derivation tree with
// bogus "derived" forms for every paradigm cell. These tests lock in
// the fix: the provider must skip any rule whose kind != 'derivational'.
//
// Plan 04-12 Task 1 adaptation: the provider was re-keyed from
// `String rootIpa` to `int lexemeId` to support the D-61 POS filter.
// This file now seeds a Noun lexeme (or Verb, where relevant) and calls
// the provider with the lexeme id. The kind-filter assertions are
// unchanged in spirit — they still verify inflectional rules never
// appear in the derivation tree.

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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
    );
    // Seed listeners on Drift-backed StreamProviders so their first
    // events are emitted before the synchronous Provider reads them.
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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Seeds a lexeme with the given [ipa] and [partOfSpeech] free-text label
  /// and returns its id.
  Future<int> seedLexeme({
    required String ipa,
    required String partOfSpeech,
  }) {
    return db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: ipa,
            partOfSpeech: Value(partOfSpeech),
          ),
        );
  }

  /// Waits for the ruleListProvider to emit its first event after a DB
  /// write, then returns the provider result for the given lexeme id.
  ///
  /// Eagerly subscribes to `lexemeByIdProvider(lexemeId)` so its first
  /// stream event has landed before `computedDerivedFormsProvider` reads
  /// its value (otherwise the provider would see AsyncLoading and
  /// short-circuit with an empty list).
  Future<List<DerivedFormResult>> readDerivedFor(int lexemeId) async {
    final lexSub = container.listen(
      lexemeByIdProvider(lexemeId),
      (_, _) {},
    );
    addTearDown(lexSub.close);
    // Drift schedules stream emits via microtask-driven Timer.run, so we
    // need a real async tick for the new rows to show up in the provider.
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return container.read(computedDerivedFormsProvider(lexemeId));
  }

  group('computedDerivedFormsProvider kind filter (pitfall #9)', () {
    test(
      'Test 1 — with 1 derivational + 1 inflectional rule, only the '
      'derivational rule contributes a derived form',
      () async {
        final nounPosId = await db.into(db.partsOfSpeech).insert(
              PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
            );

        // Rule A: derivational — suffix +er (agent nominalizer).
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Agent',
            source: '+er',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.derivational,
        );
        // Rule B: inflectional — suffix +s (plural).
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Plural',
            source: '+s',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.inflectional,
        );

        final katId = await seedLexeme(ipa: 'kat', partOfSpeech: 'Noun');
        final derived = await readDerivedFor(katId);

        // Exactly one derived form should be produced — the derivational
        // Agent rule. The inflectional Plural rule must NOT appear.
        expect(derived.length, 1,
            reason:
                'Expected exactly 1 derived form (from the derivational rule)');
        expect(derived.single.ruleName, 'Agent');
        expect(derived.single.derivedIpa, 'kater');

        // Ensure Plural was NOT applied — no DerivedFormResult for it.
        final pluralResults =
            derived.where((r) => r.ruleName == 'Plural').toList();
        expect(pluralResults, isEmpty,
            reason:
                'Inflectional Plural rule must be filtered out by the kind guard (pitfall #9)');
      },
    );

    test(
      'Test 2 — with ONLY inflectional rules seeded, the provider returns '
      'an empty list',
      () async {
        final nounPosId = await db.into(db.partsOfSpeech).insert(
              PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
            );
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Plural',
            source: '+s',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.inflectional,
        );
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Diminutive Infl',
            source: '+ito',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.inflectional,
        );

        final katId = await seedLexeme(ipa: 'kat', partOfSpeech: 'Noun');
        final derived = await readDerivedFor(katId);
        expect(derived, isEmpty,
            reason:
                'When every rule is inflectional the derivation tree must be empty');
      },
    );

    test(
      'Test 3 — with ONLY derivational rules, the provider returns the '
      'expected list (pre-Phase-4 behavior preserved)',
      () async {
        final verbPosId = await db.into(db.partsOfSpeech).insert(
              PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
            );
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Agent',
            source: '+er',
            inputPosId: Value(verbPosId),
            outputPosId: Value(verbPosId),
          ),
          RuleKind.derivational,
        );
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Action-noun',
            source: '+ing',
            inputPosId: Value(verbPosId),
            outputPosId: Value(verbPosId),
          ),
          RuleKind.derivational,
        );

        final teachId = await seedLexeme(ipa: 'teach', partOfSpeech: 'Verb');
        final derived = await readDerivedFor(teachId);

        expect(derived.length, 2);
        final names = derived.map((r) => r.ruleName).toSet();
        expect(names, {'Agent', 'Action-noun'});
        final forms = derived.map((r) => r.derivedIpa).toSet();
        expect(forms, {'teacher', 'teaching'});
      },
    );

    test(
      'Test 4 — inactive derivational rules are still excluded '
      '(pre-existing guard preserved after the kind filter)',
      () async {
        final nounPosId = await db.into(db.partsOfSpeech).insert(
              PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
            );
        // Active derivational rule — should contribute.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Agent',
            source: '+er',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
          RuleKind.derivational,
        );
        // Inactive derivational rule — should NOT contribute even though
        // its kind passes the new filter.
        await db.morphologyDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(
            name: 'Dormant',
            source: '+zzz',
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
            isActive: const Value(false),
          ),
          RuleKind.derivational,
        );

        final katId = await seedLexeme(ipa: 'kat', partOfSpeech: 'Noun');
        final derived = await readDerivedFor(katId);
        expect(derived.length, 1);
        expect(derived.single.ruleName, 'Agent');
      },
    );
  });
}
