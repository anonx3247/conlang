// Plan 04-17 Task 8 — widget tests for D-94 stacked intrinsic-slice
// rendering and D-95 first-matching-lexeme default behavior.
//
// Test infrastructure mirrors paradigm_table_widget_test.dart:
//   - In-memory AppDatabase overridden into currentDatabaseProvider
//   - settle() helper for Drift stream queries
//   - teardownWidget() cleanup

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/intrinsic_levels_codec.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

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
            body: SizedBox(width: 1400, height: 900, child: child),
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

  // --------------------------------------------------------------------------
  // Fixture helpers
  // --------------------------------------------------------------------------

  /// Seeds a POS with Gender intrinsic {M=0, F=1} + Number {SG=0, PL=1}
  /// (non-intrinsic) + Case {NOM=0, ACC=1} (non-intrinsic).
  /// Lexemes: m1={gender:M}, m2={gender:M}, f1={gender:F}.
  Future<
      ({
        int posId,
        int genderDimId,
        int numberDimId,
        int caseDimId,
        int m1Id,
        int m2Id,
        int f1Id,
      })> seedIntrinsicFixture() async {
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 0, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 1, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
            intrinsic: const Value(true),
          ),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: 0, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 1, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
    final caseDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Case',
            ordering: const Value(2),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: 0, name: 'Nominative', abbr: 'NOM', ordering: 0),
              DimensionLevel(
                  id: 1, name: 'Accusative', abbr: 'ACC', ordering: 1),
            ]),
            templateId: const Value('case.nom_acc'),
          ),
        );

    // Lexemes with intrinsic gender assignments.
    final m1Id = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'm1',
            partOfSpeech: const Value('Noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({genderDimId: 0})),
          ),
        );
    final m2Id = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'm2',
            partOfSpeech: const Value('Noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({genderDimId: 0})),
          ),
        );
    final f1Id = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'f1',
            partOfSpeech: const Value('Noun'),
            intrinsicLevelsJson:
                Value(IntrinsicLevelsCodec.encode({genderDimId: 1})),
          ),
        );

    return (
      posId: posId,
      genderDimId: genderDimId,
      numberDimId: numberDimId,
      caseDimId: caseDimId,
      m1Id: m1Id,
      m2Id: m2Id,
      f1Id: f1Id,
    );
  }

  // --------------------------------------------------------------------------
  // Tests
  // --------------------------------------------------------------------------

  testWidgets('D-94: two intrinsic sections render for M/F gender',
      (tester) async {
    final fix = await seedIntrinsicFixture();

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        posId: fix.posId,
        lexemeId: -1,
      ),
    ));
    await settle(tester);

    // Expect two section labels: one for Masculine, one for Feminine.
    expect(find.text('Gender: Masculine'), findsOneWidget);
    expect(find.text('Gender: Feminine'), findsOneWidget);

    await teardownWidget(tester);
  });

  testWidgets('D-95: each section defaults to first matching lexeme',
      (tester) async {
    final fix = await seedIntrinsicFixture();

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        posId: fix.posId,
        lexemeId: -1,
      ),
    ));
    await settle(tester);

    // M section dropdown should default to m1 (lowest id).
    // F section dropdown should default to f1 (only F lexeme).
    // Both should appear as DropdownButton items.
    expect(find.text('m1'), findsWidgets);
    expect(find.text('f1'), findsWidgets);

    await teardownWidget(tester);
  });

  testWidgets('D-94: changing one section dropdown does not affect the other',
      (tester) async {
    final fix = await seedIntrinsicFixture();

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        posId: fix.posId,
        lexemeId: -1,
      ),
    ));
    await settle(tester);

    // Find the M section dropdown and tap it to open.
    // The M section should show m1 as default, we'll switch to m2.
    // First, find all DropdownButton<int> widgets.
    final dropdowns = find.byType(DropdownButton<int>);
    expect(dropdowns, findsAtLeast(1));

    // Tap the first dropdown to open it.
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();

    // Select m2.
    final m2Item = find.text('m2').last;
    await tester.tap(m2Item);
    await settle(tester);

    // F section should still show f1 (unchanged).
    expect(find.text('f1'), findsWidgets);

    await teardownWidget(tester);
  });

  testWidgets('D-94: empty pool renders hint text', (tester) async {
    // Create fixture but delete all F lexemes.
    final fix = await seedIntrinsicFixture();
    await (db.delete(db.lexemes)..where((t) => t.id.equals(fix.f1Id))).go();

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        posId: fix.posId,
        lexemeId: -1,
      ),
    ));
    await settle(tester);

    // F section should render empty-pool hint.
    expect(
      find.textContaining('No word with'),
      findsOneWidget,
    );

    await teardownWidget(tester);
  });

  testWidgets('D-95: non-intrinsic POS uses first-matching-lexeme default',
      (tester) async {
    // Seed a Verb POS with no intrinsic dims.
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Tense',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 0, name: 'Present', abbr: 'PRS', ordering: 0),
              DimensionLevel(id: 1, name: 'Past', abbr: 'PST', ordering: 1),
            ]),
            templateId: const Value('tense.prs_pst'),
          ),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Person',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 0, name: 'First', abbr: '1', ordering: 0),
              DimensionLevel(id: 1, name: 'Second', abbr: '2', ordering: 1),
            ]),
            templateId: const Value('person.12'),
          ),
        );
    await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'run',
            partOfSpeech: const Value('Verb'),
          ),
        );

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        posId: posId,
        lexemeId: -1, // No explicit selection.
      ),
    ));
    await settle(tester);

    // Should render the single paradigm table (no stacked sections).
    // Should NOT show the intrinsic section labels.
    expect(find.text('Gender: Masculine'), findsNothing);
    expect(find.text('Gender: Feminine'), findsNothing);

    // Should render axis headers (Tense/Person).
    expect(find.text('PRS'), findsOneWidget);
    expect(find.text('PST'), findsOneWidget);

    await teardownWidget(tester);
  });
}
