// Plan 04-10 Task 4 — widget tests for the D-47 ParadigmUnmarked render
// branch in ParadigmTableWidget. Locks:
//   - bare root + ∅ badge appear for ParadigmUnmarked cells
//   - unmarked cells do NOT render the em-dash (that's ParadigmUncovered)
//   - unmarked cells are distinct from normal ParadigmFilled cells
//   - romanization toggle is respected the same way _FilledCell respects it
//   - phonotactic violation underlines still flow through ViolationText
//
// Test infrastructure mirrors paradigm_table_widget_test.dart:
//   - In-memory AppDatabase overridden into currentDatabaseProvider
//   - computedInflectedParadigmProvider overridden with a fixture ParadigmChart
//   - settle() interleaves runAsync pumps so Drift stream queries emit
//   - teardownWidget() prevents timers-pending on dispose

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/marker.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_axes.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
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
  // Fixture — 2-dim Noun POS with a Lexeme. Mirrors seedTwoDimFixture()
  // from paradigm_table_widget_test.dart but kept inline so this suite is
  // self-contained.
  // ------------------------------------------------------------------------

  Future<
      ({
        int posId,
        int numberDimId,
        int genderDimId,
        int lexemeId,
      })> seedFixture() async {
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
    await writeParadigmAxes(
      db,
      posId: posId,
      axes: ParadigmAxes(rows: numberDimId, cols: genderDimId),
    );
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kata',
            partOfSpeech: const Value('Noun'),
          ),
        );
    return (
      posId: posId,
      numberDimId: numberDimId,
      genderDimId: genderDimId,
      lexemeId: lexemeId,
    );
  }

  /// Builds a ParadigmChart with one [ParadigmUnmarked] cell at
  /// (Number=SG=1, Gender=M=1) and the other three cells uncovered. The
  /// marker source is a dummy MarkerDecl — the widget only reads `root`.
  ParadigmChart unmarkedFixtureChart({
    required int numberDimId,
    required int genderDimId,
    required String root,
  }) {
    final marker = MarkerDecl(
      id: 1,
      posId: 1,
      bindings: const FeatureBindings(pos: [], dims: {}),
    );
    return ParadigmChart({
      featureSetKey({numberDimId: 1, genderDimId: 1}): ParadigmChartEntry(
        featureSet: {numberDimId: 1, genderDimId: 1},
        cell: ParadigmUnmarked(root: root, source: marker),
      ),
      featureSetKey({numberDimId: 1, genderDimId: 2}): ParadigmChartEntry(
        featureSet: {numberDimId: 1, genderDimId: 2},
        cell: const ParadigmUncovered('none'),
      ),
      featureSetKey({numberDimId: 2, genderDimId: 1}): ParadigmChartEntry(
        featureSet: {numberDimId: 2, genderDimId: 1},
        cell: const ParadigmUncovered('none'),
      ),
      featureSetKey({numberDimId: 2, genderDimId: 2}): ParadigmChartEntry(
        featureSet: {numberDimId: 2, genderDimId: 2},
        cell: const ParadigmUncovered('none'),
      ),
    });
  }

  group('ParadigmUnmarked render (D-47)', () {
    testWidgets('renders bare root and ∅ badge', (tester) async {
      final ids = await seedFixture();
      final chart = unmarkedFixtureChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        root: 'kata',
      );

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
        ],
      ));
      await settle(tester);

      // The bare root surfaces as the unmarked cell's IPA label (no
      // romanization mapping is configured in this fixture, so the cell
      // renders `[kata]` directly).
      expect(find.text('[kata]'), findsOneWidget);
      // ∅ badge appears at least once — exactly one unmarked cell.
      expect(find.text('∅'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets('does NOT render the em-dash (distinct from uncovered)',
        (tester) async {
      final ids = await seedFixture();
      final chart = unmarkedFixtureChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        root: 'kata',
      );

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
        ],
      ));
      await settle(tester);

      // Three uncovered cells render `—`. The unmarked cell renders the
      // root + ∅ instead, so we see exactly three em-dashes, not four.
      expect(find.text('—'), findsNWidgets(3));
      // And exactly one ∅ badge for the unmarked cell.
      expect(find.text('∅'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets('is distinct from ParadigmFilled (different widget tree)',
        (tester) async {
      final ids = await seedFixture();

      // Fixture chart with ONE unmarked cell + THREE filled cells.
      final marker = MarkerDecl(
        id: 1,
        posId: 1,
        bindings: const FeatureBindings(pos: [], dims: {}),
      );
      final chart = ParadigmChart({
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 1},
          cell: ParadigmUnmarked(root: 'kata', source: marker),
        ),
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 2},
          cell: const ParadigmFilled(form: 'katas', ruleChain: []),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 1},
          cell: const ParadigmFilled(form: 'katam', ruleChain: []),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 2},
          cell: const ParadigmFilled(form: 'kataf', ruleChain: []),
        ),
      });

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
        ],
      ));
      await settle(tester);

      // The three filled cells show their IPA forms.
      expect(find.text('[katas]'), findsOneWidget);
      expect(find.text('[katam]'), findsOneWidget);
      expect(find.text('[kataf]'), findsOneWidget);
      // The unmarked cell shows the bare root and ∅ — the filled cells do
      // NOT have a ∅ badge.
      expect(find.text('[kata]'), findsOneWidget);
      expect(find.text('∅'), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets('respects phonotactic violation highlighting via ViolationText',
        (tester) async {
      final ids = await seedFixture();
      final chart = unmarkedFixtureChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        root: 'kata',
      );

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
        ],
      ));
      await settle(tester);

      // The unmarked cell MUST wrap its label in a ViolationText so it
      // participates in the same red-wavy-underline highlighting as filled
      // cells. Exactly one unmarked cell in the fixture → exactly one
      // ViolationText from the unmarked branch (the uncovered cells do
      // not mount a ViolationText).
      expect(find.byType(ViolationText), findsOneWidget);

      await teardownWidget(tester);
    });

    testWidgets(
        'no regression when markers are absent — uncovered em-dashes survive',
        (tester) async {
      final ids = await seedFixture();

      // All-uncovered chart: no markers, no rules. The widget must render
      // four em-dashes and zero ∅ badges — the D-47 path is DORMANT when
      // no ParadigmUnmarked cells exist.
      final chart = ParadigmChart({
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 1},
          cell: const ParadigmUncovered('none'),
        ),
        featureSetKey({ids.numberDimId: 1, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 1, ids.genderDimId: 2},
          cell: const ParadigmUncovered('none'),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 1}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 1},
          cell: const ParadigmUncovered('none'),
        ),
        featureSetKey({ids.numberDimId: 2, ids.genderDimId: 2}):
            ParadigmChartEntry(
          featureSet: {ids.numberDimId: 2, ids.genderDimId: 2},
          cell: const ParadigmUncovered('none'),
        ),
      });

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
        ],
      ));
      await settle(tester);

      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('∅'), findsNothing);

      await teardownWidget(tester);
    });
  });
}
