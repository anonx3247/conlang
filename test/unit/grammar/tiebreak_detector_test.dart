import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/inflectional_rule.dart';
import 'package:conlang_workbench/features/grammar/domain/tiebreak_detector.dart';
import 'package:flutter_test/flutter_test.dart';

InflectionalRule _rule(
  int id,
  String name,
  Map<int, int> dims, {
  bool isActive = true,
}) {
  return InflectionalRule(
    id: id,
    name: name,
    source: '+x',
    isActive: isActive,
    bindings: FeatureBindings(pos: const [], dims: dims),
  );
}

void main() {
  group('findDuplicateSpecificityConflicts', () {
    test('Test 12: identical bindings are flagged', () {
      final rules = [
        _rule(1, '-x', const {10: 1, 11: 1}),
        _rule(2, '-y', const {10: 1, 11: 1}),
        _rule(3, '-z', const {10: 1}),
      ];
      final conflicts = findDuplicateSpecificityConflicts(rules);
      expect(conflicts.length, equals(1));
      final group = conflicts.first.rules;
      expect(group.length, equals(2));
      expect(
        group.map((r) => r.name).toSet(),
        equals({'-x', '-y'}),
      );
    });

    test('Test 13: different bindings same specificity → no conflict', () {
      final rules = [
        _rule(1, '-a', const {10: 1}),
        _rule(2, '-b', const {10: 2}),
      ];
      final conflicts = findDuplicateSpecificityConflicts(rules);
      expect(conflicts, isEmpty);
    });

    test('empty input returns empty list', () {
      expect(findDuplicateSpecificityConflicts(const []), isEmpty);
    });

    test('single rule per binding key is not a conflict', () {
      final rules = [
        _rule(1, '-a', const {10: 1}),
        _rule(2, '-b', const {11: 1}),
        _rule(3, '-c', const {10: 1, 11: 1}),
      ];
      expect(findDuplicateSpecificityConflicts(rules), isEmpty);
    });

    test('inactive rules excluded from conflict detection', () {
      final rules = [
        _rule(1, '-x', const {10: 1}),
        _rule(2, '-y', const {10: 1}, isActive: false),
      ];
      expect(findDuplicateSpecificityConflicts(rules), isEmpty);
    });

    test('derivational rules (empty dims) excluded from conflict detection',
        () {
      final rules = [
        _rule(1, '-x', const {}),
        _rule(2, '-y', const {}),
      ];
      expect(findDuplicateSpecificityConflicts(rules), isEmpty);
    });

    test('three-way tie groups all three together', () {
      final rules = [
        _rule(1, '-a', const {10: 1, 11: 2}),
        _rule(2, '-b', const {10: 1, 11: 2}),
        _rule(3, '-c', const {10: 1, 11: 2}),
      ];
      final conflicts = findDuplicateSpecificityConflicts(rules);
      expect(conflicts.length, equals(1));
      expect(conflicts.first.rules.length, equals(3));
    });
  });
}
