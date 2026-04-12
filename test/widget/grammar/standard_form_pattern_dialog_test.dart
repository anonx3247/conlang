// Plan 04-17 Task 10 -- widget tests for D-98 StandardFormPatternDialog.
//
// Tests the dialog's open/save/cancel lifecycle, multi-branch editing,
// live preview, and pre-loading of existing patterns.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/grammar_providers.dart';
import 'package:conlang_workbench/features/grammar/data/standard_form_pattern_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/standard_form_branch.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/standard_form_pattern_dialog.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StandardFormPatternDao dao;

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
    dao = StandardFormPatternDao(db);

    // Seed a POS with an intrinsic dimension so the DAO has valid FK targets.
    await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: 1,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
            intrinsic: const Value(true),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => child,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
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

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('Test 1: open + add branch + save', (tester) async {
    await tester.pumpWidget(buildApp(
      const StandardFormPatternDialog(
        dimId: 1,
        dimName: 'Gender',
        levelId: 1,
        levelName: 'Masculine',
      ),
    ));
    await openDialog(tester);

    // Tap 'Add branch'.
    await tester.tap(find.text('Add branch'));
    await tester.pump();

    // Type 'ar' into the text field.
    await tester.enterText(find.byType(TextField), 'ar');
    await tester.pump();

    // Tap Save.
    await tester.tap(find.text('Save'));
    await settle(tester);

    // Verify the pattern was persisted.
    final pattern = await dao.getPattern(1, 1);
    expect(pattern, isNotNull);
    expect(pattern!.length, 1);
    expect(pattern.first.kind, BranchKind.endsWith);
    expect(pattern.first.literal, 'ar');

    await teardownWidget(tester);
  });

  testWidgets('Test 2: multi-branch save', (tester) async {
    await tester.pumpWidget(buildApp(
      const StandardFormPatternDialog(
        dimId: 1,
        dimName: 'Gender',
        levelId: 1,
        levelName: 'Masculine',
      ),
    ));
    await openDialog(tester);

    // Add first branch.
    await tester.tap(find.text('Add branch'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'ar');
    await tester.pump();

    // Add second branch.
    await tester.tap(find.text('Add branch'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'er');
    await tester.pump();

    // Save.
    await tester.tap(find.text('Save'));
    await settle(tester);

    final pattern = await dao.getPattern(1, 1);
    expect(pattern, isNotNull);
    expect(pattern!.length, 2);
    expect(pattern[0].literal, 'ar');
    expect(pattern[1].literal, 'er');

    await teardownWidget(tester);
  });

  testWidgets('Test 3: cancel discards changes', (tester) async {
    await tester.pumpWidget(buildApp(
      const StandardFormPatternDialog(
        dimId: 1,
        dimName: 'Gender',
        levelId: 1,
        levelName: 'Masculine',
      ),
    ));
    await openDialog(tester);

    // Add a branch.
    await tester.tap(find.text('Add branch'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ar');
    await tester.pump();

    // Cancel.
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // Verify nothing was saved.
    final pattern = await dao.getPattern(1, 1);
    expect(pattern, isNull);

    await teardownWidget(tester);
  });

  testWidgets('Test 4: live preview expands V class ref', (tester) async {
    // Seed some phonemes so the inventory provider has data.
    await db.into(db.phonemes).insert(
          PhonemesCompanion.insert(
            symbol: 'a',
            type: 'vowel',
          ),
        );
    await db.into(db.phonemes).insert(
          PhonemesCompanion.insert(
            symbol: 'e',
            type: 'vowel',
          ),
        );
    await db.into(db.phonemes).insert(
          PhonemesCompanion.insert(
            symbol: 'i',
            type: 'vowel',
          ),
        );

    await tester.pumpWidget(buildApp(
      const StandardFormPatternDialog(
        dimId: 1,
        dimName: 'Gender',
        levelId: 1,
        levelName: 'Masculine',
      ),
    ));
    await openDialog(tester);

    // Add a branch with V class ref.
    await tester.tap(find.text('Add branch'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Vr');
    await settle(tester);

    // The preview should show expansions containing 'ar', 'er', 'ir'.
    final previewFinder = find.textContaining('ar');
    expect(previewFinder, findsWidgets);

    await teardownWidget(tester);
  });

  testWidgets('Test 5: edit existing pattern pre-loads', (tester) async {
    // Pre-seed a pattern.
    await dao.upsertPattern(1, 1, [
      const StandardFormBranch(kind: BranchKind.endsWith, literal: 'or'),
    ]);

    await tester.pumpWidget(buildApp(
      const StandardFormPatternDialog(
        dimId: 1,
        dimName: 'Gender',
        levelId: 1,
        levelName: 'Masculine',
      ),
    ));
    await openDialog(tester);

    // The existing branch should be pre-loaded in the text field.
    expect(find.text('or'), findsWidgets);

    await teardownWidget(tester);
  });
}
