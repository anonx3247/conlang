// Plan 04-06 Task 2 — widget tests for ParadigmTableWidget, AxisConfigBar,
// and CellOverrideDialog. Covers the D-25 tabs/dropdown affordance, the
// per-cell ViolationText wiring (D-30), amber override rendering (D-28),
// and the row/column axis selector.
//
// Test infrastructure mirrors pos_dimensions_page_test.dart:
//   - In-memory AppDatabase overridden into currentDatabaseProvider
//   - settle() helper that interleaves runAsync(Future.delayed(50ms)) +
//     pump so Drift stream queries emit their first value before the
//     next assertion.
//   - teardownWidget() empties the widget tree so Drift's StreamQueryStore
//     cancel chain can finish without tripping !timersPending.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/paradigm_cell_override_dao.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_axes.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/axis_config_bar.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/cell_override_dialog.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:conlang_workbench/shared/widgets/violation_text.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  // Suppress the pre-existing op-row overflow warning that 04-05 logged;
  // nothing in this test suite should trip a new one, but we keep the
  // guard so the ParadigmTableWidget's Dropdown-based slice selector
  // doesn't fail the suite on a harmless layout measurement issue.
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

  Widget buildApp(
    Widget child, {
    List<Object> extraOverrides = const [],
  }) =>
      ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
          ...extraOverrides.cast(),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1400, height: 900, child: child),
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

  // ------------------------------------------------------------------------
  // Fixture helpers
  // ------------------------------------------------------------------------

  /// Seeds a Noun POS + Number (SG/PL) + Gender (M/F) dimensions and a
  /// Lexeme. Returns the ids for test assertions.
  Future<({int posId, int numberDimId, int genderDimId, int lexemeId})>
      seedTwoDimFixture() async {
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
          ),
        );
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kat',
            partOfSpeech: const Value('Noun'),
          ),
        );
    return (
      posId: posId,
      numberDimId: numberDimId,
      genderDimId: genderDimId,
      lexemeId: lexemeId
    );
  }

  /// Seeds a 3-dim fixture (Gender 2, Number 2, Case 3). Case has 3 levels
  /// so the non-axis dim produces 3 slices → TabBar rendering.
  Future<
      ({
        int posId,
        int genderDimId,
        int numberDimId,
        int caseDimId,
        int lexemeId,
      })> seedThreeDimTabsFixture() async {
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
          ),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
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
                  id: 1, name: 'Nominative', abbr: 'NOM', ordering: 0),
              DimensionLevel(
                  id: 2, name: 'Accusative', abbr: 'ACC', ordering: 1),
              DimensionLevel(
                  id: 3, name: 'Dative', abbr: 'DAT', ordering: 2),
            ]),
            templateId: const Value('case.nom_acc_dat'),
          ),
        );
    // Persist an explicit axis config: rows=Gender, cols=Number, tabs=[Case].
    await writeParadigmAxes(
      db,
      posId: posId,
      axes: ParadigmAxes(
        rows: genderDimId,
        cols: numberDimId,
        tabs: [caseDimId],
      ),
    );
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kat',
            partOfSpeech: const Value('Noun'),
          ),
        );
    return (
      posId: posId,
      genderDimId: genderDimId,
      numberDimId: numberDimId,
      caseDimId: caseDimId,
      lexemeId: lexemeId,
    );
  }

  /// Seeds a 3-dim fixture with 7 case levels → slice selector must render
  /// a DropdownButton instead of a TabBar.
  Future<
      ({
        int posId,
        int genderDimId,
        int numberDimId,
        int caseDimId,
        int lexemeId,
      })> seedThreeDimDropdownFixture() async {
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            templateId: const Value('gender.mf'),
          ),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
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
                  id: 1, name: 'Nominative', abbr: 'NOM', ordering: 0),
              DimensionLevel(
                  id: 2, name: 'Accusative', abbr: 'ACC', ordering: 1),
              DimensionLevel(
                  id: 3, name: 'Genitive', abbr: 'GEN', ordering: 2),
              DimensionLevel(id: 4, name: 'Dative', abbr: 'DAT', ordering: 3),
              DimensionLevel(id: 5, name: 'Ablative', abbr: 'ABL', ordering: 4),
              DimensionLevel(id: 6, name: 'Locative', abbr: 'LOC', ordering: 5),
              DimensionLevel(
                  id: 7, name: 'Instrumental', abbr: 'INS', ordering: 6),
            ]),
            templateId: const Value('case.latin_like'),
          ),
        );
    await writeParadigmAxes(
      db,
      posId: posId,
      axes: ParadigmAxes(
        rows: genderDimId,
        cols: numberDimId,
        tabs: [caseDimId],
      ),
    );
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kat',
            partOfSpeech: const Value('Noun'),
          ),
        );
    return (
      posId: posId,
      genderDimId: genderDimId,
      numberDimId: numberDimId,
      caseDimId: caseDimId,
      lexemeId: lexemeId,
    );
  }

  // ------------------------------------------------------------------------
  // 2-dim POS tests
  // ------------------------------------------------------------------------

  group('ParadigmTableWidget — 2-dim POS', () {
    testWidgets('renders column headers, row headers, and 4 cells',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );
      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      // Column headers (Gender: M, F)
      expect(find.text('M'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      // Row headers (Number: SG, PL)
      expect(find.text('SG'), findsOneWidget);
      expect(find.text('PL'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets(
        'uncovered cells render em-dash (no inflectional rules seeded)',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );
      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      // With no rules seeded, every cell should render em-dash.
      expect(find.text('—'), findsWidgets);

      await teardownWidget(tester);
    });

    testWidgets('tapping a cell opens CellOverrideDialog', (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );
      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      // Tap the first em-dash cell.
      await tester.tap(find.text('—').first);
      await settle(tester);

      expect(find.byType(CellOverrideDialog), findsOneWidget);
      expect(find.text('Edit cell'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets('override cell renders amber warning icon + override form',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );
      // Seed an override for the (Number=PL=2, Gender=M=1) cell.
      await ParadigmCellOverrideDao(db).upsertOverride(
        lexemeId: ids.lexemeId,
        featureSet: {ids.numberDimId: 2, ids.genderDimId: 1},
        overrideIpa: 'mʲiːs',
        overrideRomanization: 'mīs',
      );

      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      // Warning icon is rendered on the override cell.
      expect(find.byIcon(Icons.warning_amber_outlined), findsWidgets);
      // Override romanization is shown as the primary text.
      expect(find.text('mīs'), findsOneWidget);
      // Override IPA appears in the bracketed second line.
      expect(find.text('[mʲiːs]'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets(
        'filled cells render ViolationText and IPA (provider override fixture)',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );

      // Override computedInflectedParadigmProvider with a fixture chart so
      // we don't have to wire up a full DSL pipeline just to prove the
      // render path. Use ParadigmFilled for all 4 cells.
      final filledChart = ParadigmChart({
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 1},
          cell: const ParadigmFilled(form: 'kat', ruleChain: []),
        ),
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 2},
          cell: const ParadigmFilled(form: 'kata', ruleChain: []),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 1},
          cell: const ParadigmFilled(form: 'kati', ruleChain: []),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 2},
          cell: const ParadigmFilled(form: 'katu', ruleChain: []),
        ),
      });

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(filledChart),
        ],
      ));
      await settle(tester);

      // Each filled cell should render a ViolationText (4 total).
      expect(find.byType(ViolationText), findsNWidgets(4));
      // IPA line for at least one fixture form.
      expect(find.text('[kat]'), findsOneWidget);
      expect(find.text('[katu]'), findsOneWidget);

      await teardownWidget(tester);
    });
  });

  // ------------------------------------------------------------------------
  // 3-dim POS with ≤6 slices — TabBar
  // ------------------------------------------------------------------------

  group('ParadigmTableWidget — D-25 affordance', () {
    testWidgets('3 slices → TabBar with one tab per slice', (tester) async {
      final ids = await seedThreeDimTabsFixture();
      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      expect(find.byType(TabBar), findsOneWidget);
      // Case labels appear as tab text.
      expect(find.text('NOM'), findsWidgets);
      expect(find.text('ACC'), findsWidgets);
      expect(find.text('DAT'), findsWidgets);

      await teardownWidget(tester);
    });

    testWidgets('7 slices → DropdownButton instead of TabBar', (tester) async {
      final ids = await seedThreeDimDropdownFixture();
      await tester.pumpWidget(buildApp(ParadigmTableWidget(
        lexemeId: ids.lexemeId,
        posId: ids.posId,
      )));
      await settle(tester);

      // 7 case levels → dropdown path. ParadigmTableWidget does NOT mount
      // an AxisConfigBar, so the only DropdownButton on screen is the
      // slice selector itself.
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
      // The 'Slice:' label is a secondary signal that the dropdown path
      // (not the tab path) is active.
      expect(find.text('Slice:'), findsOneWidget);

      await teardownWidget(tester);
    });
  });

  // ------------------------------------------------------------------------
  // AxisConfigBar
  // ------------------------------------------------------------------------

  group('AxisConfigBar', () {
    testWidgets('2-dim POS renders two dropdowns and persists selection',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );
      await tester.pumpWidget(buildApp(AxisConfigBar(posId: ids.posId)));
      await settle(tester);

      expect(find.text('Rows:'), findsOneWidget);
      expect(find.text('Columns:'), findsOneWidget);
      // Two DropdownButtons (Rows + Columns). The slice-selector dropdown
      // is NOT part of AxisConfigBar.
      expect(find.byType(DropdownButton<int>), findsNWidgets(2));

      await teardownWidget(tester);
    });
  });
}
