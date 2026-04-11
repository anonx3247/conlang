// Plan 04-07 Task 3 — widget tests for the Lexicon word detail paradigm
// embed. A new `WordDetailParadigmSection` widget is mounted in the
// word_detail_panel below the derivation tree. It is only rendered when
// `posForLexeme(lexeme, posList)` resolves to a POS AND that POS has
// ≥1 dimension (per CONTEXT.md D-27 and the plan's guard conditions).
//
// Testing WordDetailPanel directly would require standing up Drift +
// romanization + phonotactic + morphology providers. Instead we test the
// extracted `WordDetailParadigmSection` widget in isolation — it's the
// single load-bearing piece of this task.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/axis_config_bar.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/coverage_matrix_panel.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_detail_panel.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  // Suppress pre-existing RuleEditorDialog / sidebar overflow noise from
  // other widgets mounted indirectly. See plan 04-05 deferred-items.md.
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

  /// Seed a Noun POS with a single Number dimension (SG/PL). Returns the
  /// posId so callers can construct lexemes that resolve to it via
  /// `posForLexeme`.
  Future<int> seedNounWithNumber() async {
    final nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
    return nounPosId;
  }

  /// Seed a POS with NO dimensions (for the negative-case test).
  Future<void> seedAdjectiveNoDimensions() async {
    await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Adjective', abbreviation: 'Adj'),
        );
  }

  /// Insert a lexeme into the DB and return the Drift row.
  Future<Lexeme> insertLexeme({
    required String ipa,
    String? partOfSpeech,
  }) async {
    final id = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: ipa,
            partOfSpeech: Value(partOfSpeech),
          ),
        );
    return (db.select(db.lexemes)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget buildApp(Widget child) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1200, height: 900, child: child),
          ),
        ),
      );

  /// Settle with a real async delay so Drift stream queries can materialise
  /// their first event.
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
    await tester.pump(const Duration(milliseconds: 150));
  }

  group('WordDetailParadigmSection guard conditions (D-27)', () {
    testWidgets(
      'Test 1 — POS resolves AND has ≥1 dimension → Paradigm section renders',
      (tester) async {
        await seedNounWithNumber();
        final noun = await insertLexeme(ipa: 'kat', partOfSpeech: 'Noun');

        await tester.pumpWidget(
          buildApp(WordDetailParadigmSection(word: noun)),
        );
        await settle(tester);

        expect(find.text('Paradigm'), findsOneWidget);
        expect(find.byType(ParadigmTableWidget), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — lexeme with null partOfSpeech → no Paradigm section',
      (tester) async {
        await seedNounWithNumber();
        final bare = await insertLexeme(ipa: 'kat', partOfSpeech: null);

        await tester.pumpWidget(
          buildApp(WordDetailParadigmSection(word: bare)),
        );
        await settle(tester);

        expect(find.text('Paradigm'), findsNothing);
        expect(find.byType(ParadigmTableWidget), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      "Test 3 — lexeme partOfSpeech doesn't match any POS row → no Paradigm",
      (tester) async {
        await seedNounWithNumber();
        // partOfSpeech text does not exist in the POS table.
        final stray = await insertLexeme(
          ipa: 'kat',
          partOfSpeech: 'Nonexistent',
        );

        await tester.pumpWidget(
          buildApp(WordDetailParadigmSection(word: stray)),
        );
        await settle(tester);

        expect(find.text('Paradigm'), findsNothing);
        expect(find.byType(ParadigmTableWidget), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — resolved POS has ZERO dimensions → no Paradigm section',
      (tester) async {
        await seedAdjectiveNoDimensions();
        final adj = await insertLexeme(
          ipa: 'red',
          partOfSpeech: 'Adjective',
        );

        await tester.pumpWidget(
          buildApp(WordDetailParadigmSection(word: adj)),
        );
        await settle(tester);

        expect(find.text('Paradigm'), findsNothing);
        expect(find.byType(ParadigmTableWidget), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — the embedded paradigm is read-only '
      '(no AxisConfigBar, no CoverageMatrixPanel per D-27)',
      (tester) async {
        await seedNounWithNumber();
        final noun = await insertLexeme(ipa: 'kat', partOfSpeech: 'Noun');

        await tester.pumpWidget(
          buildApp(WordDetailParadigmSection(word: noun)),
        );
        await settle(tester);

        // D-27: Lexicon reflects the axis config set in Grammar — no
        // axis reconfiguration UI in the Lexicon embed.
        expect(find.byType(AxisConfigBar), findsNothing);
        // Coverage matrix lives only in Grammar → Paradigm Viewer.
        expect(find.byType(CoverageMatrixPanel), findsNothing);

        await teardownWidget(tester);
      },
    );
  });
}
