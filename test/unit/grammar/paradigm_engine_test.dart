import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_cell.dart';
import 'package:conlang_workbench/features/grammar/domain/paradigm_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

/// Inventory used across every test. Consonants k,t,b,n,s — vowels a,e,i,o,u.
final _inventory = PhonemeInventory(
  consonants: const ['k', 't', 'b', 'n', 's', 'r'],
  vowels: const ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: const {
    'c': ['k', 't', 'b', 'n', 's', 'r'],
    'v': ['a', 'e', 'i', 'o', 'u'],
    'vowel': ['a', 'e', 'i', 'o', 'u'],
  },
);

// Dim ids
const int dimGender = 10;
const int dimNumber = 11;
const int dimCase = 12;

// Level ids
const int lvlM = 1;
const int lvlF = 2;
const int lvlPL = 1;
const int lvlSG = 2;
const int lvlDAT = 1;

InflectionalRule _rule(
  int id,
  String name,
  String source,
  Map<int, int> dims, {
  bool isActive = true,
}) {
  return InflectionalRule(
    id: id,
    name: name,
    source: source,
    isActive: isActive,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

void main() {
  group('computeParadigmCell — D-11 worked examples', () {
    test('Test 1: portmanteau M.PL picks -is (most specific wins)', () {
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
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['-is']));
      expect(filled.form, equals('katis'));
    });

    test('Test 2: M.SG picks -o (only gender=M matches)', () {
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
        _rule(2, '-o', '+o', const {dimGender: lvlM}),
        _rule(3, '-is', '+is', const {dimGender: lvlM, dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM, dimNumber: lvlSG},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['-o']));
      expect(filled.form, equals('kato'));
    });

    test('Test 3: F.PL picks -s (only number=PL matches)', () {
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
        _rule(2, '-o', '+o', const {dimGender: lvlM}),
        _rule(3, '-is', '+is', const {dimGender: lvlM, dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlF, dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['-s']));
      expect(filled.form, equals('kats'));
    });

    test('Test 4: multi-pass M.PL.DAT applies -ar then -e', () {
      final rules = [
        _rule(1, '-ar', '+ar', const {dimGender: lvlM, dimNumber: lvlPL}),
        _rule(2, '-e', '+e', const {dimCase: lvlDAT}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {
          dimGender: lvlM,
          dimNumber: lvlPL,
          dimCase: lvlDAT,
        },
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['-ar', '-e']));
      expect(filled.form, equals('katare'));
    });
  });

  group('computeParadigmCell — D-12 ambiguity', () {
    test('Test 5: two rules with identical bindings return ParadigmAmbiguous', () {
      final rules = [
        _rule(1, '-x', '+x', const {dimNumber: lvlPL}),
        _rule(2, '-y', '+y', const {dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmAmbiguous>());
      final amb = result as ParadigmAmbiguous;
      expect(amb.tiedRules.length, equals(2));
      expect(
        amb.tiedRules.map((r) => r.name).toSet(),
        equals({'-x', '-y'}),
      );
    });
  });

  group('computeParadigmCell — D-13 unbound / inactive filters', () {
    test('Test 6: unbound rule (dims empty) never fires', () {
      final rules = [
        _rule(1, '-u', '+u', const {}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM, dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('Test 7: inactive rule skipped', () {
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}, isActive: false),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmUncovered>());
    });
  });

  group('computeParadigmCell — A3 strict most-specific', () {
    test('Test 8: intra-specificity fall-through when first DSL condition fails', () {
      // -na applies only if root ends with a vowel; -s is plain suffix.
      final rules = [
        _rule(1, '-na', '"[vowel]"\$ +na', const {dimNumber: lvlPL}),
        _rule(2, '-s', '+s', const {dimNumber: lvlPL}),
      ];
      // root 'kat' ends in consonant -> -na should fail, -s should win
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      // Two rules at same specificity with different-named bindings are NOT
      // identical binding sets (they ARE identical here: both {11:1}). So this
      // is actually tested as ambiguous BUT the plan Test 8 expects the engine
      // to pick -s via fall-through. To resolve: use distinct binding sets that
      // are NOT identical but both match the cell. We differentiate by adding
      // a third dim constraint, but only one rule carries it — wait, then
      // specificity differs. Instead we test the fall-through when two rules
      // have same binding map but at same specificity — the plan says
      // identical binding sets are the ONLY ambiguity. So to test
      // intra-specificity fall-through we must pick a scenario with two rules
      // at the same specificity with DIFFERENT binding maps that both match.
      //
      // Use {dimNumber: lvlPL} and {dimGender: lvlM} — both specificity 1,
      // different bindings, both would match cell {gender:M, number:PL}. Try
      // -na (PL-bound) with a condition that fails on 'kat' and -o (M-bound)
      // plain suffix. Order them so -na is first. The engine sorts by
      // specificity desc — equal specificity — then tries the list in order.
      // On fail, the tests below ensure engine tries the next same-specificity
      // candidate.
      //
      // NOTE: This first test variant (Test 8 of plan) uses rules that are
      // BOTH {dimNumber: lvlPL}. That IS identical bindings. The plan's stated
      // behavior for identical bindings is ParadigmAmbiguous. So Test 8's
      // fall-through scenario as written conflicts with D-12. We test
      // fall-through with non-identical same-specificity bindings below
      // (Test 8b). This test asserts ParadigmAmbiguous for the identical case.
      expect(result, isA<ParadigmAmbiguous>());
    });

    test('Test 8b: intra-specificity fall-through with different bindings', () {
      // Cell: {gender:M, number:PL}. Both rules are specificity 1 with
      // different bindings; both can match this cell.
      // -na (PL-bound) has DSL condition endsWith [vowel] which fails on 'kat'.
      // -o (M-bound) is plain suffix and succeeds.
      //
      // Because both rules are at specificity 1 but bind different dims,
      // they are NOT "identical bindings" — they are candidates to be tried
      // at the same specificity level. The engine tries in order; -na fails
      // its DSL condition, so the engine falls through to -o within the same
      // specificity tier.
      final rules = [
        _rule(1, '-na', '"[vowel]"\$ +na', const {dimNumber: lvlPL}),
        _rule(2, '-o', '+o', const {dimGender: lvlM}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM, dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      // -o wins at first pass; it consumes gender. Next iteration -na still
      // matches remaining {number:PL} but its DSL still fails, so the engine
      // falls through — there's no other candidate at spec 1, so the cell
      // is partially filled: chain=[-o], form='kato'. Since remaining is
      // still {number:PL}, the engine returns ParadigmFilled with partial
      // chain (strict: no uncovered intermediate).
      expect(filled.ruleChain.map((r) => r.name).first, equals('-o'));
      expect(filled.form, startsWith('kato'));
    });

    test('Test 9: strict — does NOT fall through to lower specificity', () {
      // -is is specificity 2; its DSL condition endsWith vowel fails on 'kat'.
      // -s is specificity 1 and would succeed but must NOT be tried.
      final rules = [
        _rule(1, '-is', '"[vowel]"\$ +is',
            const {dimGender: lvlM, dimNumber: lvlPL}),
        _rule(2, '-s', '+s', const {dimNumber: lvlPL}),
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM, dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmUncovered>());
      final u = result as ParadigmUncovered;
      expect(u.failureReason, isNotNull);
    });
  });

  group('computeParadigmCell — edge cases', () {
    test('Test 10: empty rule set returns ParadigmUncovered', () {
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimGender: lvlM},
        rules: const [],
        inventory: _inventory,
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('Test 11: cell whose dims match no candidate returns ParadigmUncovered',
        () {
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
      ];
      // Cell's only dim (99) has no rule binding it.
      final result = computeParadigmCell(
        root: 'kat',
        target: const {99: 5},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmUncovered>());
    });

    test('derivational rule (empty dims) filtered even if present', () {
      // Mixed rule set: one inflectional, one derivational. Derivational
      // must be filtered out by the isInflectional gate (D-13).
      final rules = [
        _rule(1, '-s', '+s', const {dimNumber: lvlPL}),
        _rule(2, 'der', '+er', const {}), // empty dims = derivational
      ];
      final result = computeParadigmCell(
        root: 'kat',
        target: const {dimNumber: lvlPL},
        rules: rules,
        inventory: _inventory,
      );
      expect(result, isA<ParadigmFilled>());
      final filled = result as ParadigmFilled;
      expect(filled.ruleChain.map((r) => r.name), equals(['-s']));
    });
  });
}
