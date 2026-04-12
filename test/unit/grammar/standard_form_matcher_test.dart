// Plan 04-17 Task 9 -- unit tests for D-96 StandardFormMatcher.
//
// Verifies branch-based OR matching with class-ref reuse from the
// existing PatternCond evaluator in the morphology engine.

import 'package:conlang_workbench/features/grammar/domain/standard_form_branch.dart';
import 'package:conlang_workbench/features/grammar/domain/standard_form_matcher.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart'
    show PhonemeInventory;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matcher = StandardFormMatcher();

  // Fixture: inventory with consonants and vowels for class-ref expansion.
  const inventory = PhonemeInventory(
    consonants: ['p', 't', 'k', 'r', 's', 'n'],
    vowels: ['a', 'e', 'i', 'o', 'u'],
    naturalClasses: {},
  );

  group('StandardFormMatcher', () {
    test('Test 1 (Spanish ar-class): endsWith "ar"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'ar'),
      ];
      expect(matcher.matches('amar', branches, inventory), isTrue);
      expect(matcher.matches('korrer', branches, inventory), isFalse);
    });

    test('Test 2 (Spanish er-class): endsWith "er"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'er'),
      ];
      expect(matcher.matches('korrer', branches, inventory), isTrue);
    });

    test('Test 3 (Spanish ir-class): endsWith "ir"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'ir'),
      ];
      expect(matcher.matches('vivir', branches, inventory), isTrue);
    });

    test('Test 4 (Vr vowel+r class ref): endsWith "Vr"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'Vr'),
      ];
      // V expands to {a,e,i,o,u}. 'amar' ends with 'ar' -> V=a, match.
      expect(matcher.matches('amar', branches, inventory), isTrue);
      // 'orur' ends with 'ur' -> V=u, match.
      expect(matcher.matches('orur', branches, inventory), isTrue);
      // 'lux' does not end with Vr pattern.
      // Note: 'x' is not in inventory, but the form itself is matched.
      // The engine tokenizes the form, so 'lux' may not tokenize cleanly.
      // Use a form that's clearly non-matching.
      expect(matcher.matches('park', branches, inventory), isFalse);
    });

    test('Test 5 (multi-branch OR): endsWith "a" OR endsWith "ion"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'a'),
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'ion'),
      ];
      expect(matcher.matches('kasa', branches, inventory), isTrue);
      expect(matcher.matches('nasion', branches, inventory), isTrue);
      expect(matcher.matches('tipro', branches, inventory), isFalse);
    });

    test('Test 6 (empty branches trivial match)', () {
      expect(matcher.matches('anything', const [], inventory), isTrue);
    });

    test('Test 7 (startsWith): startsWith "C" (consonant class ref)', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.startsWith, literal: 'C'),
      ];
      // 'pata' starts with 'p' which is a consonant.
      expect(matcher.matches('pata', branches, inventory), isTrue);
      // 'amar' starts with 'a' which is a vowel, not a consonant.
      expect(matcher.matches('amar', branches, inventory), isFalse);
    });

    test('Test 8 (contains): contains "a"', () {
      final branches = [
        const StandardFormBranch(kind: BranchKind.contains, literal: 'a'),
      ];
      expect(matcher.matches('pato', branches, inventory), isTrue);
      // 'iiu' contains no 'a'.
      expect(matcher.matches('iiu', branches, inventory), isFalse);
    });

    test('Test 9 (class ref missing from inventory): V with empty vowels',
        () {
      const emptyVowelInventory = PhonemeInventory(
        consonants: ['p', 't', 'k'],
        vowels: [],
        naturalClasses: {},
      );
      final branches = [
        const StandardFormBranch(kind: BranchKind.endsWith, literal: 'Vr'),
      ];
      // V cannot expand to anything, so branch never matches.
      expect(matcher.matches('par', branches, emptyVowelInventory), isFalse);
    });
  });
}
