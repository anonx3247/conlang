// Plan 04-17 Task 15 — D-112 regression test: rewrite rules apply to
// phonetic display only, NEVER to romanization.
//
// The invariant: rom = romanize(raw phonemic), phonetic = rewritePipeline(phonemic).
// If rom shows the rewrite output (e.g. `cazana` instead of `casana`), the
// rewrite pipeline leaked into the rom display path.
//
// Test infrastructure mirrors paradigm_viewer_stacked_slices_test.dart.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_table_widget.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart'
    show parseRewriteRule;
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
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
            body: SingleChildScrollView(
              child: SizedBox(width: 2000, height: 1200, child: child),
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

  // --------------------------------------------------------------------------
  // Fixture: seeds POS "Verb" with Number {SG, PL}, a romanization mapping
  // {k->c, s->s, z->z, a->a, n->n}, and a rewrite rule "s -> z / V_V"
  // (intervocalic voicing).
  // --------------------------------------------------------------------------

  Future<({int posId, int lexemeId, int numDimId, int tenseDimId})> seedFixture() async {
    // Phonemes — needed by phonemeInventoryProvider for rewrite rule context.
    for (final c in ['k', 's', 'z', 'n']) {
      await db.into(db.phonemes).insert(
            PhonemesCompanion.insert(symbol: c, type: 'consonant'),
          );
    }
    for (final v in ['a', 'i']) {
      await db.into(db.phonemes).insert(
            PhonemesCompanion.insert(symbol: v, type: 'vowel'),
          );
    }

    // POS
    final posId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );

    // Dimension 1: Number {SG=0, PL=1}
    final numDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Number',
            levelsJson: '[{"id":0,"name":"SG","abbr":"SG","ordering":0},{"id":1,"name":"PL","abbr":"PL","ordering":1}]',
          ),
        );

    // Dimension 2: Tense {PRS=0, PST=1} — needed so paradigm table renders
    // (requires >= 2 non-intrinsic dims for rows x columns).
    final tenseDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: posId,
            name: 'Tense',
            levelsJson: '[{"id":0,"name":"PRS","abbr":"PRS","ordering":0},{"id":1,"name":"PST","abbr":"PST","ordering":1}]',
          ),
        );

    // Inflectional rule: +i (suffix) bound to PL
    final pluralRuleId = await db.into(db.morphologicalRules).insert(
          MorphologicalRulesCompanion.insert(
            name: 'Plural',
            source: '+i',
            kind: const Value('inflectional'),
            featureBindings: Value(
              FeatureBindings(pos: [posId], dims: {numDimId: 1}),
            ),
          ),
        );

    // Inflectional rule: +n (suffix) bound to PST
    final pastRuleId = await db.into(db.morphologicalRules).insert(
          MorphologicalRulesCompanion.insert(
            name: 'Past',
            source: '+n',
            kind: const Value('inflectional'),
            featureBindings: Value(
              FeatureBindings(pos: [posId], dims: {tenseDimId: 1}),
            ),
          ),
        );

    // Link rules to POS via junction table (required by
    // watchInflectionalRulesForPos which inner-joins on InflectionalRulePOS).
    await db.into(db.inflectionalRulePOS).insert(
          InflectionalRulePOSCompanion.insert(
            ruleId: pluralRuleId,
            posId: posId,
          ),
        );
    await db.into(db.inflectionalRulePOS).insert(
          InflectionalRulePOSCompanion.insert(
            ruleId: pastRuleId,
            posId: posId,
          ),
        );

    // Lexeme: root = kasa (k->c makes rom differ from IPA; s between
    // vowels triggers the rewrite rule).
    final lexemeId = await db.into(db.lexemes).insert(
          LexemesCompanion.insert(
            ipa: 'kasa',
            meaning: const Value('to cook'),
            partOfSpeech: const Value('Verb'),
          ),
        );

    // Romanization mappings: k->c, s->s, z->z, a->a, n->n, i->i
    for (final pair in [
      ('k', 'c'),
      ('s', 's'),
      ('z', 'z'),
      ('a', 'a'),
      ('n', 'n'),
      ('i', 'i'),
    ]) {
      await db.into(db.romanizationMappings).insert(
            RomanizationMappingsCompanion.insert(
              ipaSymbol: pair.$1,
              latinMapping: pair.$2,
            ),
          );
    }

    // Enable romanization
    await db.into(db.projectSettings).insert(
          ProjectSettingsCompanion.insert(
            key: 'romanization_enabled',
            value: 'true',
          ),
        );

    // Rewrite rule: s -> z / V_V (intervocalic voicing).
    // The source column stores the full DSL string.
    await db.into(db.rewriteRules).insert(
          RewriteRulesCompanion.insert(
            source: 's -> z / V_V',
            ordering: const Value(0),
          ),
        );

    return (posId: posId, lexemeId: lexemeId, numDimId: numDimId, tenseDimId: tenseDimId);
  }

  // --------------------------------------------------------------------------
  // Unit-level test: computeParadigmCell returns distinct phonemic vs form
  // --------------------------------------------------------------------------

  test('D-112 unit: computeParadigmCell returns phonemic != form when rewrites fire', () {
    final inventory = PhonemeInventory(
      consonants: const ['k', 's', 'z', 'n'],
      vowels: const ['a'],
      naturalClasses: const {},
    );

    // Parse the rewrite rule from DSL.
    final parsed = parseRewriteRule('s -> z / V_V');
    expect(parsed.isValid, isTrue, reason: 'rewrite rule DSL should parse');

    // Use a real suffix rule "+na" so the engine produces 'kasanana'
    // (phonemic), then the rewrite pipeline gives 'kazanana' (phonetic).
    final cell = computeParadigmCell(
      root: 'kasana',
      target: {1: 0},
      rules: [
        InflectionalRule(
          id: 1,
          name: 'plural',
          source: '+na',
          bindings: const FeatureBindings(pos: [], dims: {1: 0}),
          isActive: true,
        ),
      ],
      inventory: inventory,
      rewriteRules: [parsed.rule!],
    );

    expect(cell, isA<ParadigmFilled>());
    final filled = cell as ParadigmFilled;
    // The phonemic (pre-rewrite) should preserve original 's'.
    expect(filled.phonemic, 'kasanana');
    // The form (post-rewrite) should have 's' -> 'z' between vowels.
    expect(filled.form, 'kazanana');
    // They must differ — this is the D-112 invariant.
    expect(filled.phonemic, isNot(equals(filled.form)));
  });

  test('D-112 unit: computeParadigmCell phonemic == form when no rewrites', () {
    final inventory = PhonemeInventory(
      consonants: const ['k', 's', 'n'],
      vowels: const ['a'],
      naturalClasses: const {},
    );

    final cell = computeParadigmCell(
      root: 'kasana',
      target: {1: 0},
      rules: [
        InflectionalRule(
          id: 1,
          name: 'plural',
          source: '+na',
          bindings: const FeatureBindings(pos: [], dims: {1: 0}),
          isActive: true,
        ),
      ],
      inventory: inventory,
      rewriteRules: const [],
    );

    expect(cell, isA<ParadigmFilled>());
    final filled = cell as ParadigmFilled;
    expect(filled.phonemic, 'kasanana');
    expect(filled.form, 'kasanana');
    expect(filled.phonemic, equals(filled.form));
  });

  // --------------------------------------------------------------------------
  // Widget-level test: paradigm table cell rom line shows romanize(phonemic)
  // --------------------------------------------------------------------------

  testWidgets('D-112 widget: paradigm cell rom line shows correct rom not rewritten rom',
      variant: const TargetPlatformVariant({TargetPlatform.macOS}),
      (tester) async {
    final fix = await seedFixture();

    await tester.pumpWidget(buildApp(
      ParadigmTableWidget(
        lexemeId: fix.lexemeId,
        posId: fix.posId,
      ),
    ));
    await settle(tester);

    // Drain any layout overflow exceptions from filled cells that
    // render rom + bracket in a 64px-tall container. These are cosmetic
    // and do not affect the D-112 invariant being tested.
    dynamic e;
    do {
      e = tester.takeException();
    } while (e != null);

    // With root 'kasa' and mappings k->c, suffixes +i (PL) and +n (PST):
    // PL.PST cell: phonemic = kasain, phonetic = kazain (s->z / V_V).
    //   Rom should show 'casain' = romanize('kasain').
    //   NOT 'cazain' = romanize('kazain') — rewrite must NOT leak into rom.
    expect(find.text('casain'), findsWidgets,
        reason: 'rom line should use romanize(phonemic), not romanize(phonetic)');
    expect(find.text('cazain'), findsNothing,
        reason: 'rewrite must not leak into rom display');

    // The phonetic bracket line should show the post-rewrite form.
    expect(find.textContaining('kazain'), findsWidgets,
        reason: 'phonetic bracket line should show post-rewrite form');

    await teardownWidget(tester);
  });
}
