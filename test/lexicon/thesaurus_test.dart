import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conlang_workbench/features/lexicon/data/semantic_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helper: pure search filter logic mirroring ThesaurusPage._matchesSearch
  // ---------------------------------------------------------------------------

  /// Returns true if [category] or any of its descendants contains [query]
  /// (case-insensitive) in their name or concepts.
  bool categoryMatchesSearch(ThesaurusCategory category, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (category.name.toLowerCase().contains(q)) return true;
    if (category.concepts.any((c) => c.toLowerCase().contains(q))) return true;
    return category.subcategories.any((sub) => categoryMatchesSearch(sub, q));
  }

  // ---------------------------------------------------------------------------
  // JSON parsing tests
  // ---------------------------------------------------------------------------

  group('ThesaurusCategory.fromJson', () {
    test('parses leaf category with concepts', () {
      final cat = ThesaurusCategory.fromJson({
        'name': 'Cosmology',
        'concepts': ['sky', 'sun', 'moon'],
      });
      expect(cat.name, 'Cosmology');
      expect(cat.concepts, containsAll(['sky', 'sun', 'moon']));
      expect(cat.subcategories, isEmpty);
    });

    test('parses container category with subcategories', () {
      final cat = ThesaurusCategory.fromJson({
        'name': 'The Physical World',
        'subcategories': [
          {'name': 'Cosmology', 'concepts': ['sky']},
          {'name': 'Weather', 'concepts': ['rain']},
        ],
      });
      expect(cat.name, 'The Physical World');
      expect(cat.subcategories.length, 2);
      expect(cat.subcategories[0].name, 'Cosmology');
      expect(cat.subcategories[1].name, 'Weather');
    });

    test('handles missing subcategories gracefully', () {
      final cat = ThesaurusCategory.fromJson({'name': 'Empty'});
      expect(cat.subcategories, isEmpty);
      expect(cat.concepts, isEmpty);
    });

    test('parses nested three-level hierarchy', () {
      final cat = ThesaurusCategory.fromJson({
        'name': 'Root',
        'subcategories': [
          {
            'name': 'Level1',
            'subcategories': [
              {'name': 'Level2', 'concepts': ['deep concept']},
            ],
          }
        ],
      });
      expect(cat.subcategories[0].subcategories[0].name, 'Level2');
      expect(
          cat.subcategories[0].subcategories[0].concepts, ['deep concept']);
    });
  });

  // ---------------------------------------------------------------------------
  // Asset loading tests
  // ---------------------------------------------------------------------------

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

    test('all top-level categories have non-empty names', () async {
      final jsonStr =
          await rootBundle.loadString('assets/conlangers_thesaurus.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      final categories = (jsonData['categories'] as List<dynamic>)
          .map((e) =>
              ThesaurusCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final cat in categories) {
        expect(cat.name, isNotEmpty,
            reason: 'Every top-level category must have a name');
      }
    });

    test('top-level categories have subcategories or concepts', () async {
      final jsonStr =
          await rootBundle.loadString('assets/conlangers_thesaurus.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      final categories = (jsonData['categories'] as List<dynamic>)
          .map((e) =>
              ThesaurusCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      // At least some categories should have subcategories.
      final hasSubcategories =
          categories.any((c) => c.subcategories.isNotEmpty);
      expect(hasSubcategories, isTrue,
          reason: 'Thesaurus should have hierarchical structure');
    });
  });

  // ---------------------------------------------------------------------------
  // Search filtering logic tests
  // ---------------------------------------------------------------------------

  group('thesaurus search filtering', () {
    late ThesaurusCategory root;

    setUp(() {
      root = ThesaurusCategory.fromJson({
        'name': 'The Physical World',
        'subcategories': [
          {
            'name': 'Cosmology',
            'concepts': ['sky', 'sun', 'moon', 'star'],
          },
          {
            'name': 'Weather',
            'concepts': ['rain', 'snow', 'wind'],
          },
        ],
      });
    });

    test('empty query matches everything', () {
      expect(categoryMatchesSearch(root, ''), isTrue);
    });

    test('query matching top-level name returns true', () {
      expect(categoryMatchesSearch(root, 'Physical'), isTrue);
    });

    test('query matching subcategory name returns true', () {
      expect(categoryMatchesSearch(root, 'Cosmology'), isTrue);
    });

    test('query matching a leaf concept returns true', () {
      expect(categoryMatchesSearch(root, 'sky'), isTrue);
      expect(categoryMatchesSearch(root, 'rain'), isTrue);
    });

    test('query not matching anything returns false', () {
      expect(categoryMatchesSearch(root, 'xylophone'), isFalse);
    });

    test('search is case-insensitive', () {
      expect(categoryMatchesSearch(root, 'SKY'), isTrue);
      expect(categoryMatchesSearch(root, 'COSMOLOGY'), isTrue);
    });

    test('partial match on concept works', () {
      expect(categoryMatchesSearch(root, 'sno'), isTrue); // matches "snow"
    });

    test('non-matching category is filtered out', () {
      // Cosmology matches "sky", Weather does not match "sky"
      final weatherCat = root.subcategories[1];
      expect(categoryMatchesSearch(weatherCat, 'sky'), isFalse);
    });
  });
}
