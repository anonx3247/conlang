// Tests for the alias-first class resolver shared by WordGenerator._resolveClass
// and morphology_engine.resolvePhonemeClass.
//
// This suite enforces:
//   1. D-05a / RESEARCH F-2 — single-letter aliases (S/N/F/L/R) are resolved
//      BEFORE lowercasing, so `S` returns the default stops list without
//      colliding with literal /s/.
//   2. D-06 — user-defined full-name classes still shadow default full-name
//      classes via the lowercased lookup path.
//   3. Parity — word_generator and morphology_engine must produce byte-identical
//      output for every input, since morphology_engine.resolvePhonemeClass is
//      documented as "adapted from WordGenerator._resolveClass" and downstream
//      rule evaluation depends on them behaving the same.

import 'package:conlang_workbench/features/morphology/domain/morphology_engine.dart';
import 'package:conlang_workbench/features/phonology/domain/default_natural_classes.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Inventory where 'stop' is user-overridden to just [p, t, k] — proves that
  // the single-letter alias 'S' bypasses the user map entirely (the alias map
  // is always the default list), while the full-name 'stop' still honors user
  // precedence via the lowercased lookup.
  final inv = PhonemeInventory(
    consonants: const ['p', 't', 'k', 's', 'm', 'n'],
    vowels: const ['a', 'e', 'i'],
    naturalClasses: const {
      'stop': ['p', 't', 'k'], // user override
      // Note: in a REAL buildInventory run, default 'nasal' etc. would also be
      // seeded. We omit them here to keep the test focused on resolver
      // behavior, not merge behavior (which is Plan 01's test).
    },
  );

  // Helper: run both resolvers and assert they agree with the expected output.
  void bothReturn(String classRef, List<String> expected) {
    final wg = WordGenerator().resolveClassForTesting(classRef, inv);
    final me = resolvePhonemeClass(classRef, inv);
    expect(
      wg,
      equals(expected),
      reason: 'word_generator mismatch for "$classRef"',
    );
    expect(
      me,
      equals(expected),
      reason: 'morphology_engine mismatch for "$classRef"',
    );
    expect(
      wg,
      equals(me),
      reason: 'resolver parity broken for "$classRef"',
    );
  }

  group('alias-first lookup (D-05a / F-2)', () {
    test('S returns default stops (NOT user override)', () {
      bothReturn('S', defaultNaturalClassAliases['S']!);
    });

    test('stop (full name) returns user override — D-06 precedence', () {
      bothReturn('stop', const ['p', 't', 'k']);
    });

    test('N returns default nasals', () {
      bothReturn('N', defaultNaturalClassAliases['N']!);
    });

    test('F returns default fricatives', () {
      bothReturn('F', defaultNaturalClassAliases['F']!);
    });

    test('L returns default liquids', () {
      bothReturn('L', defaultNaturalClassAliases['L']!);
    });

    test('R returns default rhotics', () {
      bothReturn('R', defaultNaturalClassAliases['R']!);
    });
  });

  group('literal phoneme non-collision (F-2 proof)', () {
    test('s (lowercase) does NOT hit alias map — returns empty list', () {
      // Proves literal /s/ is not shadowed by alias S. The resolver operates
      // on the map handed to it; this inventory has no 's' natural class key,
      // so the result is empty. The key guarantee: 's' did NOT get routed to
      // the S alias (which would have returned 13 stops).
      bothReturn('s', const []);
    });

    test('unknown X alias falls through to empty', () {
      bothReturn('X', const []);
    });
  });

  group('reserved C/V preserved', () {
    test('C returns inventory.consonants', () {
      bothReturn('C', inv.consonants);
    });

    test('V returns inventory.vowels', () {
      bothReturn('V', inv.vowels);
    });
  });

  group('full-name fall-through', () {
    test('Nasal (capitalized) lowercases to nasal → empty for this inventory',
        () {
      // This inventory doesn't have 'nasal' seeded, so it returns empty.
      // The buildInventory-seeded-defaults path is tested in Plan 01.
      // What matters here: the alias map only has single letters, so 'Nasal'
      // does NOT hit the alias map — it falls through to the lowercased
      // lookup, which finds no 'nasal' key in this hand-built inventory.
      bothReturn('Nasal', const []);
    });
  });
}
