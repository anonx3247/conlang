import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight GeneratedDatabase stub used only to issue raw SQL against a
/// file-backed executor while seeding the v14 schema. Once seeded and closed,
/// AppDatabase is opened against the same file so onUpgrade(14 -> 15) runs.
///
/// Mirrors _SeedStubV8 in migration_v8_to_v9_test.dart — same contract.
class _SeedStubV14 extends GeneratedDatabase {
  _SeedStubV14(super.executor);

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

  /// Creates every table in the v14 shape so AppDatabase.onUpgrade sees a
  /// proper v14 database and only runs the v15 migration block.
  Future<void> seedV14Schema() async {
    await customStatement(
      'CREATE TABLE phonemes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"symbol" TEXT NOT NULL, "type" TEXT NOT NULL, '
      '"manner" TEXT, "place" TEXT, "voicing" TEXT, '
      '"height" TEXT, "backness" TEXT, "rounded" INTEGER, '
      '"custom_properties" TEXT)',
    );
    await customStatement(
      'CREATE TABLE natural_classes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, "phoneme_ids" TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE phonotactic_templates ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pattern" TEXT NOT NULL, "description" TEXT, '
      '"is_active" INTEGER NOT NULL DEFAULT 1)',
    );
    await customStatement(
      'CREATE TABLE phonotactic_constraints ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pattern" TEXT NOT NULL, "description" TEXT, '
      '"is_active" INTEGER NOT NULL DEFAULT 1, '
      '"position" TEXT NOT NULL DEFAULT \'anywhere\', '
      '"type" TEXT NOT NULL DEFAULT \'sequence\')',
    );
    await customStatement(
      'CREATE TABLE romanization_mappings ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"ipa_symbol" TEXT NOT NULL, "latin_mapping" TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE rewrite_rules ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"source" TEXT NOT NULL, "ordering" INTEGER NOT NULL DEFAULT 0)',
    );
    await customStatement(
      'CREATE TABLE project_settings ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"key" TEXT NOT NULL UNIQUE, "value" TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE parts_of_speech ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, "abbreviation" TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE morphological_rules ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"name" TEXT NOT NULL, "source" TEXT NOT NULL, '
      '"ordering" INTEGER NOT NULL DEFAULT 0, '
      '"is_active" INTEGER NOT NULL DEFAULT 1, '
      '"pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"pos_ids" TEXT NOT NULL DEFAULT \'\', '
      '"kind" TEXT NOT NULL DEFAULT \'derivational\', '
      '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\', '
      '"input_pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"output_pos_id" INTEGER REFERENCES parts_of_speech(id), '
      '"auto_apply" INTEGER NOT NULL DEFAULT 0)',
    );
    await customStatement(
      'CREATE TABLE morphological_rule_exceptions ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"lexeme_id" INTEGER NOT NULL, "rule_id" INTEGER NOT NULL, '
      '"override_form" TEXT NOT NULL, "rule_source_snapshot" TEXT NOT NULL)',
    );
    // v14 lexemes — all columns through v10, NO v15 additions
    await customStatement(
      'CREATE TABLE lexemes ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"ipa" TEXT NOT NULL, '
      '"root_id" TEXT, "rule_ids" TEXT, "computed_form" TEXT, '
      '"romanization" TEXT, "meaning" TEXT, "part_of_speech" TEXT, '
      '"is_phonological_exception" INTEGER NOT NULL DEFAULT 0, '
      '"skipped_dimensions_json" TEXT, '
      '"derived_from_lexeme_id" INTEGER REFERENCES lexemes(id), '
      '"derived_via_rule_id" INTEGER REFERENCES morphological_rules(id), '
      '"root_only_via_derivations" INTEGER NOT NULL DEFAULT 0, '
      '"intrinsic_levels_json" TEXT)',
    );
    await customStatement(
      'CREATE TABLE dimensions ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      '"name" TEXT NOT NULL, "ordering" INTEGER NOT NULL DEFAULT 0, '
      '"levels_json" TEXT NOT NULL, "template_id" TEXT, '
      '"intrinsic" INTEGER NOT NULL DEFAULT 0, '
      '"abbreviation" TEXT)',
    );
    await customStatement(
      'CREATE TABLE paradigm_cell_overrides ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"feature_set_json" TEXT NOT NULL, '
      '"override_ipa" TEXT NOT NULL, '
      '"override_romanization" TEXT, "notes" TEXT)',
    );
    await customStatement(
      'CREATE TABLE markers ('
      '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      '"name" TEXT NOT NULL DEFAULT \'Unmarked\', '
      '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\')',
    );
    await customStatement(
      'CREATE TABLE inflectional_rule_pos ('
      '"rule_id" INTEGER NOT NULL REFERENCES morphological_rules(id) ON DELETE CASCADE, '
      '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
      'PRIMARY KEY ("rule_id", "pos_id"))',
    );
    await customStatement(
      'CREATE TABLE lexeme_parents ('
      '"child_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"parent_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
      '"relationship" TEXT, "notes" TEXT, '
      'PRIMARY KEY ("child_lexeme_id", "parent_lexeme_id"))',
    );
    await customStatement(
      'CREATE TABLE standard_form_patterns ('
      '"dimension_id" INTEGER NOT NULL REFERENCES dimensions(id) ON DELETE CASCADE, '
      '"level_id" INTEGER NOT NULL, "branches_json" TEXT NOT NULL, '
      'PRIMARY KEY ("dimension_id", "level_id"))',
    );
    // v13 culture_pages (kept for migration compat)
    await customStatement('''
      CREATE TABLE IF NOT EXISTS culture_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER REFERENCES culture_pages(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        icon TEXT,
        ordering INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }
}

Future<String> _tempDbFile() async {
  final dir = await Directory.systemTemp.createTemp('drift_v14_v15_');
  return '${dir.path}/project.db';
}

void main() {
  group('v14 -> v15 migration', () {
    late AppDatabase db;
    late String dbPath;

    Future<void> seedAndOpen({
      Future<void> Function(GeneratedDatabase stub)? seed,
    }) async {
      dbPath = await _tempDbFile();
      final stub = _SeedStubV14(NativeDatabase(File(dbPath)));
      await stub.seedV14Schema();
      if (seed != null) await seed(stub);
      await stub.customStatement('PRAGMA user_version = 14');
      await stub.close();

      db = AppDatabase(NativeDatabase(File(dbPath)));
      // Force migration by issuing a query.
      await db.customSelect('SELECT 1').get();
    }

    tearDown(() async {
      await db.close();
      try {
        File(dbPath).parent.deleteSync(recursive: true);
      } catch (_) {}
    });

    // Test 1: lexemes table gains is_closed_class and gloss_tag after migration
    test(
        'lexemes table has is_closed_class (boolean, default false) after migration',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (1, 'ka')",
        );
      });
      final row = await db.customSelect(
        'SELECT is_closed_class, gloss_tag FROM lexemes WHERE id = 1',
      ).getSingle();
      expect(row.read<int>('is_closed_class'), equals(0));
      expect(row.read<String?>('gloss_tag'), isNull);
    });

    // Test 2: phrase_constructions table created with correct columns
    test('phrase_constructions table has id, name, ordering columns', () async {
      await seedAndOpen();
      await db.customStatement(
        "INSERT INTO phrase_constructions (name, ordering) VALUES ('S V O', 0)",
      );
      final row =
          await db.customSelect('SELECT * FROM phrase_constructions').getSingle();
      expect(row.read<String>('name'), equals('S V O'));
      expect(row.read<int>('ordering'), equals(0));
    });

    // Test 3: construction_slots table created with FK to phrase_constructions
    test(
        'construction_slots table has construction_id FK, slot_type, slot_value, label, ordering',
        () async {
      await seedAndOpen();
      await db.customStatement(
        "INSERT INTO phrase_constructions (id, name, ordering) VALUES (10, 'NP VP', 0)",
      );
      await db.customStatement(
        "INSERT INTO construction_slots (construction_id, slot_type, slot_value, label, ordering) "
        "VALUES (10, 'pos', 'N', 'Subject', 0)",
      );
      final row =
          await db.customSelect('SELECT * FROM construction_slots').getSingle();
      expect(row.read<int>('construction_id'), equals(10));
      expect(row.read<String>('slot_type'), equals('pos'));
      expect(row.read<String>('slot_value'), equals('N'));
      expect(row.read<String?>('label'), equals('Subject'));
      expect(row.read<int>('ordering'), equals(0));
    });

    // Bonus: schemaVersion is now 15
    test('schemaVersion reports 15 after migration', () async {
      await seedAndOpen();
      expect(db.schemaVersion, equals(15));
    });
  });
}
