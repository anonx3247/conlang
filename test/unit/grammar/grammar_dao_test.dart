import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/data/morphology_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GrammarDao grammarDao;
  late MorphologyDao morphDao;
  late int posNounId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    grammarDao = db.grammarDao;
    morphDao = db.morphologyDao;
    posNounId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('MorphologyDao kind-aware queries', () {
    test('watchRulesByKind filters by kind column', () async {
      for (var i = 0; i < 3; i++) {
        await morphDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(name: 'inf$i', source: '-x'),
          RuleKind.inflectional,
        );
      }
      for (var i = 0; i < 2; i++) {
        await morphDao.insertRuleWithKind(
          MorphologicalRulesCompanion.insert(name: 'der$i', source: '-y'),
          RuleKind.derivational,
        );
      }

      final infs = await morphDao.watchRulesByKind(RuleKind.inflectional).first;
      final ders = await morphDao.watchRulesByKind(RuleKind.derivational).first;

      expect(infs.length, equals(3));
      expect(ders.length, equals(2));
      expect(infs.every((r) => r.kind == 'inflectional'), isTrue);
      expect(ders.every((r) => r.kind == 'derivational'), isTrue);
    });

    test('insertRuleWithKind writes the kind column for inflectional', () async {
      final id = await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(name: 't', source: '-s'),
        RuleKind.inflectional,
      );
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.kind, equals('inflectional'));
    });

    test('insertRuleWithKind writes the kind column for derivational', () async {
      final id = await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(name: 'd', source: '-d'),
        RuleKind.derivational,
      );
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.kind, equals('derivational'));
    });

    test('watchInflectionalRulesForPos filters by pos AND kind', () async {
      // Inflectional for POS 1 (posNounId)
      await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'PL',
          source: '-s',
          featureBindings: Value(FeatureBindings(pos: [posNounId], dims: {5: 2})),
        ),
        RuleKind.inflectional,
      );
      // Inflectional applies-to-all (empty pos)
      await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'all',
          source: '-x',
          featureBindings: const Value(
            FeatureBindings(pos: [], dims: {5: 2}),
          ),
        ),
        RuleKind.inflectional,
      );
      // Inflectional for POS 999 only (should be excluded)
      await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'pos999only',
          source: '-q',
          featureBindings: const Value(
            FeatureBindings(pos: [999], dims: {5: 2}),
          ),
        ),
        RuleKind.inflectional,
      );
      // Derivational for POS 1 (should be excluded — wrong kind)
      await morphDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'derPOS1',
          source: '-d',
          featureBindings: Value(FeatureBindings(pos: [posNounId], dims: const {})),
        ),
        RuleKind.derivational,
      );

      final result = await morphDao.watchInflectionalRulesForPos(posNounId).first;
      final names = result.map((r) => r.name).toList();
      expect(names, containsAll(['PL', 'all']));
      expect(names, isNot(contains('pos999only')));
      expect(names, isNot(contains('derPOS1')));
    });
  });

  group('GrammarDao CRUD', () {
    test('insertDimension + watchDimensionsForPos returns inserted row', () async {
      final id = await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'Number',
          levelsJson: encodeLevelsJson(const [
            DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
            DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
          ]),
        ),
      );
      final list = await grammarDao.watchDimensionsForPos(posNounId).first;
      expect(list, hasLength(1));
      expect(list.first.id, equals(id));
      expect(list.first.name, equals('Number'));
    });

    test('watchDimensionsForPos orders by ordering asc', () async {
      await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'B',
          ordering: const Value(2),
          levelsJson: '[]',
        ),
      );
      await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'A',
          ordering: const Value(0),
          levelsJson: '[]',
        ),
      );
      await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'C',
          ordering: const Value(1),
          levelsJson: '[]',
        ),
      );
      final list = await grammarDao.watchDimensionsForPos(posNounId).first;
      expect(list.map((d) => d.name).toList(), equals(['A', 'C', 'B']));
    });

    test('updateDimensionLevels JSON-encodes and persists', () async {
      final id = await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'Gender',
          levelsJson: '[]',
        ),
      );
      await grammarDao.updateDimensionLevels(id, const [
        DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
        DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
      ]);
      final row = await (db.select(db.dimensions)..where((t) => t.id.equals(id)))
          .getSingle();
      final decoded = decodeLevelsJson(row.levelsJson);
      expect(decoded, hasLength(2));
      expect(decoded.first.name, equals('Masculine'));
      expect(decoded.last.name, equals('Feminine'));
    });

    test('nextLevelId returns 1 when list empty, max+1 otherwise', () async {
      final id = await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'Empty',
          levelsJson: '[]',
        ),
      );
      expect(await grammarDao.nextLevelId(id), equals(1));

      await grammarDao.updateDimensionLevels(id, const [
        DimensionLevel(id: 1, name: 'a', abbr: 'A', ordering: 0),
        DimensionLevel(id: 5, name: 'b', abbr: 'B', ordering: 1),
      ]);
      expect(await grammarDao.nextLevelId(id), equals(6));
    });

    test('nextDimensionOrdering returns 0 when empty and max+1 otherwise',
        () async {
      expect(await grammarDao.nextDimensionOrdering(posNounId), equals(0));
      await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'One',
          ordering: const Value(0),
          levelsJson: '[]',
        ),
      );
      await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'Two',
          ordering: const Value(3),
          levelsJson: '[]',
        ),
      );
      expect(await grammarDao.nextDimensionOrdering(posNounId), equals(4));
    });

    test('deleteDimension removes the row', () async {
      final id = await grammarDao.insertDimension(
        DimensionsCompanion.insert(
          posId: posNounId,
          name: 'Doomed',
          levelsJson: '[]',
        ),
      );
      await grammarDao.deleteDimension(id);
      final list = await grammarDao.watchDimensionsForPos(posNounId).first;
      expect(list, isEmpty);
    });
  });
}
