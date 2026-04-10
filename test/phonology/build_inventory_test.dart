import 'dart:convert';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/phonology/data/phonotactic_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/default_natural_classes.dart';
import 'package:flutter_test/flutter_test.dart';

// Tests for `buildInventory` (the renamed + visibleForTesting helper in
// phonotactic_providers.dart). This is the F-1 fix integration point: the
// function must seed PhonemeInventory.naturalClasses with the 9 default
// classes BEFORE overlaying user-defined classes, so every DSL consumer
// (WordGenerator._resolveClass, morphology_engine.resolvePhonemeClass)
// transparently sees the defaults.

Phoneme _phoneme(int id, String symbol, String type) =>
    Phoneme(id: id, symbol: symbol, type: type);

NaturalClassesData _natClass(int id, String name, List<int> phonemeIds) =>
    NaturalClassesData(
      id: id,
      name: name,
      phonemeIds: jsonEncode(phonemeIds),
    );

NaturalClassesData _malformedNatClass(int id, String name) =>
    NaturalClassesData(
      id: id,
      name: name,
      // Not valid JSON — exercises the try/catch path.
      phonemeIds: 'this-is-not-json',
    );

void main() {
  group('buildInventory defaults merge (F-1 fix)', () {
    test('empty user inventory still has all 9 default classes', () {
      final inv = buildInventory(const [], const [], const []);
      expect(inv.naturalClasses.containsKey('stop'), isTrue);
      expect(inv.naturalClasses.containsKey('nasal'), isTrue);
      expect(inv.naturalClasses.containsKey('fricative'), isTrue);
      expect(inv.naturalClasses.containsKey('liquid'), isTrue);
      expect(inv.naturalClasses.containsKey('rhotic'), isTrue);
      expect(inv.naturalClasses.containsKey('obstruent'), isTrue);
      expect(inv.naturalClasses.containsKey('sonorant'), isTrue);
      expect(inv.naturalClasses.containsKey('approximant'), isTrue);
      expect(inv.naturalClasses.containsKey('affricate'), isTrue);
      // Defensive: no extra keys leaked in from nowhere.
      expect(inv.naturalClasses.length, equals(9));
    });

    test("default 'stop' list matches the catalog exactly", () {
      final inv = buildInventory(const [], const [], const []);
      expect(
        inv.naturalClasses['stop'],
        equals(defaultNaturalClasses['stop']),
      );
    });

    test('keys are lowercased — Stop is not present, stop is', () {
      final inv = buildInventory(const [], const [], const []);
      expect(inv.naturalClasses.containsKey('Stop'), isFalse);
      expect(inv.naturalClasses.containsKey('stop'), isTrue);
    });

    test(
        "user-defined class named 'stop' shadows the default (D-06 precedence)",
        () {
      final consonants = [
        _phoneme(1, 'p', 'consonant'),
        _phoneme(2, 't', 'consonant'),
        _phoneme(3, 'k', 'consonant'),
      ];
      final userStop = _natClass(10, 'stop', [1, 2, 3]);

      final inv = buildInventory(consonants, const [], [userStop]);

      // User class wins — exactly 3 symbols, NOT the default 13.
      expect(inv.naturalClasses['stop'], equals(['p', 't', 'k']));
      expect(inv.naturalClasses['stop']!.length, equals(3));
    });

    test("user class with novel name adds to the map additively", () {
      final consonants = [
        _phoneme(1, 'p', 'consonant'),
        _phoneme(2, 't', 'consonant'),
      ];
      final userClass = _natClass(10, 'myclass', [1, 2]);

      final inv = buildInventory(consonants, const [], [userClass]);

      // User class present.
      expect(inv.naturalClasses['myclass'], equals(['p', 't']));
      // All 9 default keys still present.
      for (final k in defaultNaturalClasses.keys) {
        expect(
          inv.naturalClasses.containsKey(k),
          isTrue,
          reason: "default key '$k' missing after additive merge",
        );
      }
      // Total = 9 defaults + 1 user.
      expect(inv.naturalClasses.length, equals(10));
    });

    test('malformed phonemeIds JSON does not crash, defaults still merge', () {
      final bad = _malformedNatClass(10, 'broken');
      final inv = buildInventory(const [], const [], [bad]);

      // Defaults still there.
      expect(inv.naturalClasses.containsKey('stop'), isTrue);
      expect(
        inv.naturalClasses['stop'],
        equals(defaultNaturalClasses['stop']),
      );
      // Broken class was skipped (not inserted as empty).
      expect(inv.naturalClasses.containsKey('broken'), isFalse);
    });

    test('consonants and vowels remain user-supplied only', () {
      final consonants = [
        _phoneme(1, 'p', 'consonant'),
        _phoneme(2, 't', 'consonant'),
      ];
      final vowels = [
        _phoneme(3, 'a', 'vowel'),
        _phoneme(4, 'i', 'vowel'),
      ];

      final inv = buildInventory(consonants, vowels, const []);

      // Defaults flow through NaturalClasses, NOT through consonants/vowels
      // (see Pitfall 4 in 03.2-RESEARCH.md — the catalog is about DSL class
      // matching, not phoneme-level inventory display).
      expect(inv.consonants, equals(['p', 't']));
      expect(inv.vowels, equals(['a', 'i']));
    });

    test(
        'user class name is case-folded on write (existing convention preserved)',
        () {
      final consonants = [_phoneme(1, 'p', 'consonant')];
      // User enters 'STOP' — still matches default key 'stop' after lowering.
      final userStop = _natClass(10, 'STOP', [1]);

      final inv = buildInventory(consonants, const [], [userStop]);

      expect(inv.naturalClasses['stop'], equals(['p']));
      expect(inv.naturalClasses.containsKey('STOP'), isFalse);
    });
  });
}
