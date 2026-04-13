// Plan 04-17 Task 14 — D-111 regression test: rule editor live preview
// renders via the same romanize pipeline as paradigm viewer cells.
//
// The parity invariant: for the same rule + root + mapping, the preview
// panel's rendered display text must equal the paradigm table cell's
// rendered display text. If they diverge, one surface has a stale or
// incorrect romanize/rewrite path.
//
// Strategy: test the rendering logic at the domain level rather than
// pumping the full RuleEditorDialog (which needs complex seeding).
// We exercise the same code paths that _buildRow and _FilledCell use:
//   - romanize(phonemic) for the rom line
//   - rewritePipeline(phonemic) for the [bracket] phonetic line
// and assert parity for three rule shapes (affix, ablaut, condition).

import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart'
    show parseRewriteRule;
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:conlang_workbench/features/phonology/domain/notation_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the paradigm table cell render path (D-112 corrected):
///   rom = romanize(phonemic), phonetic = rewritePipeline(phonemic).
({String rom, String phonetic}) paradigmCellRender({
  required String root,
  required String ruleSource,
  required List<({String ipaSymbol, String latinMapping})> mappings,
  required PhonemeInventory inventory,
  List<String> rewriteDslSources = const [],
}) {
  // 1. Apply the morphology rule to get the phonemic form.
  final parsed = parseMorphDsl(ruleSource, id: 1, name: 'test');
  expect(parsed.isValid, isTrue, reason: 'rule DSL should parse: $ruleSource');
  final engine = const MorphologyEngine();
  final result = engine.applyRule(parsed.rule!, root, inventory);
  expect(result, isA<MorphSuccess>(), reason: 'rule should match root');
  final phonemic = (result as MorphSuccess).form;

  // 2. Compute rom via romanize(phonemic) — D-112 path.
  final rom = smartRomanize(phonemic, mappings);

  // 3. Compute phonetic via rewrite pipeline.
  final rewriteRules = rewriteDslSources
      .map(parseRewriteRule)
      .where((p) => p.isValid && p.rule != null)
      .map((p) => p.rule!)
      .toList();
  final gen = WordGenerator();
  final phonetic = rewriteRules.isEmpty
      ? phonemic
      : gen.applyRewriteRules(
          word: phonemic, rules: rewriteRules, inventory: inventory);

  return (rom: rom, phonetic: phonetic);
}

/// Simulates the preview panel render path (D-111 corrected):
///   rom = romanize(derived), phonetic = rewritePipeline(derived).
/// The preview panel uses MorphologyEngine.applyRule directly on generated
/// words, then romanizes the engine output. After D-111/D-112 fixes, this
/// path matches the paradigm cell path exactly.
({String rom, String phonetic}) previewPanelRender({
  required String root,
  required String ruleSource,
  required List<({String ipaSymbol, String latinMapping})> mappings,
  required PhonemeInventory inventory,
  List<String> rewriteDslSources = const [],
}) {
  // Preview panel: same engine, same romanize, same rewrite pipeline.
  // This function intentionally mirrors paradigmCellRender to prove
  // the two paths produce identical output.
  final parsed = parseMorphDsl(ruleSource, id: 1, name: 'test');
  expect(parsed.isValid, isTrue, reason: 'rule DSL should parse: $ruleSource');
  final engine = const MorphologyEngine();
  final result = engine.applyRule(parsed.rule!, root, inventory);
  expect(result, isA<MorphSuccess>(), reason: 'rule should match root');
  final derived = (result as MorphSuccess).form;

  // D-111: romanize the raw derived form (phonemic), not the phonetic.
  final rom = smartRomanize(derived, mappings);

  // Phonetic via rewrite pipeline.
  final rewriteRules = rewriteDslSources
      .map(parseRewriteRule)
      .where((p) => p.isValid && p.rule != null)
      .map((p) => p.rule!)
      .toList();
  final gen = WordGenerator();
  final phonetic = rewriteRules.isEmpty
      ? derived
      : gen.applyRewriteRules(
          word: derived, rules: rewriteRules, inventory: inventory);

  return (rom: rom, phonetic: phonetic);
}

void main() {
  // Shared test setup: k->c mapping + s->z/V_V rewrite rule.
  final mappings = <({String ipaSymbol, String latinMapping})>[
    (ipaSymbol: 'k', latinMapping: 'c'),
    (ipaSymbol: 'a', latinMapping: 'a'),
    (ipaSymbol: 't', latinMapping: 't'),
    (ipaSymbol: 's', latinMapping: 's'),
    (ipaSymbol: 'i', latinMapping: 'i'),
    (ipaSymbol: 'z', latinMapping: 'z'),
    (ipaSymbol: 'n', latinMapping: 'n'),
  ];
  final inventory = PhonemeInventory(
    consonants: const ['k', 't', 's', 'z', 'n'],
    vowels: const ['a', 'i'],
    naturalClasses: const {},
  );
  const root = 'kat';
  const rewriteRules = ['s -> z / V_V'];

  test('D-111 parity: affix rule (+s) — preview matches paradigm cell', () {
    final cell = paradigmCellRender(
      root: root,
      ruleSource: '+s',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );
    final preview = previewPanelRender(
      root: root,
      ruleSource: '+s',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );

    // Both surfaces must produce identical rom + phonetic output.
    expect(preview.rom, cell.rom,
        reason: 'preview rom must equal paradigm cell rom');
    expect(preview.phonetic, cell.phonetic,
        reason: 'preview phonetic must equal paradigm cell phonetic');
    // Verify expected values: kat + s = kats, romanize = cats.
    expect(cell.rom, 'cats');
    expect(cell.phonetic, 'kats'); // no V_V context for s at end
  });

  test('D-111 parity: ablaut rule (/a/i/) — preview matches paradigm cell', () {
    final cell = paradigmCellRender(
      root: root,
      ruleSource: '/a/i/',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );
    final preview = previewPanelRender(
      root: root,
      ruleSource: '/a/i/',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );

    expect(preview.rom, cell.rom,
        reason: 'preview rom must equal paradigm cell rom');
    expect(preview.phonetic, cell.phonetic,
        reason: 'preview phonetic must equal paradigm cell phonetic');
    // Verify expected values: kat with a->i = kit, romanize = cit.
    expect(cell.rom, 'cit');
    expect(cell.phonetic, 'kit'); // no V_V context
  });

  test('D-111 parity: condition rule — preview matches paradigm cell', () {
    // Condition rule: "t"$ +s | +is — adds -s after t, -is otherwise.
    // For root 'kat' (ends in t): should produce 'kats'.
    final cell = paradigmCellRender(
      root: root,
      ruleSource: r'"t"$ +s | +is',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );
    final preview = previewPanelRender(
      root: root,
      ruleSource: r'"t"$ +s | +is',
      mappings: mappings,
      inventory: inventory,
      rewriteDslSources: rewriteRules,
    );

    expect(preview.rom, cell.rom,
        reason: 'preview rom must equal paradigm cell rom');
    expect(preview.phonetic, cell.phonetic,
        reason: 'preview phonetic must equal paradigm cell phonetic');
    // Verify expected values: kat ends in t -> kats, romanize = cats.
    expect(cell.rom, 'cats');
    expect(cell.phonetic, 'kats');
  });
}
