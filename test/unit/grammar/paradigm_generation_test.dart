import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Test inventory — matches paradigm_engine_test.dart.
final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r'],
    'v': ['a', 'e', 'i', 'o', 'u'],
  },
);

InflectionalRule _rule(int id, String name, String source, Map<int, int> dims) {
  return InflectionalRule(
    id: id,
    name: name,
    source: source,
    isActive: true,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

void main() {
  group('cartesianFeatureSets — Cartesian expansion', () {
    test('0 dims yields a single empty feature set', () {
      final result = cartesianFeatureSets(const []).toList();
      expect(result, equals([<int, int>{}]));
    });

    test('1 dim × 2 levels yields 2 feature sets', () {
      final dims = [
        _dim(
          id: 10,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: 1, name: 'M', abbr: 'M', ordering: 0),
            DimensionLevel(id: 2, name: 'F', abbr: 'F', ordering: 1),
          ],
        ),
      ];
      final keys = cartesianFeatureSets(dims).map(featureSetKey).toSet();
      expect(keys, equals({'10:1', '10:2'}));
    });

    test('2 dims × 2 levels each yields 4 feature sets', () {
      final dims = [
        _dim(
          id: 10,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: 1, name: 'M', abbr: 'M', ordering: 0),
            DimensionLevel(id: 2, name: 'F', abbr: 'F', ordering: 1),
          ],
        ),
        _dim(
          id: 11,
          name: 'Number',
          levels: const [
            DimensionLevel(id: 1, name: 'PL', abbr: 'PL', ordering: 0),
            DimensionLevel(id: 2, name: 'SG', abbr: 'SG', ordering: 1),
          ],
        ),
      ];
      final keys = cartesianFeatureSets(dims).map(featureSetKey).toSet();
      expect(keys.length, equals(4));
      expect(
        keys,
        equals({'10:1,11:1', '10:1,11:2', '10:2,11:1', '10:2,11:2'}),
      );
    });
  });

  group('generateParadigm — full chart generation', () {
    test('2 dims × 2 levels × 2 rules produces 4 cells', () {
      final dims = [
        _dim(
          id: 10,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: 1, name: 'M', abbr: 'M', ordering: 0),
            DimensionLevel(id: 2, name: 'F', abbr: 'F', ordering: 1),
          ],
        ),
        _dim(
          id: 11,
          name: 'Number',
          levels: const [
            DimensionLevel(id: 1, name: 'PL', abbr: 'PL', ordering: 0),
            DimensionLevel(id: 2, name: 'SG', abbr: 'SG', ordering: 1),
          ],
        ),
      ];
      final rules = [
        _rule(1, '-s', '+s', const {11: 1}), // PL
        _rule(2, '-a', '+a', const {10: 2}), // F
      ];
      final chart = generateParadigm(
        root: 'kat',
        dimensions: dims,
        rules: rules,
        inventory: _inventory,
      );
      expect(chart.length, equals(4));
      // M.SG: no rule matches -> ParadigmUncovered
      expect(
        chart.cellFor(const {10: 1, 11: 2}),
        isA<ParadigmUncovered>(),
      );
      // F.SG: only -a matches -> ParadigmFilled('kata', [-a])
      final fSg = chart.cellFor(const {10: 2, 11: 2});
      expect(fSg, isA<ParadigmFilled>());
      expect((fSg! as ParadigmFilled).form, equals('kata'));
      // M.PL: only -s matches -> ParadigmFilled('kats', [-s])
      final mPl = chart.cellFor(const {10: 1, 11: 1});
      expect(mPl, isA<ParadigmFilled>());
      expect((mPl! as ParadigmFilled).form, equals('kats'));
      // F.PL: both -s and -a match, different bindings, both fire
      final fPl = chart.cellFor(const {10: 2, 11: 1});
      expect(fPl, isA<ParadigmFilled>());
      final fPlFilled = fPl! as ParadigmFilled;
      expect(fPlFilled.ruleChain.length, equals(2));
      expect(
        fPlFilled.ruleChain.map((r) => r.name).toSet(),
        equals({'-s', '-a'}),
      );
    });

    test('D-07 skippedDimensions collapses axes to fewer cells', () {
      final dims = [
        _dim(
          id: 10,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: 1, name: 'M', abbr: 'M', ordering: 0),
            DimensionLevel(id: 2, name: 'F', abbr: 'F', ordering: 1),
          ],
        ),
        _dim(
          id: 11,
          name: 'Number',
          levels: const [
            DimensionLevel(id: 1, name: 'PL', abbr: 'PL', ordering: 0),
            DimensionLevel(id: 2, name: 'SG', abbr: 'SG', ordering: 1),
          ],
        ),
      ];
      final rules = [
        _rule(1, '-a', '+a', const {10: 2}),
      ];
      final chart = generateParadigm(
        root: 'kat',
        dimensions: dims,
        rules: rules,
        inventory: _inventory,
        skippedDimensionIds: const {11}, // skip Number
      );
      // Only the Gender axis remains: 2 cells.
      expect(chart.length, equals(2));
      final keys =
          chart.entries.map((e) => featureSetKey(e.featureSet)).toSet();
      expect(keys, equals({'10:1', '10:2'}));
    });

    test('all dims skipped yields empty chart', () {
      final dims = [
        _dim(
          id: 10,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: 1, name: 'M', abbr: 'M', ordering: 0),
          ],
        ),
      ];
      final chart = generateParadigm(
        root: 'kat',
        dimensions: dims,
        rules: const [],
        inventory: _inventory,
        skippedDimensionIds: const {10},
      );
      expect(chart, isEmpty);
    });
  });

  group('Dimensions DB seeding — integration check', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('Seeding POS + Dimensions + running generator yields full chart',
        () async {
      final posId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: posId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(
                    id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
            ),
          );
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: posId,
              name: 'Number',
              ordering: const Value(1),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
                DimensionLevel(
                    id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
              ]),
            ),
          );
      final dims = await db.grammarDao.watchDimensionsForPos(posId).first;
      expect(dims.length, equals(2));
      final chart = generateParadigm(
        root: 'kat',
        dimensions: dims,
        rules: const [],
        inventory: _inventory,
      );
      // 2 dims × 2 levels = 4 cells; no rules -> all ParadigmUncovered.
      expect(chart.length, equals(4));
      expect(
        chart.entries.every((e) => e.cell is ParadigmUncovered),
        isTrue,
      );
    });
  });
}

/// Inline Drift [Dimension] DataClass builder for pure-value tests.
Dimension _dim({
  required int id,
  required String name,
  required List<DimensionLevel> levels,
  int posId = 1,
}) {
  return Dimension(
    id: id,
    posId: posId,
    name: name,
    ordering: 0,
    levelsJson: encodeLevelsJson(levels),
    templateId: null,
    // 04-17 D-82: intrinsic flag added; default false for pre-04-17
    // test fixtures that never exercised the intrinsic short-circuit.
    intrinsic: false,
  );
}
