// Repro for user-reported bug 2026-04-11:
//   Verb "sana" derived to noun "sanaci" via suffix "ci".
//   Root noun "aafo" inflects correctly: aafo/aafa (SG), aafos/aafas (PL).
//   Derived noun "sanaci" inflects WRONGLY: -/- (SG), sanaciso/sanacisa (PL).
//
// The user's rules:
//   - masc (bound {gender:M}): two branches
//       1. endsWith C -> suffix "o"
//       2. endsWith V -> ablaut replace 1 from-end "V" with "o"
//   - fem (bound {gender:F}): two branches, same shape with "a"
//   - plural (bound {number:PL}): suffix "s"
//
// This test reproduces the observed behavior using the paradigm engine
// directly. If the engine produces the right values we know the bug is in
// the provider / translation layer. If it produces the user's broken
// values we know the engine is the culprit.

import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart'
    as vm;
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Dim ids: Gender=1, Number=2. Level ids within each dim start at 1.
  const genderDim = 1;
  const numberDim = 2;
  const levelM = 1;
  const levelF = 2;
  const levelSG = 1;
  const levelPL = 2;

  const inventory = PhonemeInventory(
    consonants: ['s', 'n', 'c', 'f'],
    vowels: ['a', 'e', 'i', 'o', 'u'],
    naturalClasses: {
      'c': ['s', 'n', 'c', 'f'],
      'v': ['a', 'e', 'i', 'o', 'u'],
    },
  );

  vm.InflectionalRule build({
    required int id,
    required String name,
    required String source,
    required Map<int, int> dims,
  }) {
    return vm.InflectionalRule(
      id: id,
      name: name,
      source: source,
      isActive: true,
      bindings: FeatureBindings(pos: const [1], dims: dims),
    );
  }

  // Masc serialized DSL: two branches
  //   "C"$ +o | "V"$ /V/o/e1
  final masc = build(
    id: 1,
    name: 'masculine',
    source: r'"C"$ +o | "V"$ /V/o/e1',
    dims: {genderDim: levelM},
  );
  final fem = build(
    id: 2,
    name: 'feminine',
    source: r'"C"$ +a | "V"$ /V/a/e1',
    dims: {genderDim: levelF},
  );
  final plural = build(
    id: 3,
    name: 'plural',
    source: '+s',
    dims: {numberDim: levelPL},
  );

  final rules = [masc, fem, plural];

  group('aafo root noun (baseline — works per user)', () {
    test('aafo M.SG → aafo', () {
      final cell = computeParadigmCell(
        root: 'aafo',
        target: const {genderDim: levelM, numberDim: levelSG},
        rules: rules,
        inventory: inventory,
      );
      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, 'aafo');
    });

    test('aafo M.PL → aafos', () {
      final cell = computeParadigmCell(
        root: 'aafo',
        target: const {genderDim: levelM, numberDim: levelPL},
        rules: rules,
        inventory: inventory,
      );
      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, 'aafos');
    });

    test('aafo F.SG → aafa', () {
      final cell = computeParadigmCell(
        root: 'aafo',
        target: const {genderDim: levelF, numberDim: levelSG},
        rules: rules,
        inventory: inventory,
      );
      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, 'aafa');
    });

    test('aafo F.PL → aafas', () {
      final cell = computeParadigmCell(
        root: 'aafo',
        target: const {genderDim: levelF, numberDim: levelPL},
        rules: rules,
        inventory: inventory,
      );
      expect(cell, isA<ParadigmFilled>());
      expect((cell as ParadigmFilled).form, 'aafas');
    });
  });

  group('sanaci derived noun (user reports broken)', () {
    test('sanaci M.SG → sanaco (user sees "-")', () {
      final cell = computeParadigmCell(
        root: 'sanaci',
        target: const {genderDim: levelM, numberDim: levelSG},
        rules: rules,
        inventory: inventory,
      );
      // Diagnostic: print what the engine actually returned.
      print('sanaci M.SG: $cell');
      if (cell is ParadigmFilled) {
        expect(cell.form, 'sanaco');
      } else {
        fail('Expected ParadigmFilled("sanaco") but got ${cell.runtimeType}');
      }
    });

    test('sanaci M.PL → sanacos (user sees "sanaciso")', () {
      final cell = computeParadigmCell(
        root: 'sanaci',
        target: const {genderDim: levelM, numberDim: levelPL},
        rules: rules,
        inventory: inventory,
      );
      print('sanaci M.PL: $cell');
      if (cell is ParadigmFilled) {
        expect(cell.form, 'sanacos');
      } else {
        fail('Expected ParadigmFilled("sanacos") but got ${cell.runtimeType}');
      }
    });

    test('sanaci F.SG → sanaca', () {
      final cell = computeParadigmCell(
        root: 'sanaci',
        target: const {genderDim: levelF, numberDim: levelSG},
        rules: rules,
        inventory: inventory,
      );
      print('sanaci F.SG: $cell');
      if (cell is ParadigmFilled) {
        expect(cell.form, 'sanaca');
      } else {
        fail('Expected ParadigmFilled("sanaca") but got ${cell.runtimeType}');
      }
    });

    test('sanaci F.PL → sanacas (user sees "sanacisa")', () {
      final cell = computeParadigmCell(
        root: 'sanaci',
        target: const {genderDim: levelF, numberDim: levelPL},
        rules: rules,
        inventory: inventory,
      );
      print('sanaci F.PL: $cell');
      if (cell is ParadigmFilled) {
        expect(cell.form, 'sanacas');
      } else {
        fail('Expected ParadigmFilled("sanacas") but got ${cell.runtimeType}');
      }
    });
  });

  // Sanity: make sure masc rule DSL parses correctly and fires on "sanaci".
  test('masc rule DSL parses and matches sanaci endsWith V branch', () {
    final parsed = parseMorphDsl(masc.source, id: masc.id, name: masc.name);
    expect(parsed.isValid, isTrue,
        reason: 'masc DSL must round-trip. error: ${parsed.error}');
    expect(parsed.rule!.branches.length, 2);
    // Branch 2 should be endsWith V + AblautOp
    final branch2 = parsed.rule!.branches[1];
    expect(branch2.conditions.length, 1);
    final cond = branch2.conditions.first;
    expect(cond, isA<PatternCond>());
    expect((cond as PatternCond).pattern, 'V');
    expect(cond.position, CondPosition.endsWith);
    // Op should be AblautOp
    expect(branch2.operations.length, 1);
    expect(branch2.operations.first, isA<AblautOp>());
    final op = branch2.operations.first as AblautOp;
    expect(op.from, 'V');
    expect(op.to, 'o');
    expect(op.direction, AblautDirection.fromEnd);
    expect(op.count, 1);
  });
}
