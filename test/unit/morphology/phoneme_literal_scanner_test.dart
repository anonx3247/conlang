// Plan 04-16 Task 3 — unit tests for PhonemeLiteralScanner (D-81 / G-69).
//
// Covers every MorphOperation subclass + PatternCond class-ref skip +
// digraph longest-match + template digit-slot skip + defensive failure
// handling. See 04-16-PLAN.md <behavior> for the 20 test specifications.

import 'package:conlang_workbench/features/morphology/domain/morphology_dsl.dart';
import 'package:conlang_workbench/features/morphology/domain/phoneme_literal_scanner.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper: construct a PhonemeInventory tersely.
  PhonemeInventory inv({
    List<String> consonants = const [],
    List<String> vowels = const [],
    Map<String, List<String>> naturalClasses = const {},
  }) =>
      PhonemeInventory(
        consonants: consonants,
        vowels: vowels,
        naturalClasses: naturalClasses,
      );

  // Helper: wrap a single-branch rule with the given ops + conditions.
  ParsedMorphRule wrap({
    List<MorphCondition> conditions = const [],
    required List<MorphOperation> ops,
  }) {
    final rule = MorphologicalRule(
      id: 0,
      name: '',
      source: '',
      branches: [
        MorphBranch(conditions: conditions, operations: ops),
      ],
    );
    return ParsedMorphRule.success(source: '', rule: rule);
  }

  const scanner = PhonemeLiteralScanner();

  group('PhonemeLiteralScanner — D-81 / G-69', () {
    // -------------------------------------------------------------------
    // Tests 1-9: MorphOperation coverage
    // -------------------------------------------------------------------

    test('Test 1 — SuffixOp with in-inventory affix returns no violations',
        () {
      final inventory = inv(consonants: ['n', 't'], vowels: ['i', 'a']);
      final parsed = wrap(ops: const [SuffixOp('in')]);
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test(
        'Test 2 — SuffixOp with out-of-inventory affix returns one violation '
        '(the G-68 reproducer)', () {
      final inventory = inv(consonants: ['n', 't'], vowels: ['i', 'a']);
      final parsed = wrap(ops: const [SuffixOp('ci')]);
      final violations = scanner.scan(parsed, inventory);
      expect(violations, [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'c',
        ),
      ]);
    });

    test(
        'Test 3 — PrefixOp with inventory digraph wins longest-match over '
        'single-char decomposition', () {
      // Inventory contains the digraph 'tʃ' — typing 'tʃ' must be
      // recognized as a single phoneme, NOT as 't' + 'ʃ' (either of
      // which might be missing).
      final inventory = inv(consonants: ['tʃ'], vowels: ['a']);
      final parsed = wrap(ops: const [PrefixOp('tʃa')]);
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test('Test 4 — AblautOp flags unknown "from" field', () {
      final inventory = inv(consonants: const [], vowels: ['a', 'e']);
      // from='a', to='e' — both in inventory, no violations.
      final ok = wrap(ops: const [AblautOp(from: 'a', to: 'e')]);
      expect(scanner.scan(ok, inventory), isEmpty);
      // from='q' — q is not in inventory.
      final bad = wrap(ops: const [AblautOp(from: 'q', to: 'e')]);
      expect(scanner.scan(bad, inventory), [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'q',
        ),
      ]);
    });

    test('Test 5 — InfixOp literal affix is scanned', () {
      final inventory = inv(consonants: ['n'], vowels: ['a']);
      // position=1 is an int — skipped; only the affix string is scanned.
      final ok = wrap(ops: const [InfixOp(affix: 'an', position: 1)]);
      expect(scanner.scan(ok, inventory), isEmpty);
      final bad = wrap(ops: const [InfixOp(affix: 'xn', position: 1)]);
      expect(scanner.scan(bad, inventory), [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'x',
        ),
      ]);
    });

    test('Test 6 — RemoveSuffixOp literal suffix is scanned', () {
      final inventory = inv(consonants: ['s', 't'], vowels: ['o']);
      final ok = wrap(ops: const [RemoveSuffixOp('sto')]);
      expect(scanner.scan(ok, inventory), isEmpty);
      final bad = wrap(ops: const [RemoveSuffixOp('xto')]);
      expect(scanner.scan(bad, inventory), [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'x',
        ),
      ]);
    });

    test(
        'Test 7 — TemplateOp skips digits 1-9 as consonant slots; '
        'literal chars are scanned', () {
      // Inventory: consonants [], vowels [a]. Template '1a23aa':
      //   digits 1,2,3 = consonant slots (skipped)
      //   'a' chars = in-inventory vowel -> no violations.
      final inventory = inv(vowels: ['a']);
      final ok = wrap(ops: const [TemplateOp('1a23aa')]);
      expect(scanner.scan(ok, inventory), isEmpty);
      // Substituting 'x' for 'a' — 'x' is not in inventory.
      final bad = wrap(ops: const [TemplateOp('1x23xx')]);
      final badViolations = scanner.scan(bad, inventory);
      // Three 'x' characters at offsets 1, 4, 5 (digits at 0, 2, 3).
      expect(badViolations.length, 3);
      expect(badViolations.every((v) => v.char == 'x'), isTrue);
      expect(badViolations.map((v) => v.literalOffset).toList(), [1, 4, 5]);
    });

    test('Test 8 — SuppleteOp literal form is scanned', () {
      final inventory = inv(consonants: ['w', 'n', 't'], vowels: ['e']);
      final ok = wrap(ops: const [SuppleteOp('went')]);
      expect(scanner.scan(ok, inventory), isEmpty);
      final bad = wrap(ops: const [SuppleteOp('qent')]);
      expect(scanner.scan(bad, inventory), [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'q',
        ),
      ]);
    });

    test('Test 9 — RedupOp is a no-op regardless of inventory', () {
      final empty = inv();
      final parsed = wrap(ops: const [
        RedupOp(scope: 'full', position: 'prefix'),
      ]);
      expect(scanner.scan(parsed, empty), isEmpty);

      final populated = inv(consonants: ['t'], vowels: ['a']);
      final parsed2 = wrap(ops: const [
        RedupOp(scope: 'CV', position: 'suffix'),
      ]);
      expect(scanner.scan(parsed2, populated), isEmpty);
    });

    // -------------------------------------------------------------------
    // Tests 10-16: PatternCond class-ref skip + literal checking
    // -------------------------------------------------------------------

    test('Test 10 — PatternCond V class-ref returns empty', () {
      final inventory = inv();
      final parsed = wrap(
        conditions: const [PatternCond('V')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test('Test 11 — PatternCond C class-ref returns empty', () {
      final inventory = inv();
      final parsed = wrap(
        conditions: const [PatternCond('C')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test('Test 12 — PatternCond F class-ref returns empty', () {
      final inventory = inv();
      final parsed = wrap(
        conditions: const [PatternCond('F')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test(
        'Test 13 — PatternCond bracketed [nasal] class-ref returns empty',
        () {
      final inventory = inv();
      final parsed = wrap(
        conditions: const [PatternCond('[nasal]')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test(
        'Test 14 — PatternCond V + literal in-inventory a returns empty',
        () {
      final inventory = inv(vowels: ['a']);
      final parsed = wrap(
        conditions: const [PatternCond('Va')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test(
        'Test 15 — PatternCond V + literal q (not in inventory) returns '
        'one violation at literalOffset 1 with char q', () {
      final inventory = inv(vowels: ['a']);
      final parsed = wrap(
        conditions: const [PatternCond('Vq')],
        ops: const [SuffixOp('')],
      );
      final violations = scanner.scan(parsed, inventory);
      expect(violations, [
        const PhonemeViolation(
          opIndex: -1,
          literalOffset: 1,
          length: 1,
          char: 'q',
        ),
      ]);
    });

    test(
        'Test 16 — PatternCond [nasal] + literal x returns one violation '
        'at literalOffset 7', () {
      final inventory = inv();
      final parsed = wrap(
        conditions: const [PatternCond('[nasal]x')],
        ops: const [SuffixOp('')],
      );
      final violations = scanner.scan(parsed, inventory);
      expect(violations, [
        const PhonemeViolation(
          opIndex: -1,
          literalOffset: 7,
          length: 1,
          char: 'x',
        ),
      ]);
    });

    // -------------------------------------------------------------------
    // Tests 17-20: multi-op, multi-branch, empty inventory, parse failure
    // -------------------------------------------------------------------

    test(
        'Test 17 — multi-op rule: SuffixOp(in) + AblautOp(q -> e) yields '
        'exactly one violation with opIndex=1 on q', () {
      final inventory = inv(consonants: ['n'], vowels: ['i', 'e']);
      final parsed = wrap(ops: const [
        SuffixOp('in'),
        AblautOp(from: 'q', to: 'e'),
      ]);
      final violations = scanner.scan(parsed, inventory);
      expect(violations, [
        const PhonemeViolation(
          opIndex: 1,
          literalOffset: 0,
          length: 1,
          char: 'q',
        ),
      ]);
    });

    test(
        'Test 18 — multi-branch rule: opIndex is local to each branch; '
        'violations are flat across branches', () {
      final inventory = inv(vowels: ['a']);
      const rule = MorphologicalRule(
        id: 0,
        name: '',
        source: '',
        branches: [
          MorphBranch(
            conditions: [],
            operations: [SuffixOp('xa')], // violation at branch[0] op 0
          ),
          MorphBranch(
            conditions: [],
            operations: [
              PrefixOp('a'), // ok
              SuffixOp('zz'), // violations at branch[1] op 1 (two 'z')
            ],
          ),
        ],
      );
      const parsed = ParsedMorphRule.success(source: '', rule: rule);
      final violations = scanner.scan(parsed, inventory);
      // branch[0]: one 'x' at opIndex=0 offset=0
      // branch[1]: two 'z' at opIndex=1 offsets 0 and 1
      expect(violations.length, 3);
      // First: 'x' at opIndex 0 of branch[0].
      expect(violations[0].char, 'x');
      expect(violations[0].opIndex, 0);
      // Both 'z' violations carry opIndex=1 (branch-local index).
      expect(violations[1].char, 'z');
      expect(violations[1].opIndex, 1);
      expect(violations[2].char, 'z');
      expect(violations[2].opIndex, 1);
    });

    test(
        'Test 19 — empty inventory against SuffixOp(a) emits one violation '
        '(every char is unknown)', () {
      final inventory = PhonemeInventory.empty;
      final parsed = wrap(ops: const [SuffixOp('a')]);
      expect(scanner.scan(parsed, inventory), [
        const PhonemeViolation(
          opIndex: 0,
          literalOffset: 0,
          length: 1,
          char: 'a',
        ),
      ]);
    });

    test(
        'Test 20 — ParsedMorphRule.failure returns empty violations '
        '(defensive no-op)', () {
      final inventory = inv(vowels: ['a']);
      const parsed = ParsedMorphRule.failure(
        source: 'garbage',
        error: 'parse error',
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    // -------------------------------------------------------------------
    // Edge-case coverage
    // -------------------------------------------------------------------

    test('Edge — digraph aː in AblautOp.to beats single-char match', () {
      final inventory = inv(vowels: ['a', 'aː']);
      final parsed = wrap(ops: const [AblautOp(from: 'a', to: 'aː')]);
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test('Edge — empty literal string is a no-op (no violations)', () {
      final inventory = inv();
      final parsed = wrap(ops: const [SuffixOp('')]);
      expect(scanner.scan(parsed, inventory), isEmpty);
    });

    test('Edge — PatternCond with optional group markers ( and ) skipped',
        () {
      // 'Vk(l)' — V is class-ref, k and l are literals. If k and l are in
      // inventory, the parens should be skipped as structural markers.
      final inventory = inv(consonants: ['k', 'l'], vowels: ['a']);
      final parsed = wrap(
        conditions: const [PatternCond('Vk(l)')],
        ops: const [SuffixOp('')],
      );
      expect(scanner.scan(parsed, inventory), isEmpty);
    });
  });
}
