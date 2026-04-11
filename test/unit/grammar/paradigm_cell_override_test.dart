// Plan 04-06 Task 1 — ParadigmCellOverrideDao + paradigmCoverageMatrixProvider
// unit tests. Exercises the canonical featureSetKey, upsert/clear/watch CRUD,
// and the coverage matrix provider built over dimensions + inflectional rules.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/paradigm_cell_override_dao.dart';
import 'package:conlang_workbench/features/grammar/data/paradigm_coverage_provider.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_providers.dart';
import 'package:conlang_workbench/features/morphology/data/morphology_providers.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ParadigmCellOverrideDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = ParadigmCellOverrideDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('featureSetKeyForOverride canonical key', () {
    test('is canonical and order-independent', () {
      expect(featureSetKeyForOverride(const {5: 2, 7: 4}), '5:2,7:4');
      expect(featureSetKeyForOverride(const {7: 4, 5: 2}), '5:2,7:4');
    });

    test('empty feature set yields empty key', () {
      expect(featureSetKeyForOverride(const {}), '');
    });
  });

  group('ParadigmCellOverrideDao CRUD', () {
    test('upsertOverride inserts then updates without creating duplicates',
        () async {
      // Need a real Lexemes row because of FK cascade.
      final lexemeId =
          await db.into(db.lexemes).insert(LexemesCompanion.insert(ipa: 'kat'));

      await dao.upsertOverride(
        lexemeId: lexemeId,
        featureSet: const {5: 2},
        overrideIpa: 'mīs',
        overrideRomanization: 'mīs',
      );
      await dao.upsertOverride(
        lexemeId: lexemeId,
        featureSet: const {5: 2},
        overrideIpa: 'mʲiːs',
        overrideRomanization: 'mīs',
      );
      final rows = await db.select(db.paradigmCellOverrides).get();
      expect(rows.length, 1);
      expect(rows.first.overrideIpa, 'mʲiːs');
      expect(rows.first.overrideRomanization, 'mīs');
    });

    test('watchOverridesForLexeme emits a canonical keyed map', () async {
      final lexemeId =
          await db.into(db.lexemes).insert(LexemesCompanion.insert(ipa: 'kat'));
      await dao.upsertOverride(
        lexemeId: lexemeId,
        featureSet: const {5: 2},
        overrideIpa: 'mīs',
      );

      final map = await dao.watchOverridesForLexeme(lexemeId).first;
      expect(map.keys.toList(), ['5:2']);
      expect(map['5:2']!.overrideIpa, 'mīs');
    });

    test('clearOverride removes the row', () async {
      final lexemeId =
          await db.into(db.lexemes).insert(LexemesCompanion.insert(ipa: 'kat'));
      await dao.upsertOverride(
        lexemeId: lexemeId,
        featureSet: const {5: 2},
        overrideIpa: 'mīs',
      );

      final removed = await dao.clearOverride(
        lexemeId: lexemeId,
        featureSet: const {5: 2},
      );
      expect(removed, 1);
      final rows = await db.select(db.paradigmCellOverrides).get();
      expect(rows, isEmpty);
    });
  });

  group('paradigmCoverageMatrixProvider', () {
    test('flags only (dim, level) pairs covered by an active inflectional rule',
        () async {
      // Seed POS (Noun) + 2 dimensions (Number: SG/PL, Gender: M/F)
      final nounId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );
      final numberDimId = await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounId,
              name: 'Number',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
                DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
              ]),
              templateId: const Value('number.sg_pl'),
            ),
          );
      final genderDimId = await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounId,
              name: 'Gender',
              ordering: const Value(1),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              templateId: const Value('gender.mf'),
            ),
          );

      // Seed one inflectional rule bound to Number=PL only.
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Plural',
          source: 'suffix: s',
          featureBindings: Value(
            FeatureBindings(pos: [nounId], dims: {numberDimId: 2}),
          ),
        ),
        RuleKind.inflectional,
      );

      final container = ProviderContainer(overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      // Subscribe so Drift's stream queries actually start emitting.
      final dimsSub = container.listen(
        dimensionsForPosProvider(nounId),
        (prev, next) {},
      );
      addTearDown(dimsSub.close);
      final rulesSub = container.listen(
        inflectionalRulesForPosProvider(nounId),
        (prev, next) {},
      );
      addTearDown(rulesSub.close);

      // Wait for streams to emit their first value now that they have
      // listeners.
      await container.read(dimensionsForPosProvider(nounId).future);
      await container.read(inflectionalRulesForPosProvider(nounId).future);

      final coverage = container.read(paradigmCoverageMatrixProvider(nounId));

      expect(coverage[(numberDimId, 2)], isTrue,
          reason: 'Number=PL should be covered by the Plural rule');
      expect(coverage[(numberDimId, 1)], isFalse,
          reason: 'Number=SG should be uncovered');
      expect(coverage[(genderDimId, 1)], isFalse,
          reason: 'Gender=M should be uncovered');
      expect(coverage[(genderDimId, 2)], isFalse,
          reason: 'Gender=F should be uncovered');
    });
  });
}
