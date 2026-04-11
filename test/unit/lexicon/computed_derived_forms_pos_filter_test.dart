// Plan 04-12 Task 1 — D-61 / G-13 POS filter regression tests for
// `computedDerivedFormsProvider`.
//
// Pre-fix behavior: every active derivational rule was applied to every
// root IPA regardless of POS, because the provider was keyed by a raw
// `String rootIpa` and had no POS context.
//
// Post-fix behavior (this test file): the provider is keyed by
// `int lexemeId`, resolves the lexeme's POS via `posForLexeme`, and only
// applies rules whose `inputPosId` exactly matches the lexeme's POS id.
// Rules with `inputPosId = NULL` are NOT universally applied — they are
// excluded (D-61: no "any POS" sentinel).

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
  // Seeded for test structure parity — not directly referenced.
  // ignore: unused_local_variable
  late int verbPosId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
    );

    // Seed POS rows — the D-61 filter resolves by name/abbr match.
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );

    // Keep Drift-backed StreamProviders hot so their first events land
    // before the synchronous Provider reads them.
    final ruleSub = container.listen(
      morphologicalRuleListProvider,
      (_, _) {},
    );
    final posSub = container.listen(
      posListProvider,
      (_, _) {},
    );
    // Keep the allLexemeList hot too — lexemeByIdProvider depends on it.
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

  // Convenience: seed a lexeme and return its id.
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

  /// Waits a few real ticks so Drift stream emits reach the Riverpod
  /// providers, then returns the derived-form result for [lexemeId].
  ///
  /// Eagerly subscribes to `lexemeByIdProvider(lexemeId)` (the family is
  /// lazy — the first `container.read(computedDerivedFormsProvider(id))`
  /// would otherwise see AsyncLoading for the lexeme and short-circuit
  /// with an empty list before the stream emits its first value).
  Future<List<DerivedFormResult>> readDerivedFor(int lexemeId) async {
    final lexSub = container.listen(
      lexemeByIdProvider(lexemeId),
      (_, _) {},
    );
    addTearDown(lexSub.close);
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return container.read(computedDerivedFormsProvider(lexemeId));
  }

  group('computedDerivedFormsProvider POS filter (D-61 / G-13)', () {
    test(
        'Test 1 — derivational rule with inputPosId=Noun is NOT applied to a Verb lexeme',
        () async {
      // Rule: Agentive "+in" suffix restricted to Nouns.
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Agentive',
          source: '+in',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.derivational,
      );

      // Lexeme: Verb `tara`. The rule's input POS is Noun, so it must not
      // match.
      final taraId = await seedLexeme(ipa: 'tara', partOfSpeech: 'Verb');

      final derived = await readDerivedFor(taraId);
      expect(derived, isEmpty,
          reason:
              'A Noun-scoped derivational rule must NOT apply to a Verb lexeme');
    });

    test(
        'Test 2 — derivational rule with inputPosId=Noun IS applied to a matching Noun lexeme',
        () async {
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Agentive',
          source: '+in',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.derivational,
      );

      final kamaId = await seedLexeme(ipa: 'kama', partOfSpeech: 'Noun');

      final derived = await readDerivedFor(kamaId);
      expect(derived.length, 1,
          reason:
              'Rule whose inputPosId matches the lexeme POS must produce exactly one form');
      expect(derived.single.ruleName, 'Agentive');
      expect(derived.single.derivedIpa, 'kamain');
    });

    test(
        'Test 3 — derivational rule with inputPosId=NULL is NOT universally applied (no "any POS" sentinel)',
        () async {
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'SentinelFree',
          source: '+ot',
          // inputPosId intentionally NULL.
        ),
        RuleKind.derivational,
      );

      final nounId = await seedLexeme(ipa: 'pak', partOfSpeech: 'Noun');
      final verbId = await seedLexeme(ipa: 'run', partOfSpeech: 'Verb');

      expect(await readDerivedFor(nounId), isEmpty,
          reason: 'NULL inputPosId must be excluded entirely (D-61)');
      expect(await readDerivedFor(verbId), isEmpty,
          reason: 'NULL inputPosId must be excluded entirely (D-61)');
    });

    test(
        'Test 4 — free-text partOfSpeech case-insensitive name/abbr match via posForLexeme',
        () async {
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Agentive',
          source: '+in',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.derivational,
      );

      // Lowercase free-text 'noun' must resolve to the Noun POS row.
      final kamaId = await seedLexeme(ipa: 'kama', partOfSpeech: 'noun');

      final derived = await readDerivedFor(kamaId);
      expect(derived.length, 1,
          reason:
              'posForLexeme should match lowercase partOfSpeech to the Noun row');
      expect(derived.single.derivedIpa, 'kamain');
    });

    test(
        'Test 5 — lexeme with an unresolvable partOfSpeech returns empty regardless of rules',
        () async {
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Agentive',
          source: '+in',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.derivational,
      );

      final weirdId = await seedLexeme(ipa: 'kama', partOfSpeech: 'xyz');

      final derived = await readDerivedFor(weirdId);
      expect(derived, isEmpty,
          reason:
              'An unresolvable partOfSpeech yields no POS -> no derivations apply');
    });

    test(
        'Test 6 — inflectional rules are still excluded (kind filter no regression)',
        () async {
      // Inflectional rule with the same POS — must still be skipped.
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Plural',
          source: '+s',
          inputPosId: Value(nounPosId),
          outputPosId: Value(nounPosId),
        ),
        RuleKind.inflectional,
      );

      final kamaId = await seedLexeme(ipa: 'kama', partOfSpeech: 'Noun');

      final derived = await readDerivedFor(kamaId);
      expect(derived, isEmpty,
          reason:
              'Inflectional rules must not appear in the derivation tree (kind filter)');
    });
  });
}
