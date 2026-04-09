// Unit tests for phonotactic validation logic.
// These tests verify the WordGenerator.validateWord() semantics that the
// phonotacticValidatorProvider delegates to.
//
// Run with: flutter test test/lexicon/phonotactic_validation_test.dart

import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/phonology/domain/phonotactic_dsl.dart';
import '../../lib/features/phonology/domain/word_generator.dart';

void main() {
  group('phonotactic validation', () {
    // Shared inventory: consonants p, t, k; vowels a, e, i
    const inventory = PhonemeInventory(
      consonants: ['p', 't', 'k'],
      vowels: ['a', 'e', 'i'],
      naturalClasses: {},
    );

    // Forbidden rule: stop+stop (e.g. "pt" is illegal)
    final forbiddenStopCluster = parseConstraintRule('[C][C] -> forbidden');
    final forbiddenRule = ConstraintRule(
      pattern: forbiddenStopCluster.rule!.pattern,
      description: 'No consonant clusters',
      isForbidden: true,
      source: forbiddenStopCluster.rule!.source,
      position: ConstraintPosition.anywhere,
    );

    // Non-forbidden rule (annotation only, not flagged as violation)
    final annotationRule = ConstraintRule(
      pattern: forbiddenStopCluster.rule!.pattern,
      description: 'Consonant cluster annotation',
      isForbidden: false,
      source: forbiddenStopCluster.rule!.source,
      position: ConstraintPosition.anywhere,
    );

    test('word with forbidden sequence returns isValid false with violations', () {
      // "pt" contains a stop cluster — should be flagged
      final result = WordGenerator().validateWord(
        word: 'ptaki',
        constraints: [forbiddenRule],
        inventory: inventory,
      );

      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
      expect(result.violations.first.ruleDescription, equals('No consonant clusters'));
    });

    test('word conforming to all constraints returns isValid true', () {
      // "paki" has no consonant clusters
      final result = WordGenerator().validateWord(
        word: 'paki',
        constraints: [forbiddenRule],
        inventory: inventory,
      );

      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('empty word returns isValid true (no violations possible)', () {
      final result = WordGenerator().validateWord(
        word: '',
        constraints: [forbiddenRule],
        inventory: inventory,
      );

      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('multiple forbidden patterns produce multiple ViolationSpan entries', () {
      // Forbidden: initial k, forbidden: final t
      final forbiddenInitialK = parseConstraintRule('k -> forbidden initial k');
      final initialKRule = ConstraintRule(
        pattern: forbiddenInitialK.rule!.pattern,
        description: 'No initial k',
        isForbidden: true,
        source: forbiddenInitialK.rule!.source,
        position: ConstraintPosition.start,
      );
      final forbiddenFinalT = parseConstraintRule('t -> forbidden final t');
      final finalTRule = ConstraintRule(
        pattern: forbiddenFinalT.rule!.pattern,
        description: 'No final t',
        isForbidden: true,
        source: forbiddenFinalT.rule!.source,
        position: ConstraintPosition.end,
      );

      // "kat" — violates both: starts with k, ends with t
      final result = WordGenerator().validateWord(
        word: 'kat',
        constraints: [initialKRule, finalTRule],
        inventory: inventory,
      );

      expect(result.isValid, isFalse);
      expect(result.violations.length, greaterThanOrEqualTo(2));
      final descriptions = result.violations.map((v) => v.ruleDescription).toList();
      expect(descriptions, containsAll(['No initial k', 'No final t']));
    });

    test('non-forbidden annotation rules do not produce violations', () {
      // annotationRule has isForbidden=false — should not appear in violations
      final result = WordGenerator().validateWord(
        word: 'ptaki',
        constraints: [annotationRule],
        inventory: inventory,
      );

      expect(result.isValid, isTrue);
      expect(result.violations, isEmpty);
    });

    test('violation span positions are within word bounds', () {
      final result = WordGenerator().validateWord(
        word: 'ptaki',
        constraints: [forbiddenRule],
        inventory: inventory,
      );

      expect(result.violations, isNotEmpty);
      for (final v in result.violations) {
        expect(v.position, greaterThanOrEqualTo(0));
        expect(v.position + v.length, lessThanOrEqualTo('ptaki'.length));
      }
    });
  });
}
