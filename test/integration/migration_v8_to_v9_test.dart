import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight Drift database used solely to issue customStatement against
/// a shared file-backed executor while seeding the v8 schema. By using a
/// real file (not in-memory) we can close this stub and then re-open
/// AppDatabase against the same file — Drift's onUpgrade will then run
/// because user_version=8 < schemaVersion=9.
///
/// Mirrors [_SeedStub] in migration_v7_to_v8_test.dart — same contract, but
/// the target source shape is v8 instead of v7.
class _SeedStubV8 extends GeneratedDatabase {
  _SeedStubV8(super.executor);

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

  /// Creates every table in the v8 shape by hand, including v8 additions:
  ///   - dimensions (D-01)
  ///   - paradigm_cell_overrides (D-22)
  ///   - morphological_rules.kind / feature_bindings / input_pos_id / output_pos_id (D-17/19/20)
  ///   - lexemes.skipped_dimensions_json (D-07)
  ///
  /// Does NOT include any v9 additions — those must be introduced by the
  /// v8→v9 onUpgrade block running on top of this seed.
  Future<void> seedV8Schema() async {
    // v8 morphological_rules — has all v8 columns but NONE of the v9 additions
    // (auto_apply, inflectional_rule_pos junction). Note: the v8 shape already
    // includes pos_id + pos_ids (legacy, kept-and-ignored).
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
      '"output_pos_id" INTEGER REFERENCES parts_of_speech(id)'
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
    // v8 lexemes — has skipped_dimensions_json but NONE of the v9 additions
    // (derived_from_lexeme_id, derived_via_rule_id, root_only_via_derivations).
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
      '"skipped_dimensions_json" TEXT'
      ')',
    );
    // v8 dimensions + paradigm_cell_overrides
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
    // Other v8 tables that AppDatabase expects to find on open.
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
  final dir = await Directory.systemTemp.createTemp('drift_v8_v9_');
  return '${dir.path}/project.db';
}

void main() {
  group('v8 -> v9 migration', () {
    late AppDatabase db;
    late String dbPath;

    Future<void> seedAndOpen({
      required Future<void> Function(GeneratedDatabase stub) seed,
    }) async {
      dbPath = await _tempDbFile();
      final stub = _SeedStubV8(NativeDatabase(File(dbPath)));
      await stub.seedV8Schema();
      await seed(stub);
      await stub.customStatement('PRAGMA user_version = 8');
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

    test('schemaVersion reports 10 after migration (v8→v9→v10 chained)',
        () async {
      await seedAndOpen(seed: (_) async {});
      // schemaVersion now advances to 10 because plan 04-15 D-74 bumps the
      // migration tip to v10. The v8→v9 tests exercise the same chained path.
      expect(db.schemaVersion, equals(10));
    });

    test('Markers table exists and is empty after migration', () async {
      await seedAndOpen(seed: (_) async {});
      final markers = await db.select(db.markers).get();
      expect(markers, isEmpty);
    });

    test('InflectionalRulePOS table exists after migration', () async {
      await seedAndOpen(seed: (_) async {});
      final junction = await db.select(db.inflectionalRulePOS).get();
      expect(junction, isEmpty);
    });

    test('LexemeParents table exists after migration', () async {
      await seedAndOpen(seed: (_) async {});
      final parents = await db.select(db.lexemeParents).get();
      expect(parents, isEmpty);
    });

    test(
        'MorphologicalRules.autoApply column exists and defaults to false on pre-existing rows',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (30, 'Agentive', '-er', 0, 1, NULL, '', 'derivational', '{}', 1, 1)",
        );
      });
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(30)))
          .getSingle();
      expect(row.autoApply, isFalse);
    });

    test(
        'Lexemes.derivedFromLexemeId exists and is NULL for pre-existing rows',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (1, 'kat')",
        );
      });
      final row = await (db.select(db.lexemes)..where((t) => t.id.equals(1)))
          .getSingle();
      expect(row.derivedFromLexemeId, isNull);
    });

    test(
        'Lexemes.derivedViaRuleId exists and is NULL for pre-existing rows',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (1, 'dog')",
        );
      });
      final row = await (db.select(db.lexemes)..where((t) => t.id.equals(1)))
          .getSingle();
      expect(row.derivedViaRuleId, isNull);
    });

    test(
        'Lexemes.rootOnlyViaDerivations exists and defaults to false on pre-existing rows',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (1, 'bird')",
        );
      });
      final row = await (db.select(db.lexemes)..where((t) => t.id.equals(1)))
          .getSingle();
      expect(row.rootOnlyViaDerivations, isFalse);
    });

    test(
        'InflectionalRulePOS backfill: inflectional rule with input_pos_id gets one junction row',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (20, 'Plural', '-s', 0, 1, NULL, '', 'inflectional', '{\"pos\":[3],\"dims\":{\"5\":2}}', 3, 3)",
        );
      });
      final row = await (db.select(db.inflectionalRulePOS)
            ..where((t) => t.ruleId.equals(20)))
          .getSingle();
      expect(row.posId, equals(3));
    });

    test(
        'InflectionalRulePOS backfill: derivational rules are NOT backfilled',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (21, 'Agentive', '-er', 0, 1, NULL, '', 'derivational', '{}', 1, 1)",
        );
      });
      final junction = await (db.select(db.inflectionalRulePOS)
            ..where((t) => t.ruleId.equals(21)))
          .get();
      expect(junction, isEmpty);
    });

    test(
        'InflectionalRulePOS backfill: inflectional rules with NULL input_pos_id are skipped',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (22, 'Ambiguous', '-x', 0, 1, NULL, '', 'inflectional', '{}', NULL, NULL)",
        );
      });
      final junction = await (db.select(db.inflectionalRulePOS)
            ..where((t) => t.ruleId.equals(22)))
          .get();
      expect(junction, isEmpty);
    });

    test(
        'InflectionalRulePOS backfill: mixed seed (inflectional+derivational+null) produces exactly one junction row',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (20, 'Plural', '-s', 0, 1, NULL, '', 'inflectional', '{}', 3, 3)",
        );
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (21, 'Agentive', '-er', 0, 1, NULL, '', 'derivational', '{}', 1, 1)",
        );
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (22, 'Ambiguous', '-x', 0, 1, NULL, '', 'inflectional', '{}', NULL, NULL)",
        );
      });
      final junction = await db.select(db.inflectionalRulePOS).get();
      expect(junction, hasLength(1));
      expect(junction.single.ruleId, equals(20));
      expect(junction.single.posId, equals(3));
    });

    test('pre-existing v8 Dimensions rows survive migration', () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO parts_of_speech (id, name, abbreviation) VALUES (1, 'Noun', 'N')",
        );
        await stub.customStatement(
          "INSERT INTO dimensions (id, pos_id, name, ordering, levels_json, template_id) "
          "VALUES (5, 1, 'Number', 0, '[{\"id\":1,\"name\":\"SG\",\"abbr\":\"SG\",\"ordering\":0}]', NULL)",
        );
      });
      final row =
          await (db.select(db.dimensions)..where((t) => t.id.equals(5)))
              .getSingle();
      expect(row.posId, equals(1));
      expect(row.name, equals('Number'));
    });

    test('pre-existing v8 ParadigmCellOverrides rows survive migration',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO lexemes (id, ipa) VALUES (7, 'gato')",
        );
        await stub.customStatement(
          "INSERT INTO paradigm_cell_overrides (id, lexeme_id, feature_set_json, override_ipa, override_romanization, notes) "
          "VALUES (11, 7, '{\"5\":2}', 'gatos', 'gatos', NULL)",
        );
      });
      final row = await (db.select(db.paradigmCellOverrides)
            ..where((t) => t.id.equals(11)))
          .getSingle();
      expect(row.lexemeId, equals(7));
      expect(row.overrideIpa, equals('gatos'));
    });

    test('pre-existing MorphologicalRuleExceptions rows survive migration',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO morphological_rules (id, name, source, ordering, is_active, pos_id, pos_ids, kind, feature_bindings, input_pos_id, output_pos_id) "
          "VALUES (10, 'Plural', '-s', 0, 1, NULL, '', 'inflectional', '{}', 1, 1)",
        );
        await stub.customStatement(
          "INSERT INTO morphological_rule_exceptions (id, lexeme_id, rule_id, override_form, rule_source_snapshot) "
          "VALUES (100, 5, 10, 'mice', '-s')",
        );
      });
      final row = await (db.select(db.morphologicalRuleExceptions)
            ..where((t) => t.id.equals(100)))
          .getSingle();
      expect(row.overrideForm, equals('mice'));
    });

    test('beforeOpen safety net is idempotent across reopen', () async {
      await seedAndOpen(seed: (_) async {});
      // Close and reopen on the same file path — beforeOpen must not throw
      // "duplicate column" or "table already exists" on the second open.
      await db.close();
      db = AppDatabase(NativeDatabase(File(dbPath)));
      await db.customSelect('SELECT 1').get();
      expect(db.schemaVersion, equals(10));
    });

    test(
        'FeatureBindings converter round-trips on Markers.featureBindings',
        () async {
      await seedAndOpen(seed: (stub) async {
        await stub.customStatement(
          "INSERT INTO parts_of_speech (id, name, abbreviation) VALUES (1, 'Noun', 'N')",
        );
      });
      // Insert a marker via the typed Drift companion to prove the FeatureBindingsConverter
      // works on the Markers table as well (the mapping type from MorphologicalRules).
      // NOTE: FeatureBindings JSON is FLAT — pos under "pos" key, dims as
      // stringified dimension ids at the top level. See feature_bindings.dart.
      await db.customStatement(
        "INSERT INTO markers (pos_id, feature_bindings) VALUES (1, '{\"pos\":[1],\"5\":2}')",
      );
      final markers = await db.select(db.markers).get();
      expect(markers, hasLength(1));
      expect(markers.single.posId, equals(1));
      expect(markers.single.featureBindings.pos, equals([1]));
      expect(markers.single.featureBindings.dims, equals({5: 2}));
    });
  });
}
