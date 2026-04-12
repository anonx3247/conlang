// Plan 04-10 Task 3 — locks the D-45 resolution order and the D-46
// rule-wins-on-tie tiebreaker in computeParadigmCell + generateParadigm.
//
// D-45 (resolution order):
//   1. Per-word override   (handled at the widget layer, not here)
//   2. Inflectional rule   (existing feature-consumption loop)
//   3. Marker              (NEW — fires only when the rule chain is empty)
//   4. Uncovered           (fall-through when nothing matched)
//
// D-46 (tie-breaking): on exact ties between a rule and a marker with the
// SAME binding dims, the rule wins. This is automatic: markers are only
// consulted when the rule loop produced NO chain (chain.isEmpty).

import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/marker.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/db/app_database.dart';

final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r'],
    'v': ['a', 'e', 'i', 'o', 'u'],
  },
);

// Dim + level ids
const int dimGender = 10;
const int dimNumber = 11;
const int dimCase = 12;
const int lvlM = 1;
const int lvlF = 2;
const int lvlPL = 1;
const int lvlSG = 2;
const int lvlDAT = 1;

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

MarkerDecl _marker(int id, Map<int, int> dims, {int posId = 1}) {
  return MarkerDecl(
    id: id,
    posId: posId,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

void main() {
  group('computeParadigmCell — D-45 resolution order', () {
    test('Test 1: marker fills an otherwise uncovered cell (step 3)', () {
      // No rules; one marker bound to {number:PL}. Target {number:PL}.
      // Expected: ParadigmUnmarked with the bare root.
      final markers = [_marker(1, const {dimNumber: lvlPL})];
      final result = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: const [],
        inventory: _inventory,
        markers: markers,
      );
      expect(result, isA<ParadigmUnmarked>());
      final u = result as ParadigmUnmarked;
      expect(u.root, equals('kata'));
      expect(u.source.id, equals(1));
    });

    test('Test 2: rule beats marker on identical bindings (D-46 tie-break)',
        () {
      // A rule and a marker both bound to exactly {number:PL}. Target
      // {number:PL}. Expected: ParadigmFilled — rule wins on the tie.
      final rules = [_rule(1, '-s', '+s', const {dimNumber: lvlPL})];
      final markers = [_marker(1, const {dimNumber: lvlPL})];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
        markers: markers,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.form, equals('kats'));
      expect(filled.ruleChain.map((r) => r.name), equals(['-s']));
    });

    test('Test 3: higher-specificity marker wins when rule has lower spec',
        () {
      // Rule binds {number:PL} (spec 1). Marker binds {number:PL, case:DAT}
      // (spec 2). Target {number:PL, case:DAT}. The rule's DSL fails its
      // condition so it produces no chain, BUT more importantly the engine's
      // D-45 step 3 consults markers only when chain.isEmpty — so here the
      // rule chain fires first on {number:PL} (spec 1) and consumes PL.
      // Remaining {case:DAT} has no rule → engine returns ParadigmFilled
      // with the rule chain (no marker involvement).
      //
      // To actually exercise "marker with greater specificity than any rule
      // that fires on the whole cell", we use a rule whose DSL fails so no
      // chain is produced, leaving markers as the only winner.
      final rules = [
        _rule(1, '-bad', '"zzz"\$ +bad', const {dimNumber: lvlPL}),
      ];
      final markers = [
        _marker(1, const {dimNumber: lvlPL, dimCase: lvlDAT}),
      ];
      final result = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL, dimCase: lvlDAT},
        rules: rules,
        inventory: _inventory,
        markers: markers,
      );
      expect(result, isA<ParadigmUnmarked>());
      final u = result as ParadigmUnmarked;
      expect(u.root, equals('kata'));
      expect(
        u.source.bindings.dims,
        equals({dimNumber: lvlPL, dimCase: lvlDAT}),
      );
    });

    test(
        'Test 4: mixed rule+marker with DIFFERENT bindings → ParadigmFilled (rule fires, marker not consulted)',
        () {
      // Rule: {number:PL} (spec 1). Marker: {case:DAT} (spec 1).
      // Target: {number:PL, case:DAT}. The rule fires first, consumes
      // number:PL, and the engine returns ParadigmFilled with a partial
      // chain (the remaining {case:DAT} has no rule, and markers are only
      // consulted when chain.isEmpty per D-45/D-46 — the rule wins).
      final rules = [_rule(1, '-s', '+s', const {dimNumber: lvlPL})];
      final markers = [_marker(1, const {dimCase: lvlDAT})];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL, dimCase: lvlDAT},
        rules: rules,
        inventory: _inventory,
        markers: markers,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.form, equals('kats'));
      expect(filled.ruleChain.map((r) => r.name), equals(['-s']));
    });

    test(
        'Test 5: two markers with identical bindings → ParadigmUnmarked (first wins, not ambiguous)',
        () {
      // Unlike rules, two markers asserting the same "no form change" are
      // not contradictory — they assert absence. The engine picks one
      // deterministically (first in sort order) and does NOT surface a
      // ParadigmAmbiguous for marker ties.
      final markers = [
        _marker(1, const {dimNumber: lvlPL}),
        _marker(2, const {dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: const [],
        inventory: _inventory,
        markers: markers,
      );
      expect(result, isA<ParadigmUnmarked>());
    });

    test('Test 6: no rule and no marker → ParadigmUncovered', () {
      final result = computeParadigmCell(
        root: 'kata',
        target: const {dimNumber: lvlPL},
        rules: const [],
        inventory: _inventory,
        markers: const [],
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test(
        'Test 7: engine resolution does NOT handle overrides — those stay at widget layer',
        () {
      // Sanity — there is no "override" parameter on computeParadigmCell.
      // Overrides are resolved at the widget layer via ParadigmCellOverrides.
      // This test pins the engine's contract: with no rules and no markers,
      // the result is Uncovered regardless of any override state.
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: const [],
        inventory: _inventory,
        markers: const [],
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('Test 8: empty markers list preserves existing paradigm engine behavior',
        () {
      // Regression: the existing D-11 worked example from paradigm_engine_test
      // (portmanteau M.PL picks -is) must still return ParadigmFilled
      // identically when markers is []. Locks "markers default = no-op".
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
        _rule(2, '-o', '+o', const {dimGender: lvlM}),
        _rule(3, '-is', '+is', const {dimGender: lvlM, dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM, dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
        markers: const [],
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.form, equals('katis'));
    });
  });

  group('generateParadigm — D-43 binding-set cascade', () {
    test(
        'Test 9: marker binding {gender:M} cascades across both (M,SG) and (M,PL) cells',
        () {
      // D-43: a marker is declared on a binding SET (not per-cell). One
      // marker bound to {gender:M} must cause EVERY cell with gender=M to
      // resolve as ParadigmUnmarked, regardless of the number dimension.
      //
      // POS dims: gender[M,F] × number[SG,PL] → 4 cells.
      // Expected:
      //   (M,SG) → Unmarked
      //   (M,PL) → Unmarked   ← cascade proves D-43
      //   (F,SG) → Uncovered
      //   (F,PL) → Uncovered
      final dims = [
        _dim(
          id: dimGender,
          name: 'Gender',
          levels: const [
            DimensionLevel(id: lvlM, name: 'M', abbr: 'M', ordering: 0),
            DimensionLevel(id: lvlF, name: 'F', abbr: 'F', ordering: 1),
          ],
        ),
        _dim(
          id: dimNumber,
          name: 'Number',
          levels: const [
            DimensionLevel(id: lvlPL, name: 'PL', abbr: 'PL', ordering: 0),
            DimensionLevel(id: lvlSG, name: 'SG', abbr: 'SG', ordering: 1),
          ],
        ),
      ];
      final markers = [_marker(1, const {dimGender: lvlM})];

      final chart = generateParadigm(
        root: 'kata',
        dimensions: dims,
        rules: const [],
        inventory: _inventory,
        markers: markers,
      );

      final mSg = chart.cellFor(const {dimGender: lvlM, dimNumber: lvlSG});
      final mPl = chart.cellFor(const {dimGender: lvlM, dimNumber: lvlPL});
      final fSg = chart.cellFor(const {dimGender: lvlF, dimNumber: lvlSG});
      final fPl = chart.cellFor(const {dimGender: lvlF, dimNumber: lvlPL});

      expect(mSg, isA<ParadigmUnmarked>());
      expect(mPl, isA<ParadigmUnmarked>());
      expect(fSg, isA<ParadigmUncovered>());
      expect(fPl, isA<ParadigmUncovered>());
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a Drift [Dimension] row without touching the database. Mirrors
/// the pattern in paradigm_generation_test.dart.
Dimension _dim({
  required int id,
  required String name,
  required List<DimensionLevel> levels,
  int posId = 1,
}) {
  return Dimension(
    id: id,
    posId: posId,
    name: name,
    ordering: 0,
    levelsJson: encodeLevelsJson(levels),
    templateId: null,
    // 04-17 D-82: Dimensions.intrinsic required field (default false).
    intrinsic: false,
  );
}
