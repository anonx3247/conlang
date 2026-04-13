// Regression tests for G-04 — paradigm cells render romanization as the
// primary (top) line and IPA as the dimmed secondary line, but ONLY when
// the romanization differs from the IPA form. When rom == IPA (or rom is
// empty), the cell collapses to a single IPA-only dimmed line so the
// user isn't shown the same glyphs twice.
//
// Infrastructure mirrors test/widget/grammar/paradigm_table_widget_test.dart
// so we can reuse the in-memory AppDatabase + ParadigmTableWidget render
// path and just vary the romanizeProvider override per case.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_axes.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/phonology/data/romanization_providers.dart';
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

  /// Builds a 4-cell filled chart with the given forms.
  ParadigmChart _fourCellChart({
    required int numberDimId,
    required int genderDimId,
    required List<String> forms,
  }) {
    assert(forms.length == 4);
    return ParadigmChart({
      featureSetKey({numberDimId: 1, genderDimId: 1}): ParadigmChartEntry(
        featureSet: {numberDimId: 1, genderDimId: 1},
        cell: ParadigmFilled(form: forms[0], ruleChain: const []),
      ),
      featureSetKey({numberDimId: 1, genderDimId: 2}): ParadigmChartEntry(
        featureSet: {numberDimId: 1, genderDimId: 2},
        cell: ParadigmFilled(form: forms[1], ruleChain: const []),
      ),
      featureSetKey({numberDimId: 2, genderDimId: 1}): ParadigmChartEntry(
        featureSet: {numberDimId: 2, genderDimId: 1},
        cell: ParadigmFilled(form: forms[2], ruleChain: const []),
      ),
      featureSetKey({numberDimId: 2, genderDimId: 2}): ParadigmChartEntry(
        featureSet: {numberDimId: 2, genderDimId: 2},
        cell: ParadigmFilled(form: forms[3], ruleChain: const []),
      ),
    });
  }

  group('G-04 — paradigm cell rom-primary rendering', () {
    testWidgets(
        'rom hidden when equal to IPA (single dimmed IPA line, no duplication)',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );

      final chart = _fourCellChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        forms: const ['kat', 'kata', 'kati', 'katu'],
      );

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
          // Identity romanization — simulates "no romanization configured".
          romanizeProvider.overrideWithValue((String ipa) => ipa),
        ],
      ));
      await settle(tester);

      // IPA bracket line present for each cell.
      expect(find.text('[kat]'), findsOneWidget);
      expect(find.text('[kata]'), findsOneWidget);
      expect(find.text('[kati]'), findsOneWidget);
      expect(find.text('[katu]'), findsOneWidget);

      // The bare IPA form (without brackets) must NOT appear as a top line
      // when the rom is identical — that would be user-visible duplication.
      expect(find.text('kat'), findsNothing);
      expect(find.text('kata'), findsNothing);
      expect(find.text('kati'), findsNothing);
      expect(find.text('katu'), findsNothing);

      // Exactly 4 ViolationText widgets (one per cell, single-line mode).
      expect(find.byType(ViolationText), findsNWidgets(4));

      await teardownWidget(tester);
    });

    testWidgets(
        'rom is the primary top line when it differs from IPA, IPA dimmed on bottom',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );

      // Use IPA forms that will be mapped to distinct Latin strings.
      final chart = _fourCellChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        forms: const ['kaʈ', 'kaʈa', 'kaʈi', 'kaʈu'],
      );

      // Fake romanize: ʈ -> t.
      String fakeRom(String ipa) => ipa.replaceAll('ʈ', 't');

      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
          romanizeProvider.overrideWithValue(fakeRom),
        ],
      ));
      await settle(tester);

      // Romanized forms as primary top lines (bare, no brackets).
      expect(find.text('kat'), findsOneWidget);
      expect(find.text('kata'), findsOneWidget);
      expect(find.text('kati'), findsOneWidget);
      expect(find.text('katu'), findsOneWidget);

      // IPA forms as dimmed bracketed bottom lines.
      expect(find.text('[kaʈ]'), findsOneWidget);
      expect(find.text('[kaʈa]'), findsOneWidget);
      expect(find.text('[kaʈi]'), findsOneWidget);
      expect(find.text('[kaʈu]'), findsOneWidget);

      // 4 ViolationText widgets for the 4 primary rom lines.
      expect(find.byType(ViolationText), findsNWidgets(4));

      await teardownWidget(tester);
    });

    testWidgets(
        'rom empty falls back to single IPA-only dimmed line',
        (tester) async {
      final ids = await seedTwoDimFixture();
      await writeParadigmAxes(
        db,
        posId: ids.posId,
        axes: ParadigmAxes(rows: ids.numberDimId, cols: ids.genderDimId),
      );

      final chart = _fourCellChart(
        numberDimId: ids.numberDimId,
        genderDimId: ids.genderDimId,
        forms: const ['kat', 'kata', 'kati', 'katu'],
      );

      // Empty-string romanization (simulates romanization returning nothing
      // for an un-mapped phoneme inventory).
      await tester.pumpWidget(buildApp(
        ParadigmTableWidget(lexemeId: ids.lexemeId, posId: ids.posId),
        extraOverrides: [
          computedInflectedParadigmProvider(ids.lexemeId)
              .overrideWithValue(chart),
          romanizeProvider.overrideWithValue((String ipa) => ''),
        ],
      ));
      await settle(tester);

      // Bracketed IPA lines still present.
      expect(find.text('[kat]'), findsOneWidget);
      expect(find.text('[katu]'), findsOneWidget);
      // Empty string should NOT appear as a primary text node.
      expect(find.text(''), findsNothing);
      // Exactly 4 ViolationText widgets (single-line fall-through).
      expect(find.byType(ViolationText), findsNWidgets(4));

      await teardownWidget(tester);
    });
  });
}
