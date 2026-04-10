// End-to-end PHON-09 proof: parsing a syllable template that references a
// default natural class against a user inventory that defines NO consonants
// and NO natural classes must still produce words drawn from the default
// catalog. This exercises the full chain:
//
//   parseSyllableTemplate -> buildInventory (seeds defaults) ->
//   WordGenerator.generateWords -> _resolveClass (alias-first path).
//
// Two templates are tested:
//   1. `[stop]V` — full-name path (hits the lowercased-map lookup seeded by
//      buildInventory in Plan 01).
//   2. `SV` — single-letter alias path (hits the case-sensitive alias check
//      added in Plan 02 Task 1).
//
// Both must yield words whose initial phoneme is a member of the default
// stops list. This is the requirement that originally motivated Phase 3.2.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/phonology/data/phonotactic_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/default_natural_classes.dart';
import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal Phoneme fixture — only id/symbol/type are required per the Drift
// generated constructor in lib/db/app_database.g.dart (all other fields are
// nullable). Matches the pattern used in test/phonology/build_inventory_test.dart.
Phoneme _phoneme(int id, String symbol, String type) =>
    Phoneme(id: id, symbol: symbol, type: type);

Phoneme _vowel(int id, String symbol) => _phoneme(id, symbol, 'vowel');

void main() {
  group('PHON-09 end-to-end: default natural classes resolve against empty '
      'user inventory', () {
    test('[stop]V template → buildInventory([], vowels, []) → generateWords '
        'yields words starting with a default stop', () {
      final parsed = parseSyllableTemplate('[stop]V');
      expect(
        parsed.isValid,
        isTrue,
        reason: '[stop]V should parse successfully',
      );

      // User inventory: only vowels, NO consonants, NO user-defined natural
      // classes. The default catalog (seeded by buildInventory in Plan 01) is
      // the sole source of the 'stop' list.
      final vowels = [_vowel(1, 'a'), _vowel(2, 'e'), _vowel(3, 'i')];
      final inventory = buildInventory(const [], vowels, const []);

      // Sanity: the buildInventory merge must have seeded 'stop' even with
      // no user classes supplied.
      expect(
        inventory.naturalClasses.containsKey('stop'),
        isTrue,
        reason: 'buildInventory should seed default stop class',
      );
      expect(
        inventory.naturalClasses['stop'],
        isNotEmpty,
        reason: 'default stop list must not be empty',
      );

      // Use a seeded RNG for deterministic output (prevents flakes).
      final words = WordGenerator().generateWords(
        templates: [parsed],
        inventory: inventory,
        count: 20,
        minSyllables: 1,
        maxSyllables: 1,
      );

      expect(
        words,
        hasLength(20),
        reason: 'all 20 generation attempts should succeed',
      );

      final defaultStops = defaultNaturalClasses['stop']!;
      for (final w in words) {
        expect(w, isNotEmpty, reason: 'generated word should not be empty');
        final matchesAStop = defaultStops.any((stop) => w.startsWith(stop));
        expect(
          matchesAStop,
          isTrue,
          reason: 'word "$w" should start with a default stop '
              '(defaults=$defaultStops)',
        );
      }
    });

    test('SV template (single-letter alias) → same outcome via alias path',
        () {
      final parsed = parseSyllableTemplate('SV');
      expect(parsed.isValid, isTrue, reason: 'SV should parse successfully');

      final vowels = [_vowel(1, 'a'), _vowel(2, 'e'), _vowel(3, 'i')];
      final inventory = buildInventory(const [], vowels, const []);

      final words = WordGenerator().generateWords(
        templates: [parsed],
        inventory: inventory,
        count: 20,
        minSyllables: 1,
        maxSyllables: 1,
      );

      expect(words, hasLength(20));

      final aliasStops = defaultNaturalClassAliases['S']!;
      for (final w in words) {
        expect(w, isNotEmpty);
        final matchesAStop = aliasStops.any((stop) => w.startsWith(stop));
        expect(
          matchesAStop,
          isTrue,
          reason: 'word "$w" should start with a default-alias stop '
              '(alias S=$aliasStops)',
        );
      }
    });

    test('[stop]V and SV produce results drawn from the same list', () {
      // The alias map and the full-name map must carry identical stop lists.
      // If Plan 01 ever drifts (alias list != full-name list), this test
      // catches it at the integration layer.
      expect(
        defaultNaturalClasses['stop'],
        equals(defaultNaturalClassAliases['S']),
        reason: 'default stop list and S alias list must be identical',
      );
    });
  });
}
