import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight Drift database used solely to issue customStatement against
/// a shared file-backed executor while seeding the v7 schema. By using a
/// real file (not in-memory) we can close this stub and then re-open
/// AppDatabase against the same file — Drift's onUpgrade will then run
/// because user_version=7 < schemaVersion=8.
class _SeedStub extends GeneratedDatabase {
  _SeedStub(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );

  Future<void> seedV7Schema() async {
    // v7 morphological_rules — has pos_id and pos_ids but NO kind/feature_bindings/input_pos_id/output_pos_id.
    await customStatement(
      'CREATE TABLE morphological_rules ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, '
      '"source" TEXT NOT NULL, '
      '"ordering" INTEGER NOT NULL DEFAULT 0, '
      '"is_active" INTEGER NOT NULL DEFAULT 1, '
      '"pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"pos_ids" TEXT NOT NULL DEFAULT \'\''
      ')',
    );
    await customStatement(
      'CREATE TABLE morphological_rule_exceptions ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"lexeme_id" INTEGER NOT NULL, '
      '"rule_id" INTEGER NOT NULL, '
      '"override_form" TEXT NOT NULL, '
      '"rule_source_snapshot" TEXT NOT NULL'
      ')',
    );
    await customStatement(
      'CREATE TABLE parts_of_speech ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, '
      '"abbreviation" TEXT NOT NULL'
      ')',
    );
    // v7 lexemes — has is_phonological_exception but NO skipped_dimensions_json.
    await customStatement(
      'CREATE TABLE lexemes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"ipa" TEXT NOT NULL, '
      '"root_id" TEXT, '
      '"rule_ids" TEXT, '
      '"computed_form" TEXT, '
      '"romanization" TEXT, '
      '"meaning" TEXT, '
      '"part_of_speech" TEXT, '
      '"is_phonological_exception" INTEGER NOT NULL DEFAULT 0'
      ')',
    );
    // Other v7 tables that AppDatabase expects to find on open. Without these,
    // beforeOpen safety net's PRAGMA foreign_keys would still succeed but the
    // schema validation may complain. Create the minimal set.
    await customStatement(
      'CREATE TABLE phonemes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"symbol" TEXT NOT NULL, '
      '"type" TEXT NOT NULL, '
      '"manner" TEXT, "place" TEXT, "voicing" TEXT, '
      '"height" TEXT, "backness" TEXT, "rounded" INTEGER, '
      '"custom_properties" TEXT'
      ')',
    );
    await customStatement(
      'CREATE TABLE natural_classes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, '
      '"phoneme_ids" TEXT NOT NULL'
      ')',
    );
    await customStatement(
      'CREATE TABLE phonotactic_templates ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pattern" TEXT NOT NULL, '
      '"description" TEXT, '
      '"is_active" INTEGER NOT NULL DEFAULT 1'
      ')',
    );
    await customStatement(
      'CREATE TABLE phonotactic_constraints ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pattern" TEXT NOT NULL, '
      '"description" TEXT, '
      '"is_active" INTEGER NOT NULL DEFAULT 1, '
      '"position" TEXT NOT NULL DEFAULT \'anywhere\''
      ')',
    );
    await customStatement(
      'CREATE TABLE romanization_mappings ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"ipa_symbol" TEXT NOT NULL, '
      '"latin_mapping" TEXT NOT NULL'
      ')',
    );
    await customStatement(
      'CREATE TABLE rewrite_rules ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"source" TEXT NOT NULL, '
      '"ordering" INTEGER NOT NULL DEFAULT 0'
      ')',
    );
    await customStatement(
      'CREATE TABLE project_settings ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"key" TEXT NOT NULL UNIQUE, '
      '"value" TEXT NOT NULL'
      ')',
    );
  }
}

/// Returns a unique temp .db path for migration tests.
Future<String> _tempDbFile() async {
  final dir = await Directory.systemTemp.createTemp('drift_v7_v8_');
  return '${dir.path}/project.db';
}

void main() {
  group('v7 -> v8 migration', () {
    late AppDatabase db;
    late String dbPath;

    Future<void> seedAndOpen({
      required Future<void> Function(GeneratedDatabase stub) seed,
    }) async {
      dbPath = await _tempDbFile();
      final stub = _SeedStub(NativeDatabase(File(dbPath)));
      await stub.seedV7Schema();
      await seed(stub);
      await stub.customStatement('PRAGMA user_version = 7');
      await stub.close();

      db = AppDatabase(NativeDatabase(File(dbPath)));
      // Force migration to run by issuing a query.
      await db.customSelect('SELECT 1').get();
    }

    tearDown(() async {
      await db.close();
      try {
        File(dbPath).parent.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('schemaVersion is 8', () async {
      await seedAndOpen(seed: (_) async {});
      expect(db.schemaVersion, equals(8));
    });

    test(
        'existing morphological rule gets kind=derivational and pos parsed into feature_bindings',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids) "
          "VALUES (10, 'Plural', '-s', 0, 1, NULL, '1,3')",
        );
      });
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(10)))
          .getSingle();
      expect(row.kind, equals('derivational'));
      expect(row.featureBindings.pos, equals([1, 3]));
      expect(row.featureBindings.dims, isEmpty);
      expect(row.inputPosId, equals(1));
      expect(row.outputPosId, equals(1));
      expect(row.name, equals('Plural'));
      expect(row.source, equals('-s'));
      expect(row.ordering, equals(0));
      expect(row.isActive, isTrue);
    });

    test('empty posIds migrates to empty pos list', () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids) "
          "VALUES (11, 'NoPos', '-x', 0, 1, NULL, '')",
        );
      });
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(11)))
          .getSingle();
      expect(row.kind, equals('derivational'));
      expect(row.featureBindings.pos, isEmpty);
      expect(row.inputPosId, isNull);
      expect(row.outputPosId, isNull);
    });

    test('malformed posIds tokens are skipped', () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids) "
          "VALUES (12, 'Malformed', '-y', 0, 1, NULL, '2,,x,5')",
        );
      });
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(12)))
          .getSingle();
      expect(row.featureBindings.pos, equals([2, 5]));
      expect(row.inputPosId, equals(2));
      expect(row.outputPosId, equals(2));
    });

    test('MorphologicalRuleExceptions rows survive migration unchanged',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids) "
          "VALUES (10, 'Plural', '-s', 0, 1, NULL, '1')",
        );
        await stub.customStatement(
          "INSERT INTO morphological_rule_exceptions (id, lexeme_id, rule_id, override_form, rule_source_snapshot) "
          "VALUES (100, 5, 10, 'mice', '-s')",
        );
      });
      final row = await (db.select(db.morphologicalRuleExceptions)
            ..where((t) => t.id.equals(100)))
          .getSingle();
      expect(row.id, equals(100));
      expect(row.lexemeId, equals(5));
      expect(row.ruleId, equals(10));
      expect(row.overrideForm, equals('mice'));
      expect(row.ruleSourceSnapshot, equals('-s'));
    });

    test('Dimensions table exists after migration', () async {
      await seedAndOpen(seed: (_) async {});
      final dims = await db.select(db.dimensions).get();
      expect(dims, isEmpty);
    });

    test('ParadigmCellOverrides table exists after migration', () async {
      await seedAndOpen(seed: (_) async {});
      final overrides = await db.select(db.paradigmCellOverrides).get();
      expect(overrides, isEmpty);
    });

    test('Lexemes.skippedDimensionsJson is readable and defaults to null',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (1, 'kat')",
        );
      });
      final row = await (db.select(db.lexemes)..where((t) => t.id.equals(1)))
          .getSingle();
      expect(row.skippedDimensionsJson, isNull);
      expect(row.ipa, equals('kat'));
    });

    test('FeatureBindings round-trips through Drift converter', () async {
      await seedAndOpen(seed: (_) async {});
      await db.into(db.morphologicalRules).insert(
            MorphologicalRulesCompanion.insert(
              name: 'Inflectional',
              source: '-um',
              kind: const Value('inflectional'),
              featureBindings: const Value(
                FeatureBindings(pos: [1], dims: {5: 2, 7: 4}),
              ),
            ),
          );
      final rows = await db.select(db.morphologicalRules).get();
      final row = rows.firstWhere((r) => r.name == 'Inflectional');
      expect(row.kind, equals('inflectional'));
      expect(row.featureBindings.pos, equals([1]));
      expect(row.featureBindings.dims, equals({5: 2, 7: 4}));
    });
  });
}
