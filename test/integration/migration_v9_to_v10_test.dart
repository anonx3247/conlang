import 'dart:convert';
import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 04-15 D-74 — v9 → v10 migration integration tests.
///
/// Seeds a real file-backed SQLite at the v9 schema, populates
/// romanization_mappings + morphological_rules with both pure-affix and
/// ablaut rule shapes, opens [AppDatabase] so the v10 onUpgrade block runs,
/// and asserts:
///
/// 1. schemaVersion advances to 10.
/// 2. Pure-rom-affix rules are rewritten to phonemic form.
/// 3. Already-phonemic rules are left unchanged.
/// 4. Ablaut rules have their FROM/TO rewritten but FLAG SEGMENT PRESERVED
///    as ASCII (the critical regression lock — a string-level classify
///    would have rewritten `e1` → `ε1`, silently flipping direction).
/// 5. Unparseable rule sources are left untouched with the expected
///    migration_log reason.
/// 6. D-78 dot-separator rules are correctly handled via the shared
///    notation_helpers dotAwareDeromanize / smartRomanize helpers.
/// 7. The `notation_migration_v10` entry in project_settings contains a
///    JSON outcomes array with one entry per rule and correct before/after
///    values.

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

  /// Creates every table in the v9 shape by hand. Mirrors [_SeedStubV8] in
  /// migration_v8_to_v9_test.dart but at the v9 tip (v9 additions already
  /// present: markers, inflectional_rule_pos, lexeme_parents, auto_apply,
  /// derived_from_lexeme_id, derived_via_rule_id, root_only_via_derivations).
  /// v10 additions (none to the schema — v10 is a data-only migration in
  /// 04-15) are NOT present.
  Future<void> seedV9Schema() async {
    // morphological_rules — full v9 shape including v8 additions (kind,
    // feature_bindings, input_pos_id, output_pos_id) and v9 auto_apply.
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
    // lexemes — full v9 shape with all Phase 4 gap-closure columns.
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
    // v9 additions
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
    // Other v9-required tables that AppDatabase expects to find.
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
  final dir = await Directory.systemTemp.createTemp('drift_v9_v10_');
  return '${dir.path}/project.db';
}

/// Seeds the shared dogfood-like mapping set used by most tests:
/// `{k→c, ø→o, ε→e, æ→a, m→m, i→i, s→s}`. This mirrors a subset of the
/// real user's mapping on purpose so the ablaut regression lock replicates
/// the actual failure mode.
const _dogfoodMappings = <(String, String)>[
  ('k', 'c'),
  ('ø', 'o'),
  ('ε', 'e'),
  ('æ', 'a'),
  ('m', 'm'),
  ('i', 'i'),
  ('s', 's'),
];

/// Seeds the D-78 canonical dot-disambiguation mapping set
/// `{a→a, t→t, h→h, θ→th}`.
const _dotMappings = <(String, String)>[
  ('a', 'a'),
  ('t', 't'),
  ('h', 'h'),
  ('θ', 'th'),
];

void main() {
  group('v9 -> v10 notation migration', () {
    late AppDatabase db;
    late String dbPath;

    Future<void> seedAndOpen({
      required Future<void> Function(GeneratedDatabase stub) seed,
    }) async {
      dbPath = await _tempDbFile();
      final stub = _SeedStubV9(NativeDatabase(File(dbPath)));
      await stub.seedV9Schema();
      await seed(stub);
      await stub.customStatement('PRAGMA user_version = 9');
      await stub.close();

      db = AppDatabase(NativeDatabase(File(dbPath)));
      // Force migration to run by issuing a query.
      await db.customSelect('SELECT 1').get();
    }

    Future<void> seedMappings(
      GeneratedDatabase stub,
      List<(String, String)> mappings,
    ) async {
      for (final (ipa, latin) in mappings) {
        await stub.customStatement(
          'INSERT INTO romanization_mappings (ipa_symbol, latin_mapping) VALUES (?, ?)',
          [ipa, latin],
        );
      }
    }

    Future<void> seedRule(
      GeneratedDatabase stub, {
      required int id,
      required String name,
      required String source,
      String kind = 'inflectional',
    }) async {
      await stub.customStatement(
        'INSERT INTO morphological_rules '
        '(id, name, source, ordering, is_active, pos_id, pos_ids, kind, '
        'feature_bindings, input_pos_id, output_pos_id, auto_apply) '
        "VALUES (?, ?, ?, 0, 1, NULL, '', ?, '{}', NULL, NULL, 0)",
        [id, name, source, kind],
      );
    }

    Future<String> ruleSource(int id) async {
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      return row.source;
    }

    tearDown(() async {
      await db.close();
      try {
        File(dbPath).parent.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('schemaVersion reports 10 after migration', () async {
      await seedAndOpen(seed: (_) async {});
      expect(db.schemaVersion, equals(10));
    });

    test('pure rom suffix `+moc` rewrites to phonemic `+møk`', () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(stub, id: 1, name: 'Simple Past', source: '+moc');
      });
      expect(await ruleSource(1), equals('+møk'));
    });

    test('already-phonemic suffix `+møk` is left unchanged', () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(stub, id: 1, name: 'Past', source: '+møk');
      });
      expect(await ruleSource(1), equals('+møk'));
    });

    test('prefix `ca+` rewrites to `kæ+`', () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(stub, id: 1, name: 'Habitual', source: 'ca+');
      });
      expect(await ruleSource(1), equals('kæ+'));
    });

    test(
        'REGRESSION LOCK: ablaut `/V/o/e1` rewrites FROM/TO but PRESERVES ASCII `e1` flag',
        () async {
      // This is the test that would have caught the dropped earlier attempt.
      // A string-level classify would have rewritten the `e` in the `e1`
      // flag to `ε` under the `e → ε` mapping, silently flipping ablaut
      // direction from fromEnd to fromStart.
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(
          stub,
          id: 11,
          name: 'Masculine',
          source: r'"V"$ /V/o/e1 | "C"$ +o',
        );
      });
      final source = await ruleSource(11);
      expect(source, equals(r'"V"$ /V/ø/e1 | "C"$ +ø'));
      // Explicit invariant assertions.
      expect(source.contains('/e1'), isTrue,
          reason: 'ablaut flag must preserve ASCII `e1`');
      expect(source.contains('ε1'), isFalse,
          reason:
              'ablaut flag must NOT be rewritten to `ε1` — that was the dropped attempt\'s regression');
    });

    test('REGRESSION LOCK: second ablaut shape `/V/a/e1` preserves flag too',
        () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(
          stub,
          id: 13,
          name: 'Feminine',
          source: r'"C"$ +a | "V"$ /V/a/e1',
        );
      });
      final source = await ruleSource(13);
      expect(source, equals(r'"C"$ +æ | "V"$ /V/æ/e1'));
      expect(source.endsWith('/e1'), isTrue);
    });

    test('condition with literal phoneme (k endsWith + affixes) left alone',
        () async {
      // `k` is a phoneme (ipa_symbol, not latin_mapping), affixes `i` and
      // `ki` are non-round-trip after classify. Entire rule left alone.
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(
          stub,
          id: 14,
          name: 'Agent',
          source: r'"k"$ +i | +ki',
          kind: 'derivational',
        );
      });
      expect(await ruleSource(14), equals(r'"k"$ +i | +ki'));
    });

    test('unparseable rule source is left alone', () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(
          stub,
          id: 99,
          name: 'Garbage',
          source: ')))unparseable(((',
        );
      });
      expect(await ruleSource(99), equals(')))unparseable((('));
    });

    test('D-78 dot separator in affix: `+at.ha` rewrites to phonemic `+atha`',
        () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dotMappings);
        await seedRule(stub, id: 1, name: 'DotRule', source: '+at.ha');
      });
      expect(await ruleSource(1), equals('+atha'));
    });

    test('D-78 undotted rom rewrites to θ reading', () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dotMappings);
        await seedRule(stub, id: 1, name: 'NoDotRule', source: '+atha');
      });
      // `atha` under {θ→th} longest-matches `th` → phonemic `aθa`.
      expect(await ruleSource(1), equals('+aθa'));
    });

    test('migration_log entry in project_settings has one outcome per rule',
        () async {
      await seedAndOpen(seed: (stub) async {
        await seedMappings(stub, _dogfoodMappings);
        await seedRule(stub, id: 1, name: 'Rewrite', source: '+moc');
        await seedRule(stub, id: 2, name: 'LeftAlone', source: '+møk');
        await seedRule(stub, id: 3, name: 'Garbage', source: ')))xxx(((');
      });
      final settingsRow = await (db.select(db.projectSettings)
            ..where((t) => t.key.equals('notation_migration_v10')))
          .getSingle();
      final log = jsonDecode(settingsRow.value) as Map<String, dynamic>;
      expect(log['plan'], equals('04-15'));
      final outcomes = log['outcomes'] as List;
      expect(outcomes, hasLength(3));

      final byId = {
        for (final o in outcomes.cast<Map<String, dynamic>>()) o['id'] as int: o
      };
      expect(byId[1]!['outcome'], equals('rewritten'));
      expect(byId[1]!['before'], equals('+moc'));
      expect(byId[1]!['after'], equals('+møk'));
      expect(byId[2]!['outcome'], equals('left_alone_phonemic'));
      expect(byId[3]!['outcome'], equals('left_alone_unparseable'));
    });
  });
}
