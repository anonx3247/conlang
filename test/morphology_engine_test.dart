import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';

// ---------------------------------------------------------------------------
// Shared test fixture
// ---------------------------------------------------------------------------

/// Simple inventory: consonants k,t,b,m,n,l,s — vowels a,e,i,o,u
/// Natural classes: 'nasal' = [m, n], 'stop' = [k, t, b]
final testInventory = PhonemeInventory(
  consonants: ['k', 't', 'b', 'm', 'n', 'l', 's'],
  vowels: ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: {
    'c': ['k', 't', 'b', 'm', 'n', 'l', 's'],
    'v': ['a', 'e', 'i', 'o', 'u'],
    'nasal': ['m', 'n'],
    'stop': ['k', 't', 'b'],
  },
);

const engine = MorphologyEngine();

/// Helper: build a single-branch rule with no condition.
MorphologicalRule simpleRule(List<MorphOperation> ops, {String source = ''}) {
  return MorphologicalRule(
    id: 0,
    name: 'test',
    branches: [MorphBranch(conditions: const [], operations: ops)],
    source: source,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Suffix
  // -------------------------------------------------------------------------
  test('SuffixOp appends affix to root', () {
    final rule = simpleRule([const SuffixOp('in')]);
    final result = engine.applyRule(rule, 'kam', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('kamin'));
  });

  // -------------------------------------------------------------------------
  // 2. Prefix
  // -------------------------------------------------------------------------
  test('PrefixOp prepends affix to root', () {
    final rule = simpleRule([const PrefixOp('un')]);
    final result = engine.applyRule(rule, 'kat', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('unkat'));
  });

  // -------------------------------------------------------------------------
  // 3. Infix
  // -------------------------------------------------------------------------
  test('InfixOp inserts affix after Nth consonant', () {
    // root 'talis': consonants are t(pos 0), l(pos 2), s(pos 4)
    // InfixOp(position:1) inserts after 1st consonant (t) -> 'tumalis'
    final rule = simpleRule([const InfixOp(affix: 'um', position: 1)]);
    final result = engine.applyRule(rule, 'talis', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('tumalis'));
  });

  // -------------------------------------------------------------------------
  // 4. Ablaut
  // -------------------------------------------------------------------------
  test('AblautOp replaces all occurrences of vowel in root', () {
    // 'katab': replace 'a' with 'e' -> 'keteb'
    final rule = simpleRule([const AblautOp(from: 'a', to: 'e')]);
    final result = engine.applyRule(rule, 'katab', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('keteb'));
  });

  // -------------------------------------------------------------------------
  // 5. Template
  // -------------------------------------------------------------------------
  test('TemplateOp applies Semitic-style consonant pattern', () {
    // root 'ktb': consonants k,t,b; pattern '1a23aa' -> 'katbaa'
    final rule = simpleRule([const TemplateOp('1a23aa')]);
    final result = engine.applyRule(rule, 'ktb', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('katbaa'));
  });

  // -------------------------------------------------------------------------
  // 6. Reduplication - full prefix
  // -------------------------------------------------------------------------
  test('RedupOp full prefix duplicates entire root as prefix', () {
    final rule = simpleRule([const RedupOp(scope: 'full', position: 'prefix')]);
    final result = engine.applyRule(rule, 'kata', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('katakata'));
  });

  // -------------------------------------------------------------------------
  // 7. Reduplication - CV prefix
  // -------------------------------------------------------------------------
  test('RedupOp CV prefix duplicates first C+V sequence as prefix', () {
    // 'kata': first CV is 'ka' -> 'kakata'
    final rule = simpleRule([const RedupOp(scope: 'CV', position: 'prefix')]);
    final result = engine.applyRule(rule, 'kata', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('kakata'));
  });

  // -------------------------------------------------------------------------
  // 8. Suppletive
  // -------------------------------------------------------------------------
  test('SuppleteOp returns the literal form regardless of root', () {
    final rule = simpleRule([const SuppleteOp('went')]);
    final result = engine.applyRule(rule, 'go', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('went'));
  });

  // -------------------------------------------------------------------------
  // 9. Branching - PatternCond literal suffix / prefix
  // -------------------------------------------------------------------------
  test('Branching with PatternCond(o_) selects correct branch', () {
    // Branch 1: ends with 'o' -> remove 'o', add 'in'
    // Branch 2 (default): add 'in'
    // 'kamo' should hit branch 1 -> -o -> 'kam' -> +in -> 'kamin'
    // 'kam' should hit branch 2 -> add 'in' -> 'kamin'
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('o_')],
          operations: const [RemoveSuffixOp('o'), SuffixOp('in')],
        ),
        MorphBranch(
          conditions: const [],
          operations: const [SuffixOp('in')],
        ),
      ],
      source: '',
    );
    final result1 = engine.applyRule(rule, 'kamo', testInventory);
    expect(result1, isA<MorphSuccess>());
    expect((result1 as MorphSuccess).form, equals('kamin'));

    final result2 = engine.applyRule(rule, 'kam', testInventory);
    expect(result2, isA<MorphSuccess>());
    expect((result2 as MorphSuccess).form, equals('kamin'));
  });

  // -------------------------------------------------------------------------
  // 10. Branching - PatternCond class (vowel-final)
  // -------------------------------------------------------------------------
  test('Branching with PatternCond(V_) selects correct branch', () {
    // Branch 1: ends with V -> suffix 'n'
    // Branch 2 (default): suffix 'an'
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('V_')],
          operations: const [SuffixOp('n')],
        ),
        MorphBranch(
          conditions: const [],
          operations: const [SuffixOp('an')],
        ),
      ],
      source: '',
    );

    // Vowel-final root 'kata' -> ends with 'a' (vowel) -> suffix 'n' -> 'katan'
    final result1 = engine.applyRule(rule, 'kata', testInventory);
    expect(result1, isA<MorphSuccess>());
    expect((result1 as MorphSuccess).form, equals('katan'));

    // Consonant-final root 'kat' -> hits default -> suffix 'an' -> 'katan'
    final result2 = engine.applyRule(rule, 'kat', testInventory);
    expect(result2, isA<MorphSuccess>());
    expect((result2 as MorphSuccess).form, equals('katan'));
  });

  // -------------------------------------------------------------------------
  // 11. Chained operations
  // -------------------------------------------------------------------------
  test('Chained operations apply in order', () {
    // [SuffixOp('a'), SuffixOp('n')] on 'kam' -> 'kama' -> 'kaman'
    final rule = simpleRule([const SuffixOp('a'), const SuffixOp('n')]);
    final result = engine.applyRule(rule, 'kam', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('kaman'));
  });

  // -------------------------------------------------------------------------
  // 12. Empty root
  // -------------------------------------------------------------------------
  test('Engine returns MorphNoMatch for empty root', () {
    final rule = simpleRule([const SuffixOp('in')]);
    final result = engine.applyRule(rule, '', testInventory);
    expect(result, isA<MorphNoMatch>());
  });

  // -------------------------------------------------------------------------
  // 13. No matching branch
  // -------------------------------------------------------------------------
  test('Engine returns MorphNoMatch when no branch condition matches', () {
    // Rule has only one branch with PatternCond('x_'); root 'kam' does not match
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('x_')],
          operations: const [SuffixOp('in')],
        ),
      ],
      source: '',
    );
    final result = engine.applyRule(rule, 'kam', testInventory);
    expect(result, isA<MorphNoMatch>());
  });

  // -------------------------------------------------------------------------
  // 14. DSL round-trip
  // -------------------------------------------------------------------------
  test('DSL round-trip: parse -> serialize -> parse gives same result', () {
    // A suffix rule with one branch
    const source = '+in';
    final parsed1 = parseMorphDsl(source);
    expect(parsed1.isValid, isTrue, reason: 'First parse should succeed: ${parsed1.error}');

    final serialized = serializeMorphRule(parsed1.rule!);
    final parsed2 = parseMorphDsl(serialized);
    expect(parsed2.isValid, isTrue, reason: 'Re-parse should succeed: ${parsed2.error}');

    // Both parses should produce equivalent rules (same branches, same ops)
    expect(parsed2.rule!.branches.length, equals(parsed1.rule!.branches.length));
    final op1 = parsed1.rule!.branches.first.operations.first;
    final op2 = parsed2.rule!.branches.first.operations.first;
    expect(op1.runtimeType, equals(op2.runtimeType));
    expect((op1 as SuffixOp).affix, equals((op2 as SuffixOp).affix));
  });

  // -------------------------------------------------------------------------
  // 15. DSL parse: multi-branch rule
  // -------------------------------------------------------------------------
  test('DSL parse: {C_} +in | {V_} +ain | {o_} -"o" +in produces 3 branches', () {
    const source = '{C_} +in | {V_} +ain | {o_} -"o" +in';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(3));
  });

  // -------------------------------------------------------------------------
  // 16. InfixOp DSL round-trip
  // -------------------------------------------------------------------------
  group('InfixOp DSL round-trip', () {
    test('InfixOp serializes to infix:um:1 and parses back losslessly', () {
      final rule = simpleRule(
        [const InfixOp(affix: 'um', position: 1)],
        source: 'infix:um:1',
      );

      // Verify serialization
      final serialized = serializeMorphRule(rule);
      expect(serialized, equals('infix:um:1'));

      // Verify parse round-trip
      final parsed = parseMorphDsl(serialized);
      expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');

      final op = parsed.rule!.branches.first.operations.first;
      expect(op, isA<InfixOp>());
      expect((op as InfixOp).affix, equals('um'));
      expect(op.position, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // 17. PatternCond: V_ matches vowel-final, not consonant-final
  // -------------------------------------------------------------------------
  test('PatternCond V_ matches vowel-final word', () {
    expect(patternConditionMatches(const PatternCond('V_'), 'taka', testInventory), isTrue);
    expect(patternConditionMatches(const PatternCond('V_'), 'tak', testInventory), isFalse);
  });

  // -------------------------------------------------------------------------
  // 18. PatternCond: _CV matches words starting with consonant+vowel
  // -------------------------------------------------------------------------
  test('PatternCond _CV matches word starting with C+V', () {
    expect(patternConditionMatches(const PatternCond('_CV'), 'taka', testInventory), isTrue);
    // 'atka' starts with vowel, not consonant -> no match
    expect(patternConditionMatches(const PatternCond('_CV'), 'atka', testInventory), isFalse);
  });

  // -------------------------------------------------------------------------
  // 19. PatternCond: [nasal]V_ matches word ending with nasal+vowel
  // -------------------------------------------------------------------------
  test('PatternCond [nasal]V_ matches word ending with nasal+vowel', () {
    // 'tana': t-a-n-a. Last two: n(nasal)+a(vowel) -> matches [nasal]V_
    expect(
      patternConditionMatches(const PatternCond('[nasal]V_'), 'tana', testInventory),
      isTrue,
    );
    // 'tanka': ends with n-k-a (consonant-final nasal sequence) -> no match for [nasal]V_
    expect(
      patternConditionMatches(const PatternCond('[nasal]V_'), 'taka', testInventory),
      isFalse,
    );
  });

  // -------------------------------------------------------------------------
  // 20. PatternCond: Vk(l)_ matches word ending with vowel+k or vowel+k+l
  // -------------------------------------------------------------------------
  test('PatternCond Vk(l)_ matches Vkl and Vk suffixes', () {
    // 'takl': t-a-k-l -> ends with a(V)+k+l -> matches Vk(l)_
    expect(patternConditionMatches(const PatternCond('Vk(l)_'), 'takl', testInventory), isTrue);
    // 'tak': t-a-k -> ends with a(V)+k -> optional l absent -> still matches Vk(l)_
    expect(patternConditionMatches(const PatternCond('Vk(l)_'), 'tak', testInventory), isTrue);
    // 'taka': ends with k+a -> V is in wrong position for Vk_ -> no match
    expect(patternConditionMatches(const PatternCond('Vk(l)_'), 'taka', testInventory), isFalse);
  });

  // -------------------------------------------------------------------------
  // 21. Multiple conditions (AND logic) per branch
  // -------------------------------------------------------------------------
  test('Multiple conditions on a branch require all to match (AND)', () {
    // Branch: conditions = [PatternCond('_C'), PatternCond('V_')]
    // Must start with C AND end with V.
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('_C'), PatternCond('V_')],
          operations: const [SuffixOp('x')],
        ),
        MorphBranch(
          conditions: const [],
          operations: const [SuffixOp('y')],
        ),
      ],
      source: '',
    );

    // 'kata': starts with k(C) AND ends with a(V) -> branch 1 -> 'katax'
    final r1 = engine.applyRule(rule, 'kata', testInventory);
    expect(r1, isA<MorphSuccess>());
    expect((r1 as MorphSuccess).form, equals('katax'));

    // 'akat': starts with a(V) not C -> falls to default -> 'akaty'
    final r2 = engine.applyRule(rule, 'akat', testInventory);
    expect(r2, isA<MorphSuccess>());
    expect((r2 as MorphSuccess).form, equals('akaty'));

    // 'katan': starts with k(C) but ends with n(C) -> falls to default -> 'katany'
    final r3 = engine.applyRule(rule, 'katan', testInventory);
    expect(r3, isA<MorphSuccess>());
    expect((r3 as MorphSuccess).form, equals('katany'));
  });

  // -------------------------------------------------------------------------
  // 22. DSL round-trip for PatternCond branches
  // -------------------------------------------------------------------------
  test('DSL round-trip: PatternCond branches serialize and re-parse correctly', () {
    const source = '{V_} +n | _ +an';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(2));

    final branch0 = parsed.rule!.branches[0];
    expect(branch0.conditions.length, equals(1));
    expect((branch0.conditions[0] as PatternCond).pattern, equals('V_'));

    final branch1 = parsed.rule!.branches[1];
    expect(branch1.conditions.isEmpty, isTrue);

    // Serialize and re-parse
    final serialized = serializeMorphRule(parsed.rule!);
    final reparsed = parseMorphDsl(serialized);
    expect(reparsed.isValid, isTrue);
    expect(reparsed.rule!.branches.length, equals(2));
  });

  // -------------------------------------------------------------------------
  // 23. Migration: old-style DSL syntax loads via backward-compat parser
  // -------------------------------------------------------------------------
  test('Migration: old [C_] ends-with-class syntax parses to PatternCond', () {
    // Old-style: [C_] ends-with-class -> now PatternCond('[C]_')
    const source = '[C_] +in | _ +an';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(2));
    final cond = parsed.rule!.branches[0].conditions.first;
    expect(cond, isA<PatternCond>());
    expect((cond as PatternCond).pattern, equals('[C]_'));
  });

  test('Migration: old "lit"_ ends-with-literal syntax parses to PatternCond', () {
    const source = '"o"_ +in | _ +an';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    final cond = parsed.rule!.branches[0].conditions.first;
    expect(cond, isA<PatternCond>());
    expect((cond as PatternCond).pattern, equals('o_'));
  });
}
