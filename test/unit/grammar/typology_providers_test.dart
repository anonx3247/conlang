import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_axes.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParadigmAxes', () {
    test('toJson/fromJson round-trip', () {
      const a = ParadigmAxes(rows: 10, cols: 11, tabs: [12, 13]);
      final json = a.toJson();
      expect(json['rows'], equals(10));
      expect(json['cols'], equals(11));
      expect(json['tabs'], equals([12, 13]));
      expect(ParadigmAxes.fromJson(json), equals(a));
    });

    test('JSON string round-trip', () {
      const a = ParadigmAxes(rows: 1, cols: 2, tabs: [3]);
      expect(ParadigmAxes.fromJsonString(a.toJsonString()), equals(a));
    });

    test('empty string parses to empty axes (T-04-11 defense)', () {
      expect(ParadigmAxes.fromJsonString(''), equals(const ParadigmAxes()));
    });

    test('malformed JSON parses to empty axes (T-04-11 defense)', () {
      expect(ParadigmAxes.fromJsonString('not a json'),
          equals(const ParadigmAxes()));
      expect(ParadigmAxes.fromJsonString('[1,2,3]'),
          equals(const ParadigmAxes()));
    });

    test('defaultsFor with 0 dims returns empty axes', () {
      expect(ParadigmAxes.defaultsFor(const []), equals(const ParadigmAxes()));
    });

    test('defaultsFor with 1 dim sets rows only', () {
      final axes = ParadigmAxes.defaultsFor([
        _dim(id: 7, posId: 1, name: 'Gender'),
      ]);
      expect(axes.rows, equals(7));
      expect(axes.cols, isNull);
      expect(axes.tabs, isEmpty);
    });

    test('defaultsFor with 3 dims sets rows, cols, and tabs', () {
      final axes = ParadigmAxes.defaultsFor([
        _dim(id: 10, posId: 1, name: 'Gender'),
        _dim(id: 11, posId: 1, name: 'Number'),
        _dim(id: 12, posId: 1, name: 'Case'),
      ]);
      expect(axes.rows, equals(10));
      expect(axes.cols, equals(11));
      expect(axes.tabs, equals([12]));
    });
  });

  group('TypologySettings', () {
    test('readTypologySettings returns defaults when project_settings empty',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = await readTypologySettings(db);
      expect(settings.alignment, isNull);
      expect(settings.wordOrder, isNull);
      expect(settings.modality, isNull);
    });

    test('readTypologySettings reads all three typology keys', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.projectSettings).insert(
            ProjectSettingsCompanion.insert(
              key: 'typology.alignment',
              value: 'erg_abs',
            ),
          );
      await db.into(db.projectSettings).insert(
            ProjectSettingsCompanion.insert(
              key: 'typology.word_order',
              value: 'SOV',
            ),
          );
      await db.into(db.projectSettings).insert(
            ProjectSettingsCompanion.insert(
              key: 'typology.modality',
              value: 'synthetic',
            ),
          );
      final settings = await readTypologySettings(db);
      expect(settings.alignment, equals('erg_abs'));
      expect(settings.wordOrder, equals('SOV'));
      expect(settings.modality, equals('synthetic'));
    });

    test('writeTypologyKey then readTypologySettings round-trip', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await writeTypologyKey(db, 'typology.alignment', 'nom_acc');
      await writeTypologyKey(db, 'typology.alignment', 'nom_acc'); // upsert
      final settings = await readTypologySettings(db);
      expect(settings.alignment, equals('nom_acc'));
    });
  });

  group('Paradigm axes persistence', () {
    test('readParadigmAxes returns defaults when no row exists', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final axes = await readParadigmAxes(db, posId: 1);
      // No dims either, so defaults = empty.
      expect(axes, equals(const ParadigmAxes()));
    });

    test('writeParadigmAxes then readParadigmAxes round-trip', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      const axes = ParadigmAxes(rows: 10, cols: 11, tabs: [12]);
      await writeParadigmAxes(db, posId: 1, axes: axes);
      final got = await readParadigmAxes(db, posId: 1);
      expect(got, equals(axes));
    });

    test('writeParadigmAxes upserts on second call', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await writeParadigmAxes(db,
          posId: 1, axes: const ParadigmAxes(rows: 10));
      await writeParadigmAxes(db,
          posId: 1, axes: const ParadigmAxes(rows: 20, cols: 21));
      final got = await readParadigmAxes(db, posId: 1);
      expect(got, equals(const ParadigmAxes(rows: 20, cols: 21)));
      // Only one row should exist for this key.
      final rows = await (db.select(db.projectSettings)
            ..where((t) => t.key.equals('typology.paradigm_axes.1')))
          .get();
      expect(rows.length, equals(1));
    });
  });
}

/// Helper to construct a Drift [Dimension] DataClass inline for pure-value
/// tests of `ParadigmAxes.defaultsFor`. No DB involved.
Dimension _dim({required int id, required int posId, required String name}) {
  return Dimension(
    id: id,
    posId: posId,
    name: name,
    ordering: 0,
    levelsJson: '[]',
    templateId: null,
  );
}
