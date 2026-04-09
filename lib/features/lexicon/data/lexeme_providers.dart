import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import 'lexeme_dao.dart';

// ---------------------------------------------------------------------------
// DAO provider
// ---------------------------------------------------------------------------

/// Returns the [LexemeDao] for the currently open project database, or
/// null when no project is open.
///
/// Uses a plain [Provider] (not riverpod_generator) to avoid build_runner
/// type-traversal issues with Drift-generated types (established project
/// convention — see STATE.md decision 01-05).
final lexemeDaoProvider = Provider<LexemeDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.lexemeDao;
});

// ---------------------------------------------------------------------------
// Lexeme list providers
// ---------------------------------------------------------------------------

/// Watches all root lexemes (rootId IS NULL) for the current project.
///
/// Emits an empty list when no project is open.
final rootLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchRoots();
});

/// Watches ALL lexemes (roots + derived forms) for the current project.
///
/// Used for derived-word search (D-11): when a derived form matches the query,
/// its root is bubbled up into the filtered results.
final allLexemeListProvider = StreamProvider<List<Lexeme>>((ref) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllLexemes();
});

// ---------------------------------------------------------------------------
// Filter state providers
// ---------------------------------------------------------------------------

/// Notifier backing [lexemeSearchQueryProvider].
///
/// StateProvider was removed in flutter_riverpod 3.x — use NotifierProvider.
class _LexemeSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  /// Updates the search query.
  void set(String value) => state = value;
}

/// The current search query string entered by the user.
///
/// An empty string means "no filter" — all roots are shown.
final lexemeSearchQueryProvider =
    NotifierProvider<_LexemeSearchQuery, String>(_LexemeSearchQuery.new);

/// Notifier backing [lexemePosFilterProvider].
class _LexemePosFilter extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  /// Replaces the current POS filter set.
  void set(Set<String> value) => state = value;

  /// Toggles a single POS value in the filter.
  void toggle(String pos) {
    final current = Set<String>.from(state);
    if (current.contains(pos)) {
      current.remove(pos);
    } else {
      current.add(pos);
    }
    state = current;
  }
}

/// The current POS filter set. An empty set means "no POS filter".
///
/// When non-empty, only roots whose [partOfSpeech] is in this set are shown.
final lexemePosFilterProvider =
    NotifierProvider<_LexemePosFilter, Set<String>>(_LexemePosFilter.new);

// ---------------------------------------------------------------------------
// Filtered lexeme provider (client-side, D-09 decision: <10k words)
// ---------------------------------------------------------------------------

/// Provides a filtered + sorted list of root lexemes based on the current
/// search query and POS filter.
///
/// Filter logic:
/// 1. IPA substring match on root
/// 2. Romanization substring match on root
/// 3. Meaning substring match on root
/// 4. Derived-form match: if a derived form (child) matches, include the root
///    (D-11 requirement — see 03-CONTEXT.md)
/// 5. POS exact match (when posFilter is non-empty)
final filteredLexemeListProvider = Provider<List<Lexeme>>((ref) {
  final roots = ref.watch(rootLexemeListProvider).asData?.value ?? [];
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  final query = ref.watch(lexemeSearchQueryProvider).toLowerCase();
  final posFilter = ref.watch(lexemePosFilterProvider);

  // Collect root IDs of derived forms that match the query (D-11).
  final derivedMatchRootIds = <String>{};
  if (query.isNotEmpty) {
    for (final l in allLexemes) {
      if (l.rootId != null) {
        final matchesIpa = l.ipa.toLowerCase().contains(query);
        final matchesRom = l.romanization?.toLowerCase().contains(query) ?? false;
        final matchesMeaning = l.meaning?.toLowerCase().contains(query) ?? false;
        if (matchesIpa || matchesRom || matchesMeaning) {
          derivedMatchRootIds.add(l.rootId!);
        }
      }
    }
  }

  return roots.where((l) {
    final matchesQuery = query.isEmpty ||
        l.ipa.toLowerCase().contains(query) ||
        (l.romanization?.toLowerCase().contains(query) ?? false) ||
        (l.meaning?.toLowerCase().contains(query) ?? false) ||
        derivedMatchRootIds.contains(l.id.toString());
    final matchesPos = posFilter.isEmpty ||
        (l.partOfSpeech != null && posFilter.contains(l.partOfSpeech));
    return matchesQuery && matchesPos;
  }).toList();
});

// ---------------------------------------------------------------------------
// Derived search matches provider (for highlighting in detail panel)
// ---------------------------------------------------------------------------

/// Returns the IDs of derived forms (non-root lexemes) whose IPA, romanization,
/// or meaning matches the current search query.
///
/// Used by the word detail panel to highlight which derived forms triggered a
/// search match (plan 03-02 consumer).
final derivedSearchMatchesProvider = Provider<Set<int>>((ref) {
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  final query = ref.watch(lexemeSearchQueryProvider).toLowerCase();
  if (query.isEmpty) return {};
  return allLexemes
      .where((l) =>
          l.rootId != null &&
          (l.ipa.toLowerCase().contains(query) ||
              (l.romanization?.toLowerCase().contains(query) ?? false) ||
              (l.meaning?.toLowerCase().contains(query) ?? false)))
      .map((l) => l.id)
      .toSet();
});
