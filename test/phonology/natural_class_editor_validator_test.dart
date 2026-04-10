// Unit tests for the pure-function validator extracted from the natural-class
// editor dialog. The validator must reject both the legacy reserved names
// (C, V) and the Phase 3.2 single-letter aliases (S, N, F, L, R) while still
// allowing users to shadow default full-name classes (D-06).

import 'package:conlang_workbench/features/phonology/presentation/inventory/natural_class_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateNaturalClassName', () {
    test('rejects S with alias-expansion message', () {
      final err = validateNaturalClassName('S');
      expect(err, isNotNull);
      expect(err, contains('Stop'));
      expect(err, contains('reserved'));
    });

    test('rejects N with alias-expansion message', () {
      final err = validateNaturalClassName('N');
      expect(err, isNotNull);
      expect(err, contains('Nasal'));
    });

    test('rejects F with alias-expansion message', () {
      final err = validateNaturalClassName('F');
      expect(err, isNotNull);
      expect(err, contains('Fricative'));
    });

    test('rejects L with alias-expansion message', () {
      final err = validateNaturalClassName('L');
      expect(err, isNotNull);
      expect(err, contains('Liquid'));
    });

    test('rejects R with alias-expansion message', () {
      final err = validateNaturalClassName('R');
      expect(err, isNotNull);
      expect(err, contains('Rhotic'));
    });

    test('rejects C (system class regression guard)', () {
      final err = validateNaturalClassName('C');
      expect(err, isNotNull);
      expect(err, contains('reserved'));
    });

    test('rejects V (system class regression guard)', () {
      final err = validateNaturalClassName('V');
      expect(err, isNotNull);
      expect(err, contains('reserved'));
    });

    test('accepts stop (D-06 user override allowed)', () {
      // Lowercase full names are intentionally NOT reserved — D-06 lets users
      // shadow default full-name classes via the lowercased lookup path in
      // buildInventory.
      expect(validateNaturalClassName('stop'), isNull);
    });

    test('accepts Stop (not a single letter, not reserved)', () {
      // Only single-letter aliases are reserved. A multi-character capitalized
      // name like "Stop" is fine — buildInventory lowercases user class names
      // before merging, so it still overrides default 'stop'.
      expect(validateNaturalClassName('Stop'), isNull);
    });

    test('accepts X (unreserved single letter)', () {
      expect(validateNaturalClassName('X'), isNull);
    });

    test('rejects empty string with Required', () {
      expect(validateNaturalClassName(''), equals('Required'));
    });

    test('rejects whitespace-only with Required', () {
      expect(validateNaturalClassName('   '), equals('Required'));
    });

    test('rejects null with Required', () {
      expect(validateNaturalClassName(null), equals('Required'));
    });

    test('trims whitespace before checking reserved status', () {
      // '  S  ' is just the reserved alias with padding.
      expect(validateNaturalClassName('  S  '), isNotNull);
    });
  });
}
