import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conlang_workbench/features/lexicon/data/semantic_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Test helpers for pure logic tests (do not require Flutter binding)
  // ---------------------------------------------------------------------------

  /// Computes Swadesh coverage from a list of concepts and lexeme meanings.
  /// Mirrors swadeshCoverageProvider logic as a pure function for testing.
  Map<int, bool> computeCoverage({
    required List<SwadeshItem> items,
    required List<String> lexemeMeanings,
  }) {
    final meaningSet = lexemeMeanings.map((m) => m.toLowerCase()).toSet();
    return {
      for (final item in items)
        item.id: meaningSet.contains(item.concept.toLowerCase()),
    };
  }

  // ---------------------------------------------------------------------------
  // JSON parsing tests
  // ---------------------------------------------------------------------------

  group('SwadeshItem.fromJson', () {
    test('parses a single item correctly', () {
      final item = SwadeshItem.fromJson({
        'id': 1,
        'concept': 'I',
        'category': 'Pronouns',
      });
      expect(item.id, 1);
      expect(item.concept, 'I');
      expect(item.category, 'Pronouns');
    });

    test('parses a list of items', () {
      const raw =
          '[{"id":1,"concept":"I","category":"Pronouns"},{"id":2,"concept":"you (singular)","category":"Pronouns"}]';
      final items = (jsonDecode(raw) as List<dynamic>)
          .map((e) => SwadeshItem.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(items.length, 2);
      expect(items[0].concept, 'I');
      expect(items[1].concept, 'you (singular)');
    });
  });

  // ---------------------------------------------------------------------------
  // Asset loading tests (requires TestWidgetsFlutterBinding + flutter test)
  // ---------------------------------------------------------------------------

  group('swadesh_list.json asset', () {
    setUpAll(() {
      // Register the assets bundle so rootBundle can load files in tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('loads and parses exactly 207 items', () async {
      final jsonStr =
          await rootBundle.loadString('assets/swadesh_list.json');
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final items = jsonList
          .map((e) => SwadeshItem.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(items.length, 207,
          reason: 'Swadesh list should contain exactly 207 concepts');
    });

    test('all items have non-empty concept and category', () async {
      final jsonStr =
          await rootBundle.loadString('assets/swadesh_list.json');
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final items = jsonList
          .map((e) => SwadeshItem.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final item in items) {
        expect(item.concept, isNotEmpty,
            reason: 'concept should not be empty for id=${item.id}');
        expect(item.category, isNotEmpty,
            reason: 'category should not be empty for id=${item.id}');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Coverage computation logic
  // ---------------------------------------------------------------------------

  group('swadesh coverage computation', () {
    late List<SwadeshItem> items;

    setUp(() {
      items = [
        const SwadeshItem(id: 1, concept: 'I', category: 'Pronouns'),
        const SwadeshItem(id: 2, concept: 'you (singular)', category: 'Pronouns'),
        const SwadeshItem(id: 3, concept: 'fire', category: 'Nature'),
      ];
    });

    test('returns false for all concepts when lexicon is empty', () {
      final coverage = computeCoverage(items: items, lexemeMeanings: []);
      expect(coverage[1], isFalse);
      expect(coverage[2], isFalse);
      expect(coverage[3], isFalse);
    });

    test('returns true for concepts that exactly match a lexeme meaning', () {
      final coverage =
          computeCoverage(items: items, lexemeMeanings: ['I', 'fire']);
      expect(coverage[1], isTrue);
      expect(coverage[2], isFalse);
      expect(coverage[3], isTrue);
    });

    test('matching is case-insensitive', () {
      final coverage =
          computeCoverage(items: items, lexemeMeanings: ['i', 'YOU (SINGULAR)']);
      expect(coverage[1], isTrue);
      expect(coverage[2], isTrue);
    });

    test('counts covered concepts correctly', () {
      final coverage = computeCoverage(
          items: items, lexemeMeanings: ['I', 'you (singular)', 'fire']);
      final coveredCount = coverage.values.where((v) => v).length;
      expect(coveredCount, 3);
    });

    test('full 207-item coverage starts at 0 when lexicon empty', () async {
      final jsonStr =
          await rootBundle.loadString('assets/swadesh_list.json');
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final allItems = jsonList
          .map((e) => SwadeshItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final coverage = computeCoverage(items: allItems, lexemeMeanings: []);
      final coveredCount = coverage.values.where((v) => v).length;
      expect(coveredCount, 0, reason: 'Empty lexicon means 0/207 coverage');
    });
  });

  // ---------------------------------------------------------------------------
  // ThesaurusCategory parsing
  // ---------------------------------------------------------------------------

  group('ThesaurusCategory.fromJson', () {
    test('parses a leaf category with concepts', () {
      final cat = ThesaurusCategory.fromJson({
        'name': 'Cosmology',
        'concepts': ['sky', 'sun', 'moon'],
      });
      expect(cat.name, 'Cosmology');
      expect(cat.concepts, ['sky', 'sun', 'moon']);
      expect(cat.subcategories, isEmpty);
    });

    test('parses nested subcategories', () {
      final cat = ThesaurusCategory.fromJson({
        'name': 'The Physical World',
        'subcategories': [
          {
            'name': 'Cosmology',
            'concepts': ['sky', 'sun'],
          }
        ],
      });
      expect(cat.name, 'The Physical World');
      expect(cat.subcategories.length, 1);
      expect(cat.subcategories[0].name, 'Cosmology');
    });

    test('handles missing subcategories and concepts gracefully', () {
      final cat = ThesaurusCategory.fromJson({'name': 'Empty'});
      expect(cat.name, 'Empty');
      expect(cat.subcategories, isEmpty);
      expect(cat.concepts, isEmpty);
    });
  });

  group('conlangers_thesaurus.json asset', () {
    test('parses into non-empty category tree', () async {
      final jsonStr =
          await rootBundle.loadString('assets/conlangers_thesaurus.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      final categories = (jsonData['categories'] as List<dynamic>)
          .map((e) =>
              ThesaurusCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(categories, isNotEmpty,
          reason: 'Thesaurus should have at least one top-level category');
    });
  });
}
