import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import 'lexeme_providers.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Represents a single Swadesh list concept.
class SwadeshItem {
  final int id;
  final String concept;
  final String category;

  const SwadeshItem({
    required this.id,
    required this.concept,
    required this.category,
  });

  factory SwadeshItem.fromJson(Map<String, dynamic> json) => SwadeshItem(
        id: json['id'] as int,
        concept: json['concept'] as String,
        category: json['category'] as String,
      );
}

/// Represents a node in the Conlanger's Thesaurus hierarchy.
///
/// A node may be a container (has [subcategories]) or a leaf (has [concepts]),
/// or both.
class ThesaurusCategory {
  final String name;
  final List<ThesaurusCategory> subcategories;
  final List<String> concepts;

  const ThesaurusCategory({
    required this.name,
    this.subcategories = const [],
    this.concepts = const [],
  });

  factory ThesaurusCategory.fromJson(Map<String, dynamic> json) =>
      ThesaurusCategory(
        name: json['name'] as String,
        subcategories: (json['subcategories'] as List<dynamic>?)
                ?.map((e) =>
                    ThesaurusCategory.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        concepts: (json['concepts'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

// ---------------------------------------------------------------------------
// Swadesh providers
// ---------------------------------------------------------------------------

/// Loads and parses the Swadesh list from the bundled JSON asset.
///
/// Returns a list of 207 [SwadeshItem] objects.
final swadeshListProvider = FutureProvider<List<SwadeshItem>>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/swadesh_list.json');
  final jsonList = json.decode(jsonStr) as List<dynamic>;
  return jsonList
      .map((e) => SwadeshItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Computes a coverage map from Swadesh concept id to the matching [Lexeme],
/// or null if uncovered.
///
/// Matching is case-insensitive on [Lexeme.meaning] vs [SwadeshItem.concept].
final swadeshCoverageProvider = Provider<Map<int, Lexeme?>>((ref) {
  final swadesh = ref.watch(swadeshListProvider).asData?.value ?? [];
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];

  final meaningMap = <String, Lexeme>{};
  for (final l in allLexemes) {
    if (l.meaning != null && l.meaning!.isNotEmpty) {
      meaningMap[l.meaning!.toLowerCase()] = l;
    }
  }

  final coverage = <int, Lexeme?>{};
  for (final item in swadesh) {
    coverage[item.id] = meaningMap[item.concept.toLowerCase()];
  }
  return coverage;
});

// ---------------------------------------------------------------------------
// Thesaurus provider
// ---------------------------------------------------------------------------

/// Loads and parses the Conlanger's Thesaurus from the bundled JSON asset.
///
/// Returns a list of top-level [ThesaurusCategory] objects. Each category
/// may contain [subcategories] and/or [concepts] recursively.
///
/// Gracefully handles malformed data via [ThesaurusCategory.fromJson]'s
/// empty defaults — max nesting follows the JSON structure (~3 levels).
final thesaurusProvider = FutureProvider<List<ThesaurusCategory>>((ref) async {
  final jsonStr =
      await rootBundle.loadString('assets/conlangers_thesaurus.json');
  final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
  final categories = jsonData['categories'] as List<dynamic>;
  return categories
      .map((e) => ThesaurusCategory.fromJson(e as Map<String, dynamic>))
      .toList();
});
