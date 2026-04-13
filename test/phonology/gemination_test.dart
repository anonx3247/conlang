import 'package:flutter_test/flutter_test.dart';

import 'package:conlang_workbench/features/phonology/domain/phonotactic_dsl.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // GeminationConstraint / parseGeminationConstraint tests
  // ---------------------------------------------------------------------------

  group('parseGeminationConstraint', () {
    test('!GG returns everywhere constraint', () {
      final result = parseGeminationConstraint('!GG');
      expect(result.isValid, isTrue);
      expect(result.constraint!.positions, equals({GeminationPosition.everywhere}));
    });

    test('!GG/coda returns coda constraint', () {
      final result = parseGeminationConstraint('!GG/coda');
      expect(result.isValid, isTrue);
      expect(result.constraint!.positions, equals({GeminationPosition.coda}));
    });

    test('!GG/onset,initial returns onset and initial constraint', () {
      final result = parseGeminationConstraint('!GG/onset,initial');
      expect(result.isValid, isTrue);
      expect(
        result.constraint!.positions,
        equals({GeminationPosition.onset, GeminationPosition.initial}),
      );
    });

    test('invalid input returns failure', () {
      final result = parseGeminationConstraint('invalid');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('empty input returns failure', () {
      final result = parseGeminationConstraint('');
      expect(result.isValid, isFalse);
    });

    test('!GG/final returns final_ constraint', () {
      final result = parseGeminationConstraint('!GG/final');
      expect(result.isValid, isTrue);
      expect(result.constraint!.positions, equals({GeminationPosition.final_}));
    });

    test('!GG/everywhere returns everywhere constraint', () {
      final result = parseGeminationConstraint('!GG/everywhere');
      expect(result.isValid, isTrue);
      expect(result.constraint!.positions, equals({GeminationPosition.everywhere}));
    });

    test('everywhere in position set dominates other positions', () {
      // Per D-03 mutual exclusion: if "everywhere" is in the set, it is the only position.
      final result = parseGeminationConstraint('!GG/everywhere,coda');
      expect(result.isValid, isTrue);
      expect(result.constraint!.positions, equals({GeminationPosition.everywhere}));
    });
  });

  group('GeminationConstraint.toSource', () {
    test('everywhere serializes to !GG', () {
      final c = GeminationConstraint(
        positions: {GeminationPosition.everywhere},
        source: '!GG',
      );
      expect(c.toSource(), equals('!GG'));
    });

    test('single position serializes correctly', () {
      final c = GeminationConstraint(
        positions: {GeminationPosition.coda},
        source: '!GG/coda',
      );
      expect(c.toSource(), equals('!GG/coda'));
    });

    test('multiple positions serialize correctly', () {
      final c = GeminationConstraint(
        positions: {GeminationPosition.onset, GeminationPosition.initial},
        source: '!GG/onset,initial',
      );
      // Positions may be in any order in the serialized form, so check both.
      final src = c.toSource();
      expect(src, startsWith('!GG/'));
      expect(src, contains('onset'));
      expect(src, contains('initial'));
    });

    test('round-trip: toSource -> parse -> toSource is stable', () {
      const inputs = ['!GG', '!GG/coda', '!GG/onset', '!GG/final', '!GG/initial'];
      for (final input in inputs) {
        final parsed = parseGeminationConstraint(input);
        expect(parsed.isValid, isTrue, reason: 'Should parse: $input');
        final reserialized = parsed.constraint!.toSource();
        final reparsed = parseGeminationConstraint(reserialized);
        expect(reparsed.isValid, isTrue, reason: 'Re-parse should succeed: $reserialized');
        expect(
          reparsed.constraint!.positions,
          equals(parsed.constraint!.positions),
          reason: 'Round-trip positions should match for $input',
        );
      }
    });
  });

  group('serializeGeminationPositions / deserializeGeminationPositions', () {
    test('everywhere round-trips', () {
      final positions = {GeminationPosition.everywhere};
      final serialized = serializeGeminationPositions(positions);
      expect(deserializeGeminationPositions(serialized), equals(positions));
    });

    test('coda round-trips', () {
      final positions = {GeminationPosition.coda};
      final serialized = serializeGeminationPositions(positions);
      expect(deserializeGeminationPositions(serialized), equals(positions));
    });

    test('multiple positions round-trip', () {
      final positions = {GeminationPosition.coda, GeminationPosition.onset};
      final serialized = serializeGeminationPositions(positions);
      expect(deserializeGeminationPositions(serialized), equals(positions));
    });

    test('final_ serializes as "final"', () {
      final serialized = serializeGeminationPositions({GeminationPosition.final_});
      expect(serialized, equals('final'));
    });

    test('deserialize "final" gives final_', () {
      final positions = deserializeGeminationPositions('final');
      expect(positions, equals({GeminationPosition.final_}));
    });

    test('empty string returns everywhere', () {
      // An empty string should return the default (everywhere).
      final positions = deserializeGeminationPositions('');
      expect(positions, equals({GeminationPosition.everywhere}));
    });
  });

  // ---------------------------------------------------------------------------
  // WordGenerator gemination detection tests (Task 2)
  // ---------------------------------------------------------------------------

  group('WordGenerator gemination detection', () {
    late WordGenerator generator;
    late PhonemeInventory inventory;

    setUp(() {
      generator = WordGenerator();
      inventory = const PhonemeInventory(
        consonants: ['k', 'p', 't', 'n', 'm', 's'],
        vowels: ['a', 'i', 'u'],
        naturalClasses: {},
      );
    });

    test('detects "kk" as gemination violation when everywhere constraint active', () {
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.everywhere},
        source: '!GG',
      );
      final result = generator.validateWord(
        word: 'kka',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
      expect(result.violations.first.ruleDescription, contains('gemination'));
    });

    test('allows "kk" when only coda restricted and "kk" is word-initial', () {
      // "kka" — the "kk" is at word start (onset), not coda.
      // Coda restriction should NOT fire here.
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.coda},
        source: '!GG/coda',
      );
      final result = generator.validateWord(
        word: 'kka',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isTrue);
    });

    test('flags "kk" at word-final position when final_ restricted', () {
      // "akk" — the "kk" is at word end.
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.final_},
        source: '!GG/final',
      );
      final result = generator.validateWord(
        word: 'akk',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isFalse);
      expect(result.violations.first.ruleDescription, contains('gemination'));
    });

    test('generateWords filters out words with geminates when constraint active', () {
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.everywhere},
        source: '!GG',
      );
      // Use a template that might produce geminates: CC + V
      // We'll test that no generated word has adjacent identical consonants.
      final templates = [
        parseSyllableTemplate('CCV'),
        parseSyllableTemplate('CV'),
      ];
      final generated = generator.generateWords(
        templates: templates,
        inventory: inventory,
        count: 50,
        geminationConstraints: [gemConstraint],
      );
      for (final word in generated) {
        // Check no two adjacent identical consonants.
        final hasGeminate = _hasGeminate(word, inventory.consonants);
        expect(hasGeminate, isFalse, reason: 'Word "$word" should have no geminate');
      }
    });

    test('no false positive on different adjacent consonants like "kt"', () {
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.everywhere},
        source: '!GG',
      );
      final result = generator.validateWord(
        word: 'akta',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      // "kt" is not a geminate — different consonants.
      expect(result.isValid, isTrue);
    });

    test('multi-character phoneme geminates detected (e.g. "t͡ʃt͡ʃ")', () {
      final inventoryWithAffricate = const PhonemeInventory(
        consonants: ['t͡ʃ', 'k', 'p'],
        vowels: ['a', 'i'],
        naturalClasses: {},
      );
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.everywhere},
        source: '!GG',
      );
      final result = generator.validateWord(
        word: 't͡ʃt͡ʃa',
        constraints: const [],
        inventory: inventoryWithAffricate,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isFalse);
      expect(result.violations, isNotEmpty);
    });

    test('initial gemination constraint flags "kk" at word start', () {
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.initial},
        source: '!GG/initial',
      );
      // "kka" has geminate at initial position.
      final result = generator.validateWord(
        word: 'kka',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isFalse);
    });

    test('onset gemination constraint flags "kka" (geminate starts onset)', () {
      final gemConstraint = GeminationConstraint(
        positions: {GeminationPosition.onset},
        source: '!GG/onset',
      );
      // "kka" — geminate at word start (onset context).
      final result = generator.validateWord(
        word: 'kka',
        constraints: const [],
        inventory: inventory,
        geminationConstraints: [gemConstraint],
      );
      expect(result.isValid, isFalse);
    });
  });
}

/// Helper: check if any adjacent identical consonants exist in a tokenized word.
bool _hasGeminate(String word, List<String> consonants) {
  final consonantSet = consonants.toSet();
  // Greedy tokenize using consonants (longest first).
  final sorted = consonantSet.toList()..sort((a, b) => b.length.compareTo(a.length));
  final tokens = <String>[];
  var i = 0;
  while (i < word.length) {
    String? matched;
    for (final c in sorted) {
      if (word.startsWith(c, i)) {
        matched = c;
        break;
      }
    }
    tokens.add(matched ?? word[i]);
    i += matched?.length ?? 1;
  }

  for (var j = 0; j < tokens.length - 1; j++) {
    if (tokens[j] == tokens[j + 1] && consonantSet.contains(tokens[j])) {
      return true;
    }
  }
  return false;
}
