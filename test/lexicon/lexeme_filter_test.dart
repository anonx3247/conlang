import 'package:flutter_test/flutter_test.dart';

import 'package:conlang_workbench/db/app_database.dart';

// ---------------------------------------------------------------------------
// Helper: Build a Lexeme-like data object for testing the filter logic.
// The filter logic is extracted here to avoid needing a full Riverpod
// ProviderContainer setup. We test the pure filter function directly.
// ---------------------------------------------------------------------------

/// Mirrors the filteredLexemeListProvider logic as a pure function for testing.
List<Lexeme> filterLexemes({
  required List<Lexeme> roots,
  required List<Lexeme> allLexemes,
  required String query,
  required Set<String> posFilter,
}) {
  final q = query.toLowerCase();

  // Collect derived match root IDs (D-11: search derived forms to find roots)
  final derivedMatchRootIds = <String>{};
  if (q.isNotEmpty) {
    for (final l in allLexemes) {
      if (l.rootId != null) {
        final matchesIpa = l.ipa.toLowerCase().contains(q);
        final matchesRom = l.romanization?.toLowerCase().contains(q) ?? false;
        final matchesMeaning = l.meaning?.toLowerCase().contains(q) ?? false;
        if (matchesIpa || matchesRom || matchesMeaning) {
          derivedMatchRootIds.add(l.rootId!);
        }
      }
    }
  }

  return roots.where((l) {
    final matchesQuery = q.isEmpty ||
        l.ipa.toLowerCase().contains(q) ||
        (l.romanization?.toLowerCase().contains(q) ?? false) ||
        (l.meaning?.toLowerCase().contains(q) ?? false) ||
        derivedMatchRootIds.contains(l.id.toString());
    final matchesPos = posFilter.isEmpty ||
        (l.partOfSpeech != null && posFilter.contains(l.partOfSpeech));
    return matchesQuery && matchesPos;
  }).toList();
}

/// Helper to build a minimal Lexeme for testing.
Lexeme makeLexeme({
  required int id,
  required String ipa,
  String? romanization,
  String? meaning,
  String? partOfSpeech,
  String? rootId,
}) {
  return Lexeme(
    id: id,
    ipa: ipa,
    romanization: romanization,
    meaning: meaning,
    partOfSpeech: partOfSpeech,
    rootId: rootId,
    ruleIds: null,
    computedForm: null,
    isPhonologicalException: false,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Test 6: filteredLexemeListProvider filters by IPA substring match
  // -------------------------------------------------------------------------
  test('filter by IPA substring match', () {
    final roots = [
      makeLexeme(id: 1, ipa: 'bana', meaning: 'tree'),
      makeLexeme(id: 2, ipa: 'sola', meaning: 'sun'),
      makeLexeme(id: 3, ipa: 'luna', meaning: 'moon'),
    ];

    final result = filterLexemes(
      roots: roots,
      allLexemes: roots,
      query: 'ban',
      posFilter: {},
    );

    expect(result.length, 1);
    expect(result.first.ipa, 'bana');
  });

  // -------------------------------------------------------------------------
  // Test 7: filteredLexemeListProvider filters by meaning substring match
  // -------------------------------------------------------------------------
  test('filter by meaning substring match', () {
    final roots = [
      makeLexeme(id: 1, ipa: 'bana', meaning: 'tree'),
      makeLexeme(id: 2, ipa: 'arbo', meaning: 'great tree'),
      makeLexeme(id: 3, ipa: 'luna', meaning: 'moon'),
    ];

    final result = filterLexemes(
      roots: roots,
      allLexemes: roots,
      query: 'tree',
      posFilter: {},
    );

    expect(result.length, 2);
    expect(result.map((l) => l.ipa).toSet(), {'bana', 'arbo'});
  });

  // -------------------------------------------------------------------------
  // Test 8: filteredLexemeListProvider filters by partOfSpeech exact match
  // -------------------------------------------------------------------------
  test('filter by partOfSpeech exact match', () {
    final roots = [
      makeLexeme(id: 1, ipa: 'bana', meaning: 'tree', partOfSpeech: 'noun'),
      makeLexeme(id: 2, ipa: 'kali', meaning: 'run', partOfSpeech: 'verb'),
      makeLexeme(id: 3, ipa: 'tamo', meaning: 'fast', partOfSpeech: 'adjective'),
    ];

    final result = filterLexemes(
      roots: roots,
      allLexemes: roots,
      query: '',
      posFilter: {'noun'},
    );

    expect(result.length, 1);
    expect(result.first.ipa, 'bana');
  });

  // -------------------------------------------------------------------------
  // Test 9: filteredLexemeListProvider with empty query returns all roots
  // -------------------------------------------------------------------------
  test('empty query with empty posFilter returns all roots', () {
    final roots = [
      makeLexeme(id: 1, ipa: 'bana', meaning: 'tree', partOfSpeech: 'noun'),
      makeLexeme(id: 2, ipa: 'kali', meaning: 'run', partOfSpeech: 'verb'),
    ];

    final result = filterLexemes(
      roots: roots,
      allLexemes: roots,
      query: '',
      posFilter: {},
    );

    expect(result.length, 2);
  });
}
