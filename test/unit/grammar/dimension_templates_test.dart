import 'package:conlang_workbench/features/grammar/data/dimension_templates.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DimensionLevel JSON round-trip', () {
    test('toJson produces the expected map shape', () {
      const level = DimensionLevel(
        id: 1,
        name: 'Singular',
        abbr: 'SG',
        ordering: 0,
      );
      expect(
        level.toJson(),
        equals({'id': 1, 'name': 'Singular', 'abbr': 'SG', 'ordering': 0}),
      );
    });

    test('fromJson constructs an equal value', () {
      final level = DimensionLevel.fromJson({
        'id': 2,
        'name': 'Plural',
        'abbr': 'PL',
        'ordering': 1,
      });
      expect(
        level,
        equals(
          const DimensionLevel(
            id: 2,
            name: 'Plural',
            abbr: 'PL',
            ordering: 1,
          ),
        ),
      );
    });

    test('encodeLevelsJson/decodeLevelsJson round-trips losslessly', () {
      const levels = [
        DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
        DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
      ];
      final encoded = encodeLevelsJson(levels);
      expect(encoded, isA<String>());
      expect(encoded, startsWith('['));
      final decoded = decodeLevelsJson(encoded);
      expect(decoded, equals(levels));
    });

    test('decodeLevelsJson returns empty list on malformed input', () {
      expect(decodeLevelsJson(''), isEmpty);
      expect(decodeLevelsJson('not a json'), isEmpty);
      expect(decodeLevelsJson('{}'), isEmpty);
    });
  });

  group('dimensionTemplates catalog', () {
    test('ships at least 20 templates', () {
      expect(dimensionTemplates.length, greaterThanOrEqualTo(20));
    });

    test('every template has non-empty id/group/name/description/levels', () {
      for (final t in dimensionTemplates) {
        expect(t.id, isNotEmpty, reason: 'id empty in template ${t.name}');
        expect(t.group, isNotEmpty, reason: 'group empty in template ${t.id}');
        expect(t.name, isNotEmpty, reason: 'name empty in template ${t.id}');
        expect(
          t.description,
          isNotEmpty,
          reason: 'description empty in template ${t.id}',
        );
        expect(
          t.levels,
          isNotEmpty,
          reason: 'levels empty in template ${t.id}',
        );
      }
    });

    test('every template id is unique', () {
      final ids = dimensionTemplates.map((t) => t.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });

    test('every template has unique level ids within itself', () {
      for (final t in dimensionTemplates) {
        final ids = t.levels.map((l) => l.id).toList();
        expect(
          ids.toSet().length,
          equals(ids.length),
          reason: 'duplicate level ids in template ${t.id}',
        );
      }
    });

    test('catalog covers all 9 required groups', () {
      const required = <String>[
        'Gender',
        'Number',
        'Case',
        'Tense',
        'Aspect',
        'Person',
        'Mood',
        'Voice',
        'Definiteness',
      ];
      final groups = dimensionTemplates.map((t) => t.group).toSet();
      for (final g in required) {
        expect(groups, contains(g), reason: 'missing group $g');
      }
    });

    test('catalog contains specific required ids', () {
      const required = <String>[
        'gender.mf',
        'gender.mfn',
        'number.sg_pl',
        'case.nom_acc_gen_dat',
        'case.abs_erg_gen_dat',
        'tense.prs_pst_fut',
        'person.1_2_3',
        'mood.ind_subj_imp',
        'voice.act_pass',
        'definiteness.def_indef',
      ];
      final ids = dimensionTemplates.map((t) => t.id).toSet();
      for (final r in required) {
        expect(ids, contains(r), reason: 'missing template id $r');
      }
    });

    test('level abbreviations are unique within each template', () {
      for (final t in dimensionTemplates) {
        final abbrs = t.levels.map((l) => l.abbr).toList();
        expect(
          abbrs.toSet().length,
          equals(abbrs.length),
          reason: 'duplicate level abbrs in template ${t.id}',
        );
      }
    });
  });
}
