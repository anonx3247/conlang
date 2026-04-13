// Plan 04 Wave 3a-bis G-67 fix — regression tests for the per-POS binding
// remap that makes multi-POS inflectional rules fire on every attached POS.
//
// The bug: inflectional rule bindings store dim/level IDs from the authoring
// POS's dimension rows. Dimensions are POS-scoped — each POS has its own
// row for "number", "gender", etc. — so a rule bound to {noun.number: SG}
// never matched a descriptor cell whose target had {descriptor.number: SG},
// even though the conceptual feature was identical.
//
// The fix: translate bindings at read time by matching dim + level names
// across POS. Each rule surfaces with the query POS's own IDs.

import 'dart:convert';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/binding_translator.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

String _levelsJson(List<({int id, String name, String abbr, int ordering})> lv) {
  return jsonEncode(lv
      .map((l) => {
            'id': l.id,
            'name': l.name,
            'abbr': l.abbr,
            'ordering': l.ordering,
          })
      .toList());
}

Dimension _dim({
  required int id,
  required int posId,
  required String name,
  required String levelsJson,
}) {
  return Dimension(
    id: id,
    posId: posId,
    name: name,
    levelsJson: levelsJson,
    ordering: 0,
    // 04-17 D-82: Dimensions.intrinsic required field (default false).
    intrinsic: false,
  );
}

void main() {
  group('translateBindingsByName', () {
    test('returns original when dims is empty', () {
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {}),
        authPosDims: const [],
        queryPosDims: const [],
      );
      expect(result, isNotNull);
      expect(result!.dims, isEmpty);
    });

    test('pass-through when auth dim id already exists in query space', () {
      // The identity case — both POS share the literal Dimensions row id.
      final dim = _dim(
        id: 5,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
          (id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
        ]),
      );
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1], dims: {5: 1}),
        authPosDims: [dim],
        queryPosDims: [dim],
      );
      expect(result, isNotNull);
      expect(result!.dims, equals({5: 1}));
    });

    test('remaps dim id across POS by name, preserving same level ids',
        () {
      // Nouns and descriptors each have their own "Number" dimension row.
      // Levels come from the same template so the level ids are identical.
      final nounNumber = _dim(
        id: 10,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
          (id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
        ]),
      );
      final descriptorNumber = _dim(
        id: 20,
        posId: 2,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
          (id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
        ]),
      );

      // Rule authored against noun (dim.id = 10), bound to SG (level id 1).
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {10: 1}),
        authPosDims: [nounNumber],
        queryPosDims: [descriptorNumber],
      );

      expect(result, isNotNull);
      expect(result!.dims, equals({20: 1}),
          reason: 'dim id remapped from noun.10 to descriptor.20, level id '
              'unchanged because levels come from the same template');
    });

    test('remaps level id when templates differ but name matches', () {
      final nounGender = _dim(
        id: 10,
        posId: 1,
        name: 'Gender',
        levelsJson: _levelsJson([
          (id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
          (id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
        ]),
      );
      // Descriptor's Gender uses DIFFERENT level ids — e.g. a user renumbered
      // them, or added "Neuter" at index 0 then renumbered.
      final descriptorGender = _dim(
        id: 20,
        posId: 2,
        name: 'Gender',
        levelsJson: _levelsJson([
          (id: 3, name: 'Neuter', abbr: 'N', ordering: 0),
          (id: 5, name: 'Masculine', abbr: 'M', ordering: 1),
          (id: 7, name: 'Feminine', abbr: 'F', ordering: 2),
        ]),
      );

      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {10: 1}),
        authPosDims: [nounGender],
        queryPosDims: [descriptorGender],
      );

      expect(result, isNotNull);
      expect(result!.dims, equals({20: 5}),
          reason: 'Masculine id remapped from 1 to 5 via name match');
    });

    test('falls back to abbr when level name does not match', () {
      final nounNumber = _dim(
        id: 10,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
        ]),
      );
      final descriptorNumber = _dim(
        id: 20,
        posId: 2,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 99, name: 'Sing.', abbr: 'SG', ordering: 0),
        ]),
      );
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {10: 1}),
        authPosDims: [nounNumber],
        queryPosDims: [descriptorNumber],
      );
      expect(result, isNotNull);
      expect(result!.dims, equals({20: 99}));
    });

    test('returns null when query POS lacks the named dimension', () {
      final nounNumber = _dim(
        id: 10,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
        ]),
      );
      final verbAspect = _dim(
        id: 20,
        posId: 3,
        name: 'Aspect',
        levelsJson: _levelsJson([
          (id: 1, name: 'Perfective', abbr: 'PFV', ordering: 0),
        ]),
      );
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 3], dims: {10: 1}),
        authPosDims: [nounNumber],
        queryPosDims: [verbAspect],
      );
      expect(result, isNull,
          reason: 'Verbs have no Number dim, so the rule is unreachable');
    });

    test('returns null when query POS dim lacks the target level name', () {
      final nounNumber = _dim(
        id: 10,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Dual', abbr: 'DU', ordering: 0),
        ]),
      );
      final descriptorNumber = _dim(
        id: 20,
        posId: 2,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
          (id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
        ]),
      );
      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {10: 1}),
        authPosDims: [nounNumber],
        queryPosDims: [descriptorNumber],
      );
      expect(result, isNull,
          reason: 'descriptor Number has no "Dual" level');
    });

    test('multi-dim bindings are all remapped', () {
      final nounNumber = _dim(
        id: 10,
        posId: 1,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
        ]),
      );
      final nounGender = _dim(
        id: 11,
        posId: 1,
        name: 'Gender',
        levelsJson: _levelsJson([
          (id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
        ]),
      );
      final descNumber = _dim(
        id: 20,
        posId: 2,
        name: 'Number',
        levelsJson: _levelsJson([
          (id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
        ]),
      );
      final descGender = _dim(
        id: 21,
        posId: 2,
        name: 'Gender',
        levelsJson: _levelsJson([
          (id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
        ]),
      );

      final result = translateBindingsByName(
        original: const FeatureBindings(pos: [1, 2], dims: {10: 1, 11: 1}),
        authPosDims: [nounNumber, nounGender],
        queryPosDims: [descNumber, descGender],
      );

      expect(result, isNotNull);
      expect(result!.dims, equals({20: 1, 21: 1}));
    });
  });

  group('authPosIdForRule', () {
    test('returns smallest POS id in featureBindings.pos when non-empty', () {
      expect(
        authPosIdForRule(
          featureBindingsPos: const [5, 2, 8],
          legacyInputPosId: 99,
        ),
        equals(2),
      );
    });

    test('falls back to legacy inputPosId when featureBindingsPos is empty',
        () {
      expect(
        authPosIdForRule(
          featureBindingsPos: const [],
          legacyInputPosId: 42,
        ),
        equals(42),
      );
    });

    test('returns null when both sources are empty / null', () {
      expect(
        authPosIdForRule(
          featureBindingsPos: const [],
          legacyInputPosId: null,
        ),
        isNull,
      );
    });
  });
}
