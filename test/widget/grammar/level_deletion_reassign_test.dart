// Plan 04-17 Task 3 — D-86 unified level-deletion dependency check +
// reassign dialog widget tests for DimensionEditorPanel.
//
// Locks:
//   D-86 Test 1: dim with 2 levels, no references → onDeleted deletes
//                directly without a dialog.
//   D-86 Test 2: 2 lexemes reference level 1 via intrinsicLevelsJson →
//                opens reassign dialog; pick level 2; assert lexemes now
//                reference level 2 and level 1 is gone from levelsJson.
//   D-86 Test 3: rule featureBindings references (dim, level1) → dialog
//                shows the rule; confirm reassigns rule bindings.
//   D-86 Test 4: standard_form_patterns row for (dim, level1) → dialog
//                shows the pattern; confirm reassigns the row's levelId.
//   D-86 Test 5 [WARN-7 parity regression]: seed a rule whose
//                featureBindings blocks deletion — NO lexemes, NO
//                patterns. Assert checkLevelDeletionDependencies returns
//                ruleCount == 1 and isBlocking == true. Also verify the
//                non-deleted levels remain unchanged in levelsJson after
//                the reassign (WARN-7 lock).
//
// The featureBindings blocks deletion string appears in a file comment
// below (required by the WARN-7 parity grep lock in the plan).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_dao.dart';
import 'package:conlang_workbench/features/grammar/data/intrinsic_levels_codec.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WARN-7 parity regression: featureBindings blocks deletion — the unified
// checkLevelDeletionDependencies helper MUST still surface rule
// featureBindings references exactly as the pre-unification standalone
// check did. The grep lock `featureBindings.*blocks.*deletion` in the
// plan's acceptance criteria pins this comment.

void main() {
  late AppDatabase db;
  late GrammarDao dao;
  late int posId;
  late int dimId;

  void Function(FlutterErrorDetails)? previousOnError;
  setUpAll(() {
    previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('A RenderFlex overflowed by')) return;
      previousOnError?.call(details);
    };
  });
  tearDownAll(() {
    FlutterError.onError = previousOnError;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.grammarDao;
    posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    dimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: DimensionEditorPanel(posId: posId),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> teardownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<List<DimensionLevel>> fetchLevels() async {
    final row = await (db.select(db.dimensions)
          ..where((t) => t.id.equals(dimId)))
        .getSingle();
    return decodeLevelsJson(row.levelsJson);
  }

  /// Grabs the Masculine chip's onDeleted callback and calls it. We go
  /// through the widget (not hit-testing the delete region) for the same
  /// reason dimension_level_edit_test.dart does: InputChip's internal
  /// delete slot is awkward to target in hit-test space.
  Future<void> tapMasculineDelete(WidgetTester tester) async {
    final chip = tester.widget<InputChip>(
      find.ancestor(
        of: find.text('Masculine (M)'),
        matching: find.byType(InputChip),
      ),
    );
    chip.onDeleted!();
  }

  testWidgets(
      'D-86 Test 1 — no references → onDeleted deletes directly, no dialog',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tapMasculineDelete(tester);
    await tester.pumpAndSettle();
    await settle(tester);

    // No AlertDialog present.
    expect(find.byType(AlertDialog), findsNothing);

    // DB: Feminine is the only remaining level.
    final levels = await fetchLevels();
    expect(levels.length, equals(1));
    expect(levels.first.name, equals('Feminine'));

    await teardownWidget(tester);
  });

  testWidgets(
      'D-86 Test 2 — 2 lexemes reference level 1 → dialog, reassign, delete',
      (tester) async {
    // Seed 2 lexemes referencing level 1 (Masculine) in their intrinsic map.
    await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kasa',
            partOfSpeech: const Value('noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({dimId: 1})),
          ),
        );
    await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'pinu',
            partOfSpeech: const Value('noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({dimId: 1})),
          ),
        );

    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tapMasculineDelete(tester);
    await tester.pumpAndSettle();
    await settle(tester);

    // Dialog opens with the right summary copy.
    expect(find.text("Reassign and delete 'Masculine'"), findsOneWidget);
    expect(find.text('• 2 words'), findsOneWidget);

    // Open the dropdown and pick Feminine.
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feminine (F)').last);
    await tester.pumpAndSettle();

    // Confirm.
    await tester.tap(find.text('Reassign and delete'));
    await tester.pumpAndSettle();
    await settle(tester);

    // DB: lexemes now reference level 2, level 1 is gone from levelsJson.
    final allLexemes = await db.select(db.lexemes).get();
    for (final lex in allLexemes) {
      final decoded =
          IntrinsicLevelsCodec.decode(lex.intrinsicLevelsJson);
      expect(decoded[dimId], equals(2));
    }
    final levels = await fetchLevels();
    expect(levels.length, equals(1));
    expect(levels.first.id, equals(2));

    await teardownWidget(tester);
  });

  testWidgets(
      'D-86 Test 3 — rule featureBindings references level 1 → dialog, reassign',
      (tester) async {
    final ruleId = await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'M-suffix',
        source: 'suffix: o',
        featureBindings: Value(
          FeatureBindings(pos: [posId], dims: {dimId: 1}),
        ),
      ),
      RuleKind.inflectional,
    );

    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tapMasculineDelete(tester);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text("Reassign and delete 'Masculine'"), findsOneWidget);
    expect(find.text('• 1 inflection rule'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feminine (F)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reassign and delete'));
    await tester.pumpAndSettle();
    await settle(tester);

    // Rule's featureBindings dims should now map dimId → 2.
    final rule = await (db.select(db.morphologicalRules)
          ..where((t) => t.id.equals(ruleId)))
        .getSingle();
    expect(rule.featureBindings.dims[dimId], equals(2));

    final levels = await fetchLevels();
    expect(levels.any((l) => l.id == 1), isFalse);

    await teardownWidget(tester);
  });

  testWidgets(
      'D-86 Test 4 — standard_form_patterns row for level 1 → dialog, reassign',
      (tester) async {
    await db.into(db.standardFormPatterns).insert(
          StandardFormPatternsCompanion.insert(
            dimensionId: dimId,
            levelId: 1,
            branchesJson: '[]',
          ),
        );

    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tapMasculineDelete(tester);
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text("Reassign and delete 'Masculine'"), findsOneWidget);
    expect(find.text('• 1 standard-form patterns'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feminine (F)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reassign and delete'));
    await tester.pumpAndSettle();
    await settle(tester);

    final rows = await db.select(db.standardFormPatterns).get();
    expect(rows.length, equals(1));
    expect(rows.first.dimensionId, equals(dimId));
    expect(rows.first.levelId, equals(2),
        reason: 'pattern row should now reference the new level id');

    await teardownWidget(tester);
  });

  testWidgets(
      'D-86 Test 5 [WARN-7 parity] — rule featureBindings alone blocks deletion + non-deleted levels preserved',
      (tester) async {
    // Pre-condition setup mirrors Test 3 but with a richer 3-level dim so
    // we can assert the non-deleted levels survive unchanged.
    await (db.update(db.dimensions)..where((t) => t.id.equals(dimId))).write(
      DimensionsCompanion(
        levelsJson: Value(encodeLevelsJson(const [
          DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
          DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
          DimensionLevel(id: 3, name: 'Neuter', abbr: 'N', ordering: 2),
        ])),
      ),
    );
    await db.morphologyDao.insertRuleWithKind(
      MorphologicalRulesCompanion.insert(
        name: 'M-suffix',
        source: 'suffix: o',
        featureBindings: Value(
          FeatureBindings(pos: [posId], dims: {dimId: 1}),
        ),
      ),
      RuleKind.inflectional,
    );

    // Direct DAO assertions — the unified helper must still report the
    // rule reference with NO lexemes and NO patterns present.
    final report = await dao.checkLevelDeletionDependencies(dimId, 1);
    expect(report.ruleCount, equals(1));
    expect(report.lexemeCount, equals(0));
    expect(report.patternCount, equals(0));
    expect(report.isBlocking, isTrue);

    await tester.pumpWidget(buildApp());
    await settle(tester);

    await tapMasculineDelete(tester);
    await tester.pumpAndSettle();
    await settle(tester);

    // Dialog visible with copy referencing "1 inflection rule".
    expect(find.text("Reassign and delete 'Masculine'"), findsOneWidget);
    expect(find.text('• 1 inflection rule'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feminine (F)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reassign and delete'));
    await tester.pumpAndSettle();
    await settle(tester);

    // WARN-7 parity: Feminine and Neuter survive unchanged.
    final levels = await fetchLevels();
    expect(levels.length, equals(2));
    final f = levels.firstWhere((l) => l.id == 2);
    expect(f.name, equals('Feminine'));
    expect(f.abbr, equals('F'));
    expect(f.ordering, equals(1));
    final n = levels.firstWhere((l) => l.id == 3);
    expect(n.name, equals('Neuter'));
    expect(n.abbr, equals('N'));
    expect(n.ordering, equals(2));
    expect(levels.any((l) => l.id == 1), isFalse);

    await teardownWidget(tester);
  });
}
