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
    final rule = simpleRule([const InfixOp(affix: 'um', position: 1)]);
    final result = engine.applyRule(rule, 'talis', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('tumalis'));
  });

  // -------------------------------------------------------------------------
  // 4. Ablaut (replace all, default)
  // -------------------------------------------------------------------------
  test('AblautOp replaces all occurrences of vowel in root', () {
    final rule = simpleRule([const AblautOp(from: 'a', to: 'e')]);
    final result = engine.applyRule(rule, 'katab', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('keteb'));
  });

  // -------------------------------------------------------------------------
  // 4b. Ablaut with count and direction
  // -------------------------------------------------------------------------
  test('AblautOp count=1 fromStart replaces first occurrence only', () {
    final rule = simpleRule([
      const AblautOp(from: 'a', to: 'e', count: 1, direction: AblautDirection.fromStart),
    ]);
    final result = engine.applyRule(rule, 'banana', testInventory);
    expect(result, isA<MorphSuccess>());
    // banana: a at positions 1, 3, 5 — replace first -> benana
    expect((result as MorphSuccess).form, equals('benana'));
  });

  test('AblautOp count=1 fromEnd replaces last occurrence only', () {
    final rule = simpleRule([
      const AblautOp(from: 'a', to: 'e', count: 1, direction: AblautDirection.fromEnd),
    ]);
    final result = engine.applyRule(rule, 'banana', testInventory);
    expect(result, isA<MorphSuccess>());
    // banana: a at positions 1, 3, 5 — replace last -> banane
    expect((result as MorphSuccess).form, equals('banane'));
  });

  test('AblautOp count=2 fromEnd replaces last two occurrences', () {
    final rule = simpleRule([
      const AblautOp(from: 'a', to: 'e', count: 2, direction: AblautDirection.fromEnd),
    ]);
    final result = engine.applyRule(rule, 'banana', testInventory);
    expect(result, isA<MorphSuccess>());
    // banana: a at 1, 3, 5 — replace last two (3, 5) -> banene
    expect((result as MorphSuccess).form, equals('banene'));
  });

  // Regression for UAT repro: class `V` must resolve to user vowels, and
  // fromEnd+count=1 must replace only the last vowel. Before the fix,
  // applyAblaut compared tokens to the literal string "V" and never matched.
  test('AblautOp from="V" fromEnd count=1 replaces only the last vowel', () {
    final rule = simpleRule([
      const AblautOp(
        from: 'V',
        to: 'o',
        count: 1,
        direction: AblautDirection.fromEnd,
      ),
    ]);
    final result = engine.applyRule(rule, 'sana', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('sano'));
  });

  test('AblautOp from="V" replaces all vowels when count is null', () {
    final rule = simpleRule([const AblautOp(from: 'V', to: 'o')]);
    final result = engine.applyRule(rule, 'sana', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('sono'));
  });

  test('AblautOp from="C" fromStart count=1 replaces only the first consonant', () {
    final rule = simpleRule([
      const AblautOp(
        from: 'C',
        to: 't',
        count: 1,
        direction: AblautDirection.fromStart,
      ),
    ]);
    final result = engine.applyRule(rule, 'kabel', testInventory);
    expect(result, isA<MorphSuccess>());
    // kabel: C at 0 (k), 2 (b), 4 (l) — replace first -> tabel
    expect((result as MorphSuccess).form, equals('tabel'));
  });

  test('AblautOp with named natural class [nasal] resolves via inventory', () {
    final rule = simpleRule([const AblautOp(from: '[nasal]', to: 'l')]);
    final result = engine.applyRule(rule, 'mana', testInventory);
    expect(result, isA<MorphSuccess>());
    // nasal = {m, n} -> both replaced
    expect((result as MorphSuccess).form, equals('lala'));
  });

  test('AblautOp with literal phoneme still matches by exact equality', () {
    // Literal `a` (not a class) must behave exactly as before.
    final rule = simpleRule([const AblautOp(from: 'a', to: 'e', count: 1)]);
    final result = engine.applyRule(rule, 'banana', testInventory);
    expect(result, isA<MorphSuccess>());
    expect((result as MorphSuccess).form, equals('benana'));
  });

  // -------------------------------------------------------------------------
  // 5. Template
  // -------------------------------------------------------------------------
  test('TemplateOp applies Semitic-style consonant pattern', () {
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
  // 9. Branching - PatternCond endsWith
  // -------------------------------------------------------------------------
  test('Branching with PatternCond endsWith selects correct branch', () {
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('o', position: CondPosition.endsWith)],
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
  // 10. Branching - PatternCond endsWith class (vowel-final)
  // -------------------------------------------------------------------------
  test('Branching with PatternCond endsWith V selects correct branch', () {
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('V', position: CondPosition.endsWith)],
          operations: const [SuffixOp('n')],
        ),
        MorphBranch(
          conditions: const [],
          operations: const [SuffixOp('an')],
        ),
      ],
      source: '',
    );

    final result1 = engine.applyRule(rule, 'kata', testInventory);
    expect(result1, isA<MorphSuccess>());
    expect((result1 as MorphSuccess).form, equals('katan'));

    final result2 = engine.applyRule(rule, 'kat', testInventory);
    expect(result2, isA<MorphSuccess>());
    expect((result2 as MorphSuccess).form, equals('katan'));
  });

  // -------------------------------------------------------------------------
  // 11. Chained operations
  // -------------------------------------------------------------------------
  test('Chained operations apply in order', () {
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
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [PatternCond('x', position: CondPosition.endsWith)],
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
    const source = '+in';
    final parsed1 = parseMorphDsl(source);
    expect(parsed1.isValid, isTrue, reason: 'First parse should succeed: ${parsed1.error}');

    final serialized = serializeMorphRule(parsed1.rule!);
    final parsed2 = parseMorphDsl(serialized);
    expect(parsed2.isValid, isTrue, reason: 'Re-parse should succeed: ${parsed2.error}');

    expect(parsed2.rule!.branches.length, equals(parsed1.rule!.branches.length));
    final op1 = parsed1.rule!.branches.first.operations.first;
    final op2 = parsed2.rule!.branches.first.operations.first;
    expect(op1.runtimeType, equals(op2.runtimeType));
    expect((op1 as SuffixOp).affix, equals((op2 as SuffixOp).affix));
  });

  // -------------------------------------------------------------------------
  // 15. DSL parse: multi-branch rule with new condition format
  // -------------------------------------------------------------------------
  test('DSL parse: new condition format produces correct branches', () {
    const source = r'^"C" +in | "V"$ +ain | "o"$ -"o" +in';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(3));

    final cond0 = parsed.rule!.branches[0].conditions.first as PatternCond;
    expect(cond0.pattern, equals('C'));
    expect(cond0.position, equals(CondPosition.startsWith));

    final cond1 = parsed.rule!.branches[1].conditions.first as PatternCond;
    expect(cond1.pattern, equals('V'));
    expect(cond1.position, equals(CondPosition.endsWith));
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

      final serialized = serializeMorphRule(rule);
      expect(serialized, equals('infix:um:1'));

      final parsed = parseMorphDsl(serialized);
      expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');

      final op = parsed.rule!.branches.first.operations.first;
      expect(op, isA<InfixOp>());
      expect((op as InfixOp).affix, equals('um'));
      expect(op.position, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // 17. PatternCond endsWith V matches vowel-final word
  // -------------------------------------------------------------------------
  test('PatternCond endsWith V matches vowel-final word', () {
    expect(
      patternConditionMatches(
        const PatternCond('V', position: CondPosition.endsWith),
        'taka',
        testInventory,
      ),
      isTrue,
    );
    expect(
      patternConditionMatches(
        const PatternCond('V', position: CondPosition.endsWith),
        'tak',
        testInventory,
      ),
      isFalse,
    );
  });

  // -------------------------------------------------------------------------
  // 18. PatternCond startsWith CV
  // -------------------------------------------------------------------------
  test('PatternCond startsWith CV matches word starting with C+V', () {
    expect(
      patternConditionMatches(
        const PatternCond('CV', position: CondPosition.startsWith),
        'taka',
        testInventory,
      ),
      isTrue,
    );
    expect(
      patternConditionMatches(
        const PatternCond('CV', position: CondPosition.startsWith),
        'atka',
        testInventory,
      ),
      isFalse,
    );
  });

  // -------------------------------------------------------------------------
  // 19. PatternCond endsWith [nasal]V
  // -------------------------------------------------------------------------
  test('PatternCond endsWith [nasal]V matches word ending with nasal+vowel', () {
    expect(
      patternConditionMatches(
        const PatternCond('[nasal]V', position: CondPosition.endsWith),
        'tana',
        testInventory,
      ),
      isTrue,
    );
    expect(
      patternConditionMatches(
        const PatternCond('[nasal]V', position: CondPosition.endsWith),
        'taka',
        testInventory,
      ),
      isFalse,
    );
  });

  // -------------------------------------------------------------------------
  // 20. PatternCond endsWith Vk(l)
  // -------------------------------------------------------------------------
  test('PatternCond endsWith Vk(l) matches Vkl and Vk suffixes', () {
    expect(
      patternConditionMatches(
        const PatternCond('Vk(l)', position: CondPosition.endsWith),
        'takl',
        testInventory,
      ),
      isTrue,
    );
    expect(
      patternConditionMatches(
        const PatternCond('Vk(l)', position: CondPosition.endsWith),
        'tak',
        testInventory,
      ),
      isTrue,
    );
    expect(
      patternConditionMatches(
        const PatternCond('Vk(l)', position: CondPosition.endsWith),
        'taka',
        testInventory,
      ),
      isFalse,
    );
  });

  // -------------------------------------------------------------------------
  // 21. Multiple conditions (AND logic) per branch
  // -------------------------------------------------------------------------
  test('Multiple conditions on a branch require all to match (AND)', () {
    final rule = MorphologicalRule(
      id: 0,
      name: 'test',
      branches: [
        MorphBranch(
          conditions: const [
            PatternCond('C', position: CondPosition.startsWith),
            PatternCond('V', position: CondPosition.endsWith),
          ],
          operations: const [SuffixOp('x')],
        ),
        MorphBranch(
          conditions: const [],
          operations: const [SuffixOp('y')],
        ),
      ],
      source: '',
    );

    final r1 = engine.applyRule(rule, 'kata', testInventory);
    expect(r1, isA<MorphSuccess>());
    expect((r1 as MorphSuccess).form, equals('katax'));

    final r2 = engine.applyRule(rule, 'akat', testInventory);
    expect(r2, isA<MorphSuccess>());
    expect((r2 as MorphSuccess).form, equals('akaty'));

    final r3 = engine.applyRule(rule, 'katan', testInventory);
    expect(r3, isA<MorphSuccess>());
    expect((r3 as MorphSuccess).form, equals('katany'));
  });

  // -------------------------------------------------------------------------
  // 22. DSL round-trip for new condition format
  // -------------------------------------------------------------------------
  test('DSL round-trip: new condition format serialize and re-parse correctly', () {
    const source = r'"V"$ +n | _ +an';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(2));

    final branch0 = parsed.rule!.branches[0];
    expect(branch0.conditions.length, equals(1));
    final cond = branch0.conditions[0] as PatternCond;
    expect(cond.pattern, equals('V'));
    expect(cond.position, equals(CondPosition.endsWith));

    final branch1 = parsed.rule!.branches[1];
    expect(branch1.conditions.isEmpty, isTrue);

    final serialized = serializeMorphRule(parsed.rule!);
    final reparsed = parseMorphDsl(serialized);
    expect(reparsed.isValid, isTrue);
    expect(reparsed.rule!.branches.length, equals(2));
  });

  // -------------------------------------------------------------------------
  // 23. Migration: old-style DSL syntax loads via backward-compat parser
  // -------------------------------------------------------------------------
  test('Migration: old {pattern_} syntax parses to PatternCond with endsWith', () {
    const source = '{C_} +in | _ +an';
    final parsed = parseMorphDsl(source);
    // Old {C_} should migrate: strip trailing _, C = pattern, endsWith
    // But {C_} hits the legacy braces parser which does _migratePatternAnchors('C_')
    // C_ -> hasEnd=true -> PatternCond('C', position: endsWith)
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    expect(parsed.rule!.branches.length, equals(2));
    final cond = parsed.rule!.branches[0].conditions.first as PatternCond;
    expect(cond.pattern, equals('C'));
    expect(cond.position, equals(CondPosition.endsWith));
  });

  test('Migration: old {V_} syntax parses to endsWith V', () {
    const source = '{V_} +n';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    final cond = parsed.rule!.branches[0].conditions.first as PatternCond;
    expect(cond.pattern, equals('V'));
    expect(cond.position, equals(CondPosition.endsWith));
  });

  test('Migration: old {_CV} syntax parses to startsWith CV', () {
    const source = '{_CV} +n';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    final cond = parsed.rule!.branches[0].conditions.first as PatternCond;
    expect(cond.pattern, equals('CV'));
    expect(cond.position, equals(CondPosition.startsWith));
  });

  // -------------------------------------------------------------------------
  // 24. Ablaut DSL round-trip with direction/count flags
  // -------------------------------------------------------------------------
  test('Ablaut DSL round-trip with direction and count flags', () {
    // /a/e/e1 = from end, replace 1
    const source = '/a/e/e1';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    final op = parsed.rule!.branches.first.operations.first as AblautOp;
    expect(op.from, equals('a'));
    expect(op.to, equals('e'));
    expect(op.direction, equals(AblautDirection.fromEnd));
    expect(op.count, equals(1));

    // Serialize and re-parse
    final serialized = serializeMorphRule(parsed.rule!);
    expect(serialized, equals('/a/e/e1'));
    final reparsed = parseMorphDsl(serialized);
    expect(reparsed.isValid, isTrue);
    final op2 = reparsed.rule!.branches.first.operations.first as AblautOp;
    expect(op2.direction, equals(AblautDirection.fromEnd));
    expect(op2.count, equals(1));
  });

  test('Ablaut DSL backward compat: /a/e/ has no flags = all from start', () {
    const source = '/a/e/';
    final parsed = parseMorphDsl(source);
    expect(parsed.isValid, isTrue, reason: 'Parse should succeed: ${parsed.error}');
    final op = parsed.rule!.branches.first.operations.first as AblautOp;
    expect(op.from, equals('a'));
    expect(op.to, equals('e'));
    expect(op.direction, equals(AblautDirection.fromStart));
    expect(op.count, isNull);

    // Serialize should produce the short form
    final serialized = serializeMorphRule(parsed.rule!);
    expect(serialized, equals('/a/e/'));
  });

  // -------------------------------------------------------------------------
  // 25. PatternCond contains matches anywhere
  // -------------------------------------------------------------------------
  test('PatternCond contains [stop]Vk(l) matches user examples', () {
    // pakmy: p-a-k-m-y — [stop] matches 'k'? No, 'p' is not in stop class.
    // Let's use the test inventory where stop = [k, t, b]
    // pakmy with our inventory: p is not a known phoneme, tokenized as 'p'
    // Use 'takmu' instead: t(stop) a(V) k -> [stop]Vk matches at start
    expect(
      patternConditionMatches(
        const PatternCond('[stop]Vk', position: CondPosition.startsWith),
        'takmu',
        testInventory,
      ),
      isTrue,
    );
    // mipoklu: contains pokl which has [stop](no, p not stop)
    // Use 'mitaklu': contains tak -> [stop]Vk at position 2
    expect(
      patternConditionMatches(
        const PatternCond('[stop]Vk', position: CondPosition.contains),
        'mitaklu',
        testInventory,
      ),
      isTrue,
    );
    // mitaklu with startsWith: starts with 'm' which is not [stop]
    expect(
      patternConditionMatches(
        const PatternCond('[stop]Vk', position: CondPosition.startsWith),
        'mitaklu',
        testInventory,
      ),
      isFalse,
    );
  });
}
