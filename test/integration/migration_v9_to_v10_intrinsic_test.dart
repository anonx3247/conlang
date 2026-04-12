import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 04-17 Task 1 — D-82 / D-83 / D-97 schema integration tests.
///
/// Seeds a real file-backed SQLite at the v9 schema, opens [AppDatabase]
/// so the v10 onUpgrade block runs (which now includes the 04-17 additions
/// appended to the 04-15 v10 block in-place — NO v11 bump), and asserts:
///
/// 1. `dimensions.intrinsic` column exists with default 0 on existing rows.
/// 2. `lexemes.intrinsic_levels_json` column exists, NULL on existing rows.
/// 3. `standard_form_patterns` table exists with the expected columns.
/// 4. The composite primary key `(dimension_id, level_id)` blocks duplicates.
/// 5. Cascade-delete on `dimensions` removes referencing pattern rows.
/// 6. `schemaVersion` is still 10 (no v11 bump).

class _SeedStubV9 extends GeneratedDatabase {
  _SeedStubV9(super.executor);

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

  /// Seeds the v9 schema (mirrors `migration_v9_to_v10_test.dart` exactly so
  /// the same fixture shape is exercised).
  Future<void> seedV9Schema() async {
    await customStatement(
      'CREATE TABLE morphological_rules ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, '
      '"source" TEXT NOT NULL, '
      '"ordering" INTEGER NOT NULL DEFAULT 0, '
      '"is_active" INTEGER NOT NULL DEFAULT 1, '
      '"pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"pos_ids" TEXT NOT NULL DEFAULT \'\', '
      '"kind" TEXT NOT NULL DEFAULT \'derivational\', '
      '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\', '
      '"input_pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"output_pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"auto_apply" INTEGER NOT NULL DEFAULT 0'
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
      '"is_phonological_exception" INTEGER NOT NULL DEFAULT 0, '
      '"skipped_dimensions_json" TEXT, '
      '"derived_from_lexeme_id" INTEGER, '
      '"derived_via_rule_id" INTEGER, '
      '"root_only_via_derivations" INTEGER NOT NULL DEFAULT 0'
      ')',
    );
    await customStatement(
      'CREATE TABLE dimensions ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      '"name" TEXT NOT NULL, '
      '"ordering" INTEGER NOT NULL DEFAULT 0, '
      '"levels_json" TEXT NOT NULL, '
      '"template_id" TEXT'
      ')',
    );
    await customStatement(
      'CREATE TABLE paradigm_cell_overrides ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"feature_set_json" TEXT NOT NULL, '
      '"override_ipa" TEXT NOT NULL, '
      '"override_romanization" TEXT, '
      '"notes" TEXT'
      ')',
    );
    await customStatement(
      'CREATE TABLE markers ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\''
      ')',
    );
    await customStatement(
      'CREATE TABLE inflectional_rule_pos ('
      '"rule_id" INTEGER NOT NULL REFERENCES morphological_rules(id) ON DELETE CASCADE, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      'PRIMARY KEY (rule_id, pos_id)'
      ')',
    );
    await customStatement(
      'CREATE TABLE lexeme_parents ('
      '"child_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"parent_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"via_rule_id" INTEGER REFERENCES morphological_rules(id) ON DELETE SET NULL, '
      'PRIMARY KEY (child_lexeme_id, parent_lexeme_id)'
      ')',
    );
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

Future<String> _tempDbFile() async {
  final dir = await Directory.systemTemp.createTemp('drift_v9_v10_intrinsic_');
  return '${dir.path}/project.db';
}

void main() {
  group('v9 -> v10 intrinsic schema migration (Plan 04-17 D-82/D-83/D-97)', () {
    late AppDatabase db;
    late String dbPath;

    Future<void> seedAndOpen({
      Future<void> Function(GeneratedDatabase stub)? extraSeed,
    }) async {
      dbPath = await _tempDbFile();
      final stub = _SeedStubV9(NativeDatabase(File(dbPath)));
      await stub.seedV9Schema();
      // Seed one POS, one dimension, one lexeme so we can verify
      // post-migration column defaults on real rows.
      await stub.customStatement(
        "INSERT INTO parts_of_speech (id, name, abbreviation) VALUES (1, 'noun', 'N')",
      );
      await stub.customStatement(
        "INSERT INTO dimensions (id, pos_id, name, ordering, levels_json) "
        "VALUES (1, 1, 'gender', 0, '[]')",
      );
      await stub.customStatement(
        "INSERT INTO lexemes (id, ipa, part_of_speech) VALUES (1, 'kasa', 'noun')",
      );
      if (extraSeed != null) await extraSeed(stub);
      await stub.customStatement('PRAGMA user_version = 9');
      await stub.close();

      db = AppDatabase(NativeDatabase(File(dbPath)));
      await db.customSelect('SELECT 1').get();
    }

    tearDown(() async {
      await db.close();
      try {
        File(dbPath).parent.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('schemaVersion is 10 (no v11 bump)', () async {
      await seedAndOpen();
      expect(db.schemaVersion, equals(10));
    });

    test('dimensions.intrinsic column exists with default 0 on existing rows',
        () async {
      await seedAndOpen();
      final row = await db
          .customSelect('SELECT intrinsic FROM dimensions WHERE id = 1')
          .getSingle();
      expect(row.read<int>('intrinsic'), equals(0));
    });

    test('lexemes.intrinsic_levels_json column exists, NULL on existing rows',
        () async {
      await seedAndOpen();
      final row = await db
          .customSelect(
              'SELECT intrinsic_levels_json FROM lexemes WHERE id = 1')
          .getSingle();
      expect(row.data['intrinsic_levels_json'], isNull);
    });

    test('standard_form_patterns table exists with the expected columns',
        () async {
      await seedAndOpen();
      final tableRow = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'standard_form_patterns'")
          .getSingleOrNull();
      expect(tableRow, isNotNull,
          reason: 'standard_form_patterns table must exist post-migration');
      final cols =
          await db.customSelect('PRAGMA table_info(standard_form_patterns)').get();
      final colNames = cols.map((r) => r.read<String>('name')).toSet();
      expect(colNames, contains('dimension_id'));
      expect(colNames, contains('level_id'));
      expect(colNames, contains('branches_json'));
    });

    test('composite primary key (dimension_id, level_id) blocks duplicates',
        () async {
      await seedAndOpen();
      await db.customStatement(
        "INSERT INTO standard_form_patterns (dimension_id, level_id, branches_json) "
        "VALUES (1, 1, '[]')",
      );
      // Second insert with the same PK pair should fail.
      Object? error;
      try {
        await db.customStatement(
          "INSERT INTO standard_form_patterns (dimension_id, level_id, branches_json) "
          "VALUES (1, 1, '[]')",
        );
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'duplicate (dimension_id, level_id) insert must error');
    });

    test('cascade-delete on dimensions removes referencing pattern rows',
        () async {
      await seedAndOpen();
      await db.customStatement(
        "INSERT INTO standard_form_patterns (dimension_id, level_id, branches_json) "
        "VALUES (1, 1, '[]')",
      );
      // Confirm row exists.
      var rows = await db
          .customSelect(
              'SELECT COUNT(*) AS c FROM standard_form_patterns WHERE dimension_id = 1')
          .getSingle();
      expect(rows.read<int>('c'), equals(1));
      // Delete the dimension; FK cascade should remove the pattern row.
      await db.customStatement('DELETE FROM dimensions WHERE id = 1');
      rows = await db
          .customSelect(
              'SELECT COUNT(*) AS c FROM standard_form_patterns WHERE dimension_id = 1')
          .getSingle();
      expect(rows.read<int>('c'), equals(0));
    });
  });
}
