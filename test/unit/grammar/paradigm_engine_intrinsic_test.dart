// Plan 04-17 Task 4 — D-88 / D-89 paradigm engine intrinsic-aware
// rule eval and cell enumeration tests.
//
// Locks:
//   D-88 Test 1 (hit): rule {A=M, B=pl} with intrinsic dim A. Lexeme
//                      {A: M}. Target {B: pl}. → filled (rule fires).
//   D-88 Test 2 (miss): same setup, lexeme {A: F}. → uncovered.
//   D-89 Test 3: generateParadigm on dims [A intrinsic, B non-intrinsic]
//                yields cell keys with ONLY B entries, never A.
//   D-91b Test 4: rule {A=M} only (intrinsic-only), lexeme {A: M},
//                 target {B: sg}. Degenerate state tolerated — no crash;
//                 cell falls back to uncovered because the non-intrinsic
//                 projection of the rule is empty (D-13).
//   D-88 Test 5 (mixed): rule {A=M, B=sg} + rule {B=pl}; lexeme {A: M};
//                       target {B: sg} → rule 1 fires;
//                       target {B: pl} → rule 2 fires.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r'],
    'v': ['a', 'e', 'i', 'o', 'u'],
  },
);

// Dim ids
const int dimA = 10; // A — gender (intrinsic in most tests)
const int dimB = 11; // B — number (non-intrinsic)

// Level ids
const int lvlM = 1;
const int lvlF = 2;
const int lvlSG = 1;
const int lvlPL = 2;

InflectionalRule _rule(
  int id,
  String name,
  String source,
  Map<int, int> dims,
) {
  return InflectionalRule(
    id: id,
    name: name,
    source: source,
    isActive: true,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

/// Build an in-memory Dimension row.
Dimension _dim({
  required int id,
  required String name,
  required List<DimensionLevel> levels,
  required bool intrinsic,
}) {
  return Dimension(
    id: id,
    posId: 1,
    name: name,
    ordering: 0,
    levelsJson: encodeLevelsJson(levels),
    templateId: null,
    intrinsic: intrinsic,
  );
}

void main() {
  group('computeParadigmCell — 04-17 D-88 intrinsic short-circuit', () {
    test('Test 1 (hit) — rule {A=M, B=pl} + lexeme {A=M} + target {B=pl} → filled',
        () {
      final rules = [
        _rule(1, 'plural-masc', '+is', const {dimA: lvlM, dimB: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimB: lvlPL},
        rules: rules,
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlM},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['plural-masc']));
      expect(filled.form, equals('katis'));
    });

    test('Test 2 (miss) — lexeme {A=F} with rule {A=M, B=pl} → uncovered',
        () {
      final rules = [
        _rule(1, 'plural-masc', '+is', const {dimA: lvlM, dimB: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimB: lvlPL},
        rules: rules,
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlF},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('Test 4 (D-91b degenerate) — rule with ONLY intrinsic bindings → uncovered, no crash',
        () {
      // Rule {A=M} only (pure intrinsic constraint). The two-stage filter:
      // - matchesIntrinsicConstraints passes (lexeme A=M).
      // - _nonIntrinsicBindings projects to {}, _isSubset rejects empty.
      // So the rule is filtered out as a candidate. `remaining` never
      // empties and the loop exits via "candidates empty + chain empty"
      // → markerOrUncovered. No crash, no infinite loop.
      final rules = [
        _rule(1, 'only-masc', '+o', const {dimA: lvlM}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimB: lvlSG},
        rules: rules,
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlM},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('Test 5 (mixed) — intrinsic filter + non-intrinsic axis work together',
        () {
      final rules = [
        _rule(1, 'sg-masc', '+o', const {dimA: lvlM, dimB: lvlSG}),
        _rule(2, 'pl', '+s', const {dimB: lvlPL}),
      ];

      // Cell B=sg, lexeme A=M: rule 1 fires (intrinsic M match; B=sg axis).
      final sg = computeParadigmCell(
        root: 'kat',
        target: const {dimB: lvlSG},
        rules: rules,
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlM},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );
      expect(sg, isA<ParadigmFilled>());
      expect((sg as ParadigmFilled).form, equals('kato'));
      expect(sg.ruleChain.map((r) => r.name), equals(['sg-masc']));

      // Cell B=pl, lexeme A=M: rule 2 fires (no A binding — unconditional).
      final pl = computeParadigmCell(
        root: 'kat',
        target: const {dimB: lvlPL},
        rules: rules,
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlM},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );
      expect(pl, isA<ParadigmFilled>());
      expect((pl as ParadigmFilled).form, equals('kats'));
      expect(pl.ruleChain.map((r) => r.name), equals(['pl']));
    });
  });

  group('generateParadigm — 04-17 D-89 Cartesian filter', () {
    test('Test 3 — intrinsic dim A is filtered out of cell enumeration', () {
      final aDim = _dim(
        id: dimA,
        name: 'Gender',
        levels: const [
          DimensionLevel(id: lvlM, name: 'M', abbr: 'M', ordering: 0),
          DimensionLevel(id: lvlF, name: 'F', abbr: 'F', ordering: 1),
        ],
        intrinsic: true,
      );
      final bDim = _dim(
        id: dimB,
        name: 'Number',
        levels: const [
          DimensionLevel(id: lvlSG, name: 'SG', abbr: 'SG', ordering: 0),
          DimensionLevel(id: lvlPL, name: 'PL', abbr: 'PL', ordering: 1),
        ],
        intrinsic: false,
      );

      final chart = generateParadigm(
        root: 'kat',
        dimensions: [aDim, bDim],
        rules: [
          _rule(1, 'pl', '+s', const {dimB: lvlPL}),
        ],
        inventory: _inventory,
        lexemeIntrinsicLevels: const {dimA: lvlM},
        dimensionIntrinsicFlags: const {dimA: true, dimB: false},
      );

      // Exactly 2 cells (B=sg and B=pl) — not 4.
      expect(chart.length, equals(2));
      for (final entry in chart.entries) {
        expect(entry.featureSet.keys, equals({dimB}),
            reason: 'intrinsic dim A must NOT appear in cell keys');
        expect(entry.featureSet.containsKey(dimA), isFalse);
      }
    });
  });
}
