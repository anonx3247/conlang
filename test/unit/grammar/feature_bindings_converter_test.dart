import 'dart:convert';

import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const c = FeatureBindingsConverter();

  group('FeatureBindingsConverter', () {
    test('toSql emits canonical JSON with pos array and stringified dim keys',
        () {
      final out =
          c.toSql(const FeatureBindings(pos: [1, 3], dims: {5: 2, 7: 4}));
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['pos'], equals([1, 3]));
      expect(decoded['5'], equals(2));
      expect(decoded['7'], equals(4));
    });

    test('fromSql parses pos array and dim->level map', () {
      final fb = c.fromSql('{"pos":[1,3],"5":2,"7":4}');
      expect(fb.pos, equals([1, 3]));
      expect(fb.dims, equals({5: 2, 7: 4}));
    });

    test('fromSql on empty object returns empty bindings', () {
      final fb = c.fromSql('{}');
      expect(fb.pos, isEmpty);
      expect(fb.dims, isEmpty);
    });

    test('toSql on empty bindings emits {}', () {
      final out = c.toSql(const FeatureBindings(pos: [], dims: {}));
      expect(jsonDecode(out), equals(<String, dynamic>{}));
    });

    test('isInflectional true when dims non-empty', () {
      expect(const FeatureBindings(pos: [], dims: {5: 2}).isInflectional,
          isTrue);
      expect(const FeatureBindings(pos: [], dims: {5: 2}).isDerivational,
          isFalse);
    });

    test('isDerivational true when dims empty even if pos set', () {
      expect(const FeatureBindings(pos: [1], dims: {}).isInflectional, isFalse);
      expect(const FeatureBindings(pos: [1], dims: {}).isDerivational, isTrue);
    });

    test('specificity equals dims.length', () {
      expect(
          const FeatureBindings(pos: [], dims: {5: 2, 7: 4}).specificity,
          equals(2));
    });

    test('round-trip preserves equality', () {
      const original = FeatureBindings(
          pos: [1, 2, 3], dims: {10: 1, 11: 2, 12: 3, 13: 4});
      final roundTripped = c.fromSql(c.toSql(original));
      expect(roundTripped, equals(original));
    });
  });
}
