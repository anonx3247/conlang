import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/morphology/domain/morphology_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';

// ---------------------------------------------------------------------------
// Shared test fixture
// ---------------------------------------------------------------------------

/// Simple inventory: consonants k,t,b,m,n,l,s — vowels a,e,i,o,u
final testInventory = PhonemeInventory(
  consonants: ['k', 't', 'b', 'm', 'n', 'l', 's'],
  vowels: ['a', 'e', 'i', 'o', 'u'],
  naturalClasses: {
    'c': ['k', 't', 'b', 'm', 'n', 'l', 's'],
    'v': ['a', 'e', 'i', 'o', 'u'],
  },
);

const engine = MorphologyEngine();

/// Helper: build a single-branch rule with no condition.
MorphologicalRule simpleRule(List<MorphOperation> ops, {String source = ''}) {
  return MorphologicalRule(
    id: 0,
    name: 'test',
    branches: [MorphBranch(condition: null, operations: ops)],
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
  // 9. Branching - literal condition
  // -------------------------------------------------------------------------
  test('Branching with EndsWithLiteralCond selects correct branch', () {
    // Branch 1: ends with 'o' -> remove 'o', add 'in'
    // Branch 2 (default): add 'in'
    // 'kamo' should hit branch 1 -> remove 'o' -> 'kam' -> add 'in' -> 'kamin'
    // 'kam' should hit branch 2 -> add 'in' -> 'kamin'
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          condition: const EndsWithLiteralCond('o'),
          // Remove 'o' by using SuppleteOp-style won't work; we need a trim op.
          // Instead: use a suffix of '' is wrong. Use the engine to strip 'o'
          // then add 'in'. We model "remove trailing o" as: ablaut from the
          // full root. Actually we need a RemoveSuffixOp or the test should
          // reflect realistic expectations. Per plan: "remove 'o' then suffix 'in'"
          // The plan doesn't define RemoveSuffixOp explicitly. We'll use a
          // combination: SuppleteOp that computes from root minus last char is
          // also not right. Let's model this as the engine trims the condition
          // suffix and applies suffix 'in'.
          // Per plan test 9: 'kamo' -> 'kamin'. This means: strip 'o', add 'in'.
          // We need a way to express this. In the plan the op is "-o +in" in DSL.
          // For the data model test we'll use two ops: first SuffixOp isn't right.
          // The plan says "remove 'o' then suffix 'in'" — we need a strip op.
          // Since the plan didn't spec a StripSuffixOp in the sealed hierarchy
          // but the test expects this behavior, we'll model it as a workaround:
          // The engine, when it sees EndsWithLiteralCond('o') match, can
          // automatically strip the matched suffix before applying ops.
          // That would make branching conditions context-aware in a specific way.
          // OR: we add a RemoveSuffixOp to the sealed class. The plan says
          // "-o" in DSL format which would be a RemoveSuffixOp('o').
          // The plan's must_haves seal class mentions 7 ops: PrefixOp, SuffixOp,
          // InfixOp, AblautOp, TemplateOp, RedupOp, SuppleteOp. No RemoveSuffixOp.
          // Re-read plan task 9: [remove 'o' then suffix 'in'] with 'kamo'->'kamin'
          // and 'kam'->'kamin'. Both produce 'kamin'. This works if:
          // branch1(ends-with-o): strip last char + suffix 'in' (uses AblautOp? No)
          // OR the engine strips the condition literal before applying ops.
          // Simplest model for the test: AblautOp(from:'o', to:'') + SuffixOp('in')
          // But AblautOp replaces ALL 'o's, not just last.
          // The cleaner model: use the condition literal as an implicit strip.
          // Let's test with the explicit data model approach most aligned with
          // the plan: use a SuffixOp('in') for both branches (both yield 'kamin')
          // and use EndsWithLiteralCond to select. For the 'kamo' case, we strip
          // 'o' and add 'in' = 'kamin'. We'll model stripping as AblautOp but
          // since 'a' is also 'a' in 'kamo', it's only the terminal 'o'.
          // Final decision: model the strip as the engine feature where a matched
          // EndsWithLiteral condition causes the suffix to be stripped from the
          // working form before ops are applied. This is tested here.
          operations: [const SuffixOp('in')],
        ),
        MorphBranch(
          condition: null,
          operations: [const SuffixOp('in')],
        ),
      ],
      source: '',
    );
    final result1 = engine.applyRule(rule, 'kamo', testInventory);
    expect(result1, isA<MorphSuccess>());
    // 'kamo' ends with 'o': strip 'o' -> 'kam', then suffix 'in' -> 'kamin'
    expect((result1 as MorphSuccess).form, equals('kamin'));

    final result2 = engine.applyRule(rule, 'kam', testInventory);
    expect(result2, isA<MorphSuccess>());
    // 'kam' hits default: suffix 'in' -> 'kamin'
    expect((result2 as MorphSuccess).form, equals('kamin'));
  });

  // -------------------------------------------------------------------------
  // 10. Branching - class condition
  // -------------------------------------------------------------------------
  test('Branching with EndsWithClassCond selects correct branch', () {
    // Branch 1: ends with V -> suffix 'n'
    // Branch 2 (default): suffix 'an'
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          condition: const EndsWithClassCond('V'),
          operations: [const SuffixOp('n')],
        ),
        MorphBranch(
          condition: null,
          operations: [const SuffixOp('an')],
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
    // Rule has only one branch with EndsWithLiteralCond('x'); root 'kam' does not match
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          condition: const EndsWithLiteralCond('x'),
          operations: [const SuffixOp('in')],
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
  test('DSL parse: [C_] +in | [V_] +ain | "o" -o +in produces 3 branches', () {
    const source = '[C_] +in | [V_] +ain | "o" -o +in';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(3));
  });
}
