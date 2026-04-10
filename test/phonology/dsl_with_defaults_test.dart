// End-to-end PHON-09 + 2026-04-10 UAT proof: parsing a syllable template that
// references a default natural class must resolve against the intersection
// of the default catalog and the user's actual phoneme inventory. The word
// generator must ONLY emit symbols the user has defined — the default catalog
// ships with full IPA sets but generation is inventory-gated.
//
// This exercises the full chain:
//
//   parseSyllableTemplate -> buildInventory (seeds filtered defaults) ->
//   WordGenerator.generateWords -> _resolveClass (alias-first path, filtered).
//
// Two templates are tested:
//   1. `[stop]V` — full-name path (hits the lowercased-map lookup; the map
//      is pre-filtered in buildInventory).
//   2. `SV` — single-letter alias path (hits the case-sensitive alias check
//      in Plan 02 Task 1, filtered inline at resolution time).
//
// Both must yield words whose initial phoneme is a member of the user's
// inventory AND is also in the default stops catalog. This is the
// requirement that motivated Phase 3.2, as amended by the 2026-04-10 UAT.

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

Phoneme _consonant(int id, String symbol) => _phoneme(id, symbol, 'consonant');
Phoneme _vowel(int id, String symbol) => _phoneme(id, symbol, 'vowel');

void main() {
  group('PHON-09 end-to-end: default natural classes resolve against the '
      "intersection of the catalog and the user's inventory", () {
    test('[stop]V template + inventory [p, t, k, m] → yields only [p, t, k] '
        'as initial consonant', () {
      final parsed = parseSyllableTemplate('[stop]V');
      expect(parsed.isValid, isTrue, reason: '[stop]V should parse');

      // User inventory: some stops (p, t, k) + a nasal (m, NOT a stop).
      // The default catalog has 13 stops; intersection with this inventory
      // must be exactly [p, t, k]. /m/ must NEVER appear as the initial
      // consonant of a [stop]V word.
      final consonants = [
        _consonant(1, 'p'),
        _consonant(2, 't'),
        _consonant(3, 'k'),
        _consonant(4, 'm'),
      ];
      final vowels = [_vowel(10, 'a'), _vowel(11, 'e'), _vowel(12, 'i')];
      final inventory = buildInventory(consonants, vowels, const []);

      // buildInventory should have seeded 'stop' as the filtered set.
      expect(
        inventory.naturalClasses['stop'],
        equals(['p', 't', 'k']),
        reason: 'filtered default stop list must equal the inventory '
            '∩ default stops',
      );

      final words = WordGenerator().generateWords(
        templates: [parsed],
        inventory: inventory,
        count: 30,
        minSyllables: 1,
        maxSyllables: 1,
      );

      expect(words, hasLength(30));

      const allowedStops = {'p', 't', 'k'};
      for (final w in words) {
        expect(w, isNotEmpty);
        expect(
          allowedStops.any((stop) => w.startsWith(stop)),
          isTrue,
          reason: 'word "$w" should start with an in-inventory stop '
              '(allowed=$allowedStops), not /m/ or any out-of-inventory symbol',
        );
      }
    });

    test('SV template (single-letter alias) + inventory [p, t] → yields only '
        '[p, t] as initial consonant', () {
      final parsed = parseSyllableTemplate('SV');
      expect(parsed.isValid, isTrue, reason: 'SV should parse');

      // Only two stops in the inventory — proves the alias path filters.
      final consonants = [_consonant(1, 'p'), _consonant(2, 't')];
      final vowels = [_vowel(10, 'a'), _vowel(11, 'e')];
      final inventory = buildInventory(consonants, vowels, const []);

      final words = WordGenerator().generateWords(
        templates: [parsed],
        inventory: inventory,
        count: 30,
        minSyllables: 1,
        maxSyllables: 1,
      );

      expect(words, hasLength(30));

      const allowedStops = {'p', 't'};
      for (final w in words) {
        expect(w, isNotEmpty);
        expect(
          allowedStops.any((stop) => w.startsWith(stop)),
          isTrue,
          reason: 'word "$w" should start with an in-inventory stop via alias '
              'path (allowed=$allowedStops)',
        );
      }
    });

    test('[stop]V and SV produce results drawn from the same filtered list',
        () {
      // The default alias map and the full-name map must carry identical
      // stop lists, so both resolution paths produce the same intersection
      // against any given inventory.
      expect(
        defaultNaturalClasses['stop'],
        equals(defaultNaturalClassAliases['S']),
        reason: 'default stop list and S alias list must be identical at '
            'the catalog level',
      );
    });

    test('empty consonant inventory + [stop]V never emits out-of-inventory '
        'IPA symbols', () {
      // UAT 2026-04-10: with no consonants in the inventory, the default
      // stop list filters to empty, so the word generator must never emit
      // any default-catalog IPA stop symbol. (The generator skips empty
      // class slots rather than failing, so the output may contain just
      // vowels — that's fine; the contract is "no out-of-inventory
      // symbols", not "no words at all".)
      final parsed = parseSyllableTemplate('[stop]V');
      expect(parsed.isValid, isTrue);

      final vowels = [_vowel(10, 'a'), _vowel(11, 'e'), _vowel(12, 'i')];
      final inventory = buildInventory(const [], vowels, const []);

      expect(
        inventory.naturalClasses['stop'],
        isEmpty,
        reason: 'no user consonants → filtered default stop list is empty',
      );

      final words = WordGenerator().generateWords(
        templates: [parsed],
        inventory: inventory,
        count: 20,
        minSyllables: 1,
        maxSyllables: 1,
      );

      // Every word must be composed entirely of symbols from the user's
      // inventory. No default-catalog stop (p, b, t, d, ʈ, ɖ, c, ɟ, k, ɡ,
      // q, ɢ, ʔ) may appear anywhere in any generated word.
      final allowedSymbols = {
        ...inventory.consonants,
        ...inventory.vowels,
      };
      final defaultStops = defaultNaturalClasses['stop']!.toSet();
      for (final w in words) {
        for (final stop in defaultStops) {
          expect(
            w.contains(stop),
            isFalse,
            reason: 'word "$w" must not contain out-of-inventory stop "$stop"',
          );
        }
        // Sanity: every character of the word is an allowed symbol (vowels
        // only, in this setup).
        for (final ch in w.runes.map(String.fromCharCode)) {
          expect(
            allowedSymbols.contains(ch),
            isTrue,
            reason: 'word "$w" contains out-of-inventory character "$ch"',
          );
        }
      }
    });
  });
}
