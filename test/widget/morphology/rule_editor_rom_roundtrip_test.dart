// Plan 04-15 Task 2 / D-73 + D-78: Widget tests for the rule editor rom
// input → phonemic storage contract and the D-78 dot round-trip on both
// save and load paths.
//
// To avoid flaky teardown from Drift stream-query timers on in-memory
// databases, we use the same `settle()` + `teardownWidget()` pattern
// pioneered by rule_editor_dialog_kind_test.dart.
//
// The save-path tests verify the contract via the deromanize provider
// (which is exactly what `_save()` calls) rather than trying to drive
// the dialog's nested TextField tree.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart'
    as dsl;
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/phonology/data/romanization_providers.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int nounPosId;

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
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedRomanization(List<(String ipa, String latin)> rows) async {
    for (final row in rows) {
      await db.romanizationDao.insertMapping(
        RomanizationMappingsCompanion.insert(
          ipaSymbol: row.$1,
          latinMapping: row.$2,
        ),
      );
    }
  }

  Future<void> setRomEnabled(bool enabled) async {
    await db.into(db.projectSettings).insert(
          ProjectSettingsCompanion.insert(
            key: 'romanization_enabled',
            value: enabled.toString(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<int> seedRule(String name, String source) async {
    return db.into(db.morphologicalRules).insert(
          MorphologicalRulesCompanion.insert(
            name: name,
            source: source,
            ordering: const Value(0),
            kind: const Value('derivational'),
            inputPosId: Value(nounPosId),
            outputPosId: Value(nounPosId),
          ),
        );
  }

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

  /// Settle with real async delays so Drift stream queries can materialise
  /// their first event (Drift schedules the emit via a Timer.run that
  /// `tester.pump` alone does not drain). Mirrors the pattern in
  /// `rule_editor_dialog_kind_test.dart`.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Drains pending Drift stream-query timers before teardown.
  Future<void> teardownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Returns the set of controller text values for every TextField in the
  /// current widget tree.
  Set<String> collectTextFieldValues(WidgetTester tester) {
    final result = <String>{};
    for (final element in find.byType(TextField).evaluate()) {
      final tf = element.widget as TextField;
      final text = tf.controller?.text ?? '';
      result.add(text);
    }
    return result;
  }

  /// Pump a minimal host widget that reads the given provider and returns
  /// the deromanized/romanized value for [input]. Uses the same settle
  /// pattern so the mappings stream has time to emit.
  Future<String> callProvider(
    WidgetTester tester, {
    required bool useDeromanize,
    required String input,
  }) async {
    String? captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (ctx, ref, _) {
              final mappings = ref.watch(romanizationMappingsProvider);
              return mappings.when(
                data: (_) {
                  final fn = useDeromanize
                      ? ref.read(deromanizeProvider)
                      : ref.read(romanizeProvider);
                  captured = fn(input);
                  return const SizedBox();
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            },
          ),
        ),
      ),
    ));
    await settle(tester);
    return captured ?? '';
  }

  // -------------------------------------------------------------------------
  // D-73 save-path provider tests
  // -------------------------------------------------------------------------

  group('D-73 Test 1: rom "sh" deromanizes to ʃ under {ʃ→sh} mapping', () {
    testWidgets('save path', (tester) async {
      await seedRomanization([('ʃ', 'sh'), ('a', 'a')]);
      final result =
          await callProvider(tester, useDeromanize: true, input: 'sh');
      expect(result, equals('ʃ'));
      await teardownWidget(tester);
    });
  });

  group('D-73 Test 3: rom disabled → identity', () {
    testWidgets('no mappings → identity', (tester) async {
      final result =
          await callProvider(tester, useDeromanize: true, input: 'sh');
      expect(result, equals('sh'));
      await teardownWidget(tester);
    });
  });

  // -------------------------------------------------------------------------
  // D-73 load-path tests — drive the dialog and inspect controllers
  // -------------------------------------------------------------------------

  group('D-73 Test 2: stored ʃ renders as "sh" on load', () {
    testWidgets('load path', (tester) async {
      await seedRomanization([('ʃ', 'sh'), ('a', 'a')]);
      await setRomEnabled(true);

      final id = await seedRule('PreExisting', '+ʃ');
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();

      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      expect(collectTextFieldValues(tester), contains('sh'));
      await teardownWidget(tester);
    });
  });

  group('D-73 Test 4: class-ref passthrough', () {
    testWidgets('condition pattern containing V survives load', (tester) async {
      await seedRomanization([('ʃ', 'sh'), ('a', 'a')]);
      await setRomEnabled(true);

      // Serialize a rule with a contains-V condition so the DSL parser
      // actually accepts the source string. The test asserts that the
      // class-ref "V" in the condition pattern flows through unchanged
      // — it is NOT wrapped through romanize (WARN-1 deferred) and is
      // structurally matched, not phonologically.
      final tempRule = dsl.MorphologicalRule(
        id: 0,
        name: 'ClassRef',
        branches: [
          dsl.MorphBranch(
            conditions: const [
              dsl.PatternCond('V', position: dsl.CondPosition.contains),
            ],
            operations: const [dsl.SuffixOp('a')],
          ),
        ],
        source: '',
      );
      final src = dsl.serializeMorphRule(tempRule);
      final id = await seedRule('ClassRef', src);
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();

      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      // The condition pattern field should contain exactly "V" — class-refs
      // bypass romanize()/deromanize() and the condition pattern is not
      // wrapped anyway (WARN-1 deferred).
      expect(collectTextFieldValues(tester), contains('V'),
          reason: 'Class-ref V must appear unchanged in a condition field');
      await teardownWidget(tester);
    });
  });

  // -------------------------------------------------------------------------
  // D-72 bijection gate
  // -------------------------------------------------------------------------

  group('D-73 Test 5: bijection gate locks the editor', () {
    testWidgets('save button hidden when conflicts exist', (tester) async {
      await seedRomanization([('s', 's'), ('ʃ', 's')]);
      await setRomEnabled(true);

      await tester.pumpWidget(buildApp(
        const RuleEditorDialog(kind: RuleKind.derivational),
      ));
      await settle(tester);

      expect(find.textContaining('Rule editor is locked until romanization'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

      await teardownWidget(tester);
    });
  });

  // -------------------------------------------------------------------------
  // WARN-1 deferral lock
  // -------------------------------------------------------------------------

  group('D-73 Test 6: WARN-1 template deferral lock', () {
    testWidgets('template literal runs stored as-typed', (tester) async {
      await seedRomanization([('tʃ', 'ch')]);
      await setRomEnabled(true);

      final tempRule = dsl.MorphologicalRule(
        id: 0,
        name: 'Tmpl',
        branches: [
          dsl.MorphBranch(
            conditions: const [],
            operations: const [dsl.TemplateOp('1a23chi')],
          ),
        ],
        source: '',
      );
      final src = dsl.serializeMorphRule(tempRule);
      final id = await seedRule('Tmpl', src);
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();

      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      final values = collectTextFieldValues(tester);
      final hasChi = values.any((v) => v.contains('chi'));
      expect(hasChi, isTrue,
          reason: 'Template field must still contain literal "chi" — '
              'WARN-1 deferral of template wrapping');
      await teardownWidget(tester);
    });
  });

  // -------------------------------------------------------------------------
  // D-78 dot round-trip
  // -------------------------------------------------------------------------

  group('D-78 Test 7: dot round-trip (save-path provider)', () {
    testWidgets('"at.ha" → /atha/ and "atha" → /aθa/', (tester) async {
      await seedRomanization([
        ('a', 'a'),
        ('t', 't'),
        ('h', 'h'),
        ('θ', 'th'),
      ]);
      final r1 =
          await callProvider(tester, useDeromanize: true, input: 'at.ha');
      expect(r1, equals('atha'),
          reason: 'D-78: "at.ha" must deromanize to three separate '
              'phonemes (no θ) — dot is consumed and resets the scan.');
      final r2 =
          await callProvider(tester, useDeromanize: true, input: 'atha');
      expect(r2, equals('aθa'),
          reason: 'D-78: "atha" (no dot) deromanizes to /aθa/ via '
              'longest-match.');
      await teardownWidget(tester);
    });
  });

  group('D-78 Test 8: dot round-trip (load path)', () {
    testWidgets('/atha/ renders as "at.ha"', (tester) async {
      await seedRomanization([
        ('a', 'a'),
        ('t', 't'),
        ('h', 'h'),
        ('θ', 'th'),
      ]);
      await setRomEnabled(true);

      final id = await seedRule('AthaRule', '+atha');
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      expect(collectTextFieldValues(tester), contains('at.ha'),
          reason: 'D-78: stored /atha/ must smart-romanize to "at.ha" '
              'on load via smartRomanize boundary insertion');
      await teardownWidget(tester);
    });

    testWidgets('/aθa/ renders as "atha" (no dot)', (tester) async {
      await seedRomanization([
        ('a', 'a'),
        ('t', 't'),
        ('h', 'h'),
        ('θ', 'th'),
      ]);
      await setRomEnabled(true);

      final id = await seedRule('ThetaRule', '+aθa');
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      expect(collectTextFieldValues(tester), contains('atha'),
          reason: 'D-78: stored /aθa/ must smart-romanize to "atha" '
              '(no dot needed)');
      await teardownWidget(tester);
    });
  });

  group('D-78 Test 9: helper text surfaces dot escape hatch', () {
    testWidgets('"use . to force a glyph boundary" visible', (tester) async {
      await seedRomanization([
        ('a', 'a'),
        ('t', 't'),
        ('h', 'h'),
        ('θ', 'th'),
      ]);
      await setRomEnabled(true);

      final id = await seedRule('Hint', '+a');
      final row = await (db.select(db.morphologicalRules)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await tester.pumpWidget(buildApp(
        RuleEditorDialog(
          kind: RuleKind.derivational,
          existing: row,
        ),
      ));
      await settle(tester);

      expect(
        find.textContaining('use . to force a glyph boundary'),
        findsAtLeastNWidgets(1),
      );
      await teardownWidget(tester);
    });
  });
}
