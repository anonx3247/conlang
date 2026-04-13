// Plan 04-17 Task 5 — D-91 intrinsic-aware coverage matrix tests.
//
// Locks the CONTEXT.md D-91 worked example as a unit test:
//   POS=Noun, gender intrinsic {M, F}, number non-intrinsic {sg, pl}.
//
// Case 0 [BLOCKER-3] — FeatureSetKey value-equality baseline.
// Case 1 — rules {gender=M, number=pl} + {number=pl}
//          → axes = [gender, number], 4 cells, (M,pl) + (F,pl) covered.
// Case 2 — drop the general {number=pl} rule → (F,pl) flips uncovered.
// Case 3 — only {number=pl} rule (no gender references)
//          → axes collapse to [number], cells = 2.
// Case 4 — no rules at all → axes empty, cells empty.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_providers.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/data/paradigm_coverage_provider.dart';
import 'package:conlang_workbench/features/grammar/domain/coverage_matrix.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/data/morphology_providers.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureSetKey value equality (BLOCKER-3)', () {
    test('FeatureSetKey is value-equal', () {
      final k1 = FeatureSetKey({1: 2, 3: 4});
      final k2 = FeatureSetKey({3: 4, 1: 2});
      expect(k1 == k2, isTrue);
      expect(k1.hashCode, k2.hashCode);
      final map = <FeatureSetKey, bool>{k1: true};
      expect(map[k2], isTrue);
    });

    test('FeatureSetKey distinguishes different maps', () {
      final k1 = FeatureSetKey({1: 2});
      final k2 = FeatureSetKey({1: 3});
      expect(k1 == k2, isFalse);
    });
  });

  group('paradigmCoverageMatrixProvider — D-91 worked example', () {
    late AppDatabase db;
    late int nounId;
    late int genderDimId;
    late int numberDimId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      nounId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );
      // Gender — intrinsic with M/F
      genderDimId = await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              intrinsic: const Value(true),
            ),
          );
      // Number — non-intrinsic with SG/PL
      numberDimId = await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounId,
              name: 'Number',
              ordering: const Value(1),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
                DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
              ]),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertRule(String name, Map<int, int> dims) async {
      final id = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: name,
          source: '+x',
          featureBindings: Value(FeatureBindings(pos: [nounId], dims: dims)),
        ),
        RuleKind.inflectional,
      );
      await InflectionalRulePOSDao(db).replaceForRule(
        ruleId: id,
        posIds: {nounId},
      );
      return id;
    }

    Future<CoverageMatrix> readMatrix() async {
      final container = ProviderContainer(overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
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
      await container.read(dimensionsForPosProvider(nounId).future);
      await container.read(inflectionalRulesForPosProvider(nounId).future);
      return container.read(paradigmCoverageMatrixProvider(nounId));
    }

    test(
        'Case 1 — {gender=M, number=pl} + {number=pl} → axes = [gender, number], 4 cells',
        () async {
      await insertRule('masc-pl', {genderDimId: 1, numberDimId: 2});
      await insertRule('pl', {numberDimId: 2});

      final matrix = await readMatrix();

      // Axes ordered by id.
      expect(matrix.axes, equals([genderDimId, numberDimId]));
      expect(matrix.cells.length, equals(4));

      // (M, PL) covered by both rules.
      expect(
        matrix.cells[FeatureSetKey({genderDimId: 1, numberDimId: 2})],
        isTrue,
      );
      // (F, PL) covered by {number=pl} via wildcard on gender.
      expect(
        matrix.cells[FeatureSetKey({genderDimId: 2, numberDimId: 2})],
        isTrue,
      );
      // (M, SG) uncovered.
      expect(
        matrix.cells[FeatureSetKey({genderDimId: 1, numberDimId: 1})],
        isFalse,
      );
      // (F, SG) uncovered.
      expect(
        matrix.cells[FeatureSetKey({genderDimId: 2, numberDimId: 1})],
        isFalse,
      );
    });

    test(
        'Case 2 — drop {number=pl} → (F, PL) flips to uncovered, (M, PL) still covered',
        () async {
      await insertRule('masc-pl', {genderDimId: 1, numberDimId: 2});

      final matrix = await readMatrix();

      expect(
        matrix.cells[FeatureSetKey({genderDimId: 1, numberDimId: 2})],
        isTrue,
        reason: 'M, PL covered by the remaining masc-pl rule',
      );
      expect(
        matrix.cells[FeatureSetKey({genderDimId: 2, numberDimId: 2})],
        isFalse,
        reason: 'F, PL uncovered now that the general pl rule is gone',
      );
    });

    test(
        'Case 3 — only {number=pl} rule → gender axis collapses OUT, 2 cells',
        () async {
      await insertRule('pl', {numberDimId: 2});

      final matrix = await readMatrix();

      expect(matrix.axes, equals([numberDimId]));
      expect(matrix.cells.length, equals(2));
      expect(
        matrix.cells[FeatureSetKey({numberDimId: 1})],
        isFalse,
        reason: 'SG uncovered',
      );
      expect(
        matrix.cells[FeatureSetKey({numberDimId: 2})],
        isTrue,
        reason: 'PL covered',
      );
    });

    test('Case 4 — no rules → axes empty, cells empty', () async {
      final matrix = await readMatrix();
      expect(matrix.axes, isEmpty);
      expect(matrix.cells, isEmpty);
    });
  });
}
