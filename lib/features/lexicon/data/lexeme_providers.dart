import 'package:flutter_riverpod/flutter_riverpod.dart';

// `MorphologicalRule` is also defined by the Drift-generated row class in
// app_database.dart; hide that one so unqualified `MorphologicalRule`
// references in this file resolve to the domain type from morphology_dsl,
// which is what the MorphologyEngine API expects. The Drift row was never
// used in this file anyway — only `MorphologicalRuleException` is.
import '../../../db/app_database.dart' hide MorphologicalRule;
import '../../morphology/data/morphology_providers.dart';
import '../../morphology/domain/morphology_dsl.dart';
import '../../morphology/domain/morphology_engine.dart';
import '../../phonology/data/phonotactic_providers.dart';
import 'phonotactic_validation_provider.dart';
import '../../phonology/domain/word_generator.dart';
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
/// 4. Derived-form match: if ANY derived form of this root (either stored as
///    a child lexeme OR computed on-the-fly by [MorphologyEngine]) matches
///    the query, include the root (D-11 requirement — see 03-CONTEXT.md).
///    Previously this only checked stored derived lexemes, but derivations
///    are computed on demand by [computedDerivedFormsProvider], so stored
///    children are rare. Without the on-the-fly path, searching a substring
///    that only appears in a derived form never surfaced the root.
/// 5. POS exact match (when posFilter is non-empty)
final filteredLexemeListProvider = Provider<List<Lexeme>>((ref) {
  final roots = ref.watch(rootLexemeListProvider).asData?.value ?? [];
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  final query = ref.watch(lexemeSearchQueryProvider).toLowerCase();
  final posFilter = ref.watch(lexemePosFilterProvider);

  // Collect root IDs whose stored derived children match the query (legacy
  // path — keeps working for any manually-inserted derived lexemes).
  final derivedMatchRootIds = <String>{};
  if (query.isNotEmpty) {
    for (final l in allLexemes) {
      if (l.rootId != null) {
        final matchesIpa = l.ipa.toLowerCase().contains(query);
        final matchesRom =
            l.romanization?.toLowerCase().contains(query) ?? false;
        final matchesMeaning =
            l.meaning?.toLowerCase().contains(query) ?? false;
        if (matchesIpa || matchesRom || matchesMeaning) {
          derivedMatchRootIds.add(l.rootId!);
        }
      }
    }
  }

  // Compute-on-the-fly derivation match: for each root, apply all active
  // morphological rules and check the resulting forms against the query.
  // Built once per provider rebuild and reused across the where() below so
  // we don't recompute derivations per filter iteration. Keyed by root id.
  final computedDerivedMatchRootIds = <int>{};
  if (query.isNotEmpty) {
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final dbRules = rulesAsync.asData?.value ?? [];
    final activeRules = <MorphologicalRule>[];
    for (final r in dbRules) {
      if (!r.isActive) continue;
      final parsed = parseMorphDsl(r.source, id: r.id, name: r.name);
      if (parsed.isValid && parsed.rule != null) {
        activeRules.add(parsed.rule!);
      }
    }
    if (activeRules.isNotEmpty) {
      final inventory = ref.watch(phonemeInventoryProvider);
      const engine = MorphologyEngine();
      for (final root in roots) {
        for (final rule in activeRules) {
          final result = engine.applyRule(rule, root.ipa, inventory);
          if (result case MorphSuccess(:final form)) {
            if (form != root.ipa &&
                form.toLowerCase().contains(query)) {
              computedDerivedMatchRootIds.add(root.id);
              break; // one match is enough — skip remaining rules for root
            }
          }
        }
      }
    }
  }

  return roots.where((l) {
    final matchesQuery = query.isEmpty ||
        l.ipa.toLowerCase().contains(query) ||
        (l.romanization?.toLowerCase().contains(query) ?? false) ||
        (l.meaning?.toLowerCase().contains(query) ?? false) ||
        derivedMatchRootIds.contains(l.id.toString()) ||
        computedDerivedMatchRootIds.contains(l.id);
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

// ---------------------------------------------------------------------------
// Single lexeme by ID provider
// ---------------------------------------------------------------------------

/// Watches a single lexeme by its ID.
///
/// Emits null when not found or no project is open.
final lexemeByIdProvider =
    StreamProvider.family<Lexeme?, int>((ref, lexemeId) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value(null);
  return dao.watchAllLexemes().map(
        (list) => list.where((l) => l.id == lexemeId).firstOrNull,
      );
});

// ---------------------------------------------------------------------------
// Exceptions for lexeme provider
// ---------------------------------------------------------------------------

/// Watches morphological rule exceptions for a specific lexeme.
///
/// Emits an empty list when no project is open.
final exceptionsForLexemeProvider = StreamProvider.family<
    List<MorphologicalRuleException>, int>((ref, lexemeId) {
  final dao = ref.watch(lexemeDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchExceptionsForLexeme(lexemeId);
});

// ---------------------------------------------------------------------------
// On-the-fly derivation provider (LEX-02 core)
// ---------------------------------------------------------------------------

/// Result of applying a single morphological rule to a root word.
class DerivedFormResult {
  const DerivedFormResult({
    required this.ruleName,
    required this.ruleId,
    required this.derivedIpa,
    required this.ruleSource,
  });

  final String ruleName;
  final int ruleId;
  final String derivedIpa;
  final String ruleSource;
}

/// Computes derived forms for a root word on-the-fly by applying all active
/// morphological rules via [MorphologyEngine]. No stored data needed —
/// derivations are live from the engine.
///
/// Returns a list of [DerivedFormResult] for each rule that matched and
/// produced a different form (i.e. the derivation actually changed the word).
///
/// Provider is cached by Riverpod and recomputed only when rules or the
/// phoneme inventory change, preventing unnecessary work (T-03-05 mitigation).
final computedDerivedFormsProvider =
    Provider.family<List<DerivedFormResult>, String>((ref, rootIpa) {
  final rulesAsync = ref.watch(morphologicalRuleListProvider);
  final dbRules = rulesAsync.asData?.value ?? [];
  final inventory = ref.watch(phonemeInventoryProvider);

  const engine = MorphologyEngine();
  final results = <DerivedFormResult>[];

  for (final dbRule in dbRules) {
    if (!dbRule.isActive) continue;
    final parsed =
        parseMorphDsl(dbRule.source, id: dbRule.id, name: dbRule.name);
    if (!parsed.isValid || parsed.rule == null) continue;
    final result = engine.applyRule(parsed.rule!, rootIpa, inventory);
    if (result case MorphSuccess(:final form)) {
      if (form != rootIpa) {
        results.add(DerivedFormResult(
          ruleName: dbRule.name,
          ruleId: dbRule.id,
          derivedIpa: form,
          ruleSource: dbRule.source,
        ));
      }
    }
  }
  return results;
});

// ---------------------------------------------------------------------------
// Batch phonotactic violation provider (PHON-05)
// ---------------------------------------------------------------------------

/// Maps lexeme IDs to their phonotactic validation results.
///
/// Only includes lexemes that are NOT marked as phonological exceptions.
/// Only recomputes when lexemes or phonotactic constraints change (Riverpod
/// caching handles T-03-12 DoS mitigation — O(word_length * constraint_count)
/// per word, acceptable for <10k words).
///
/// Used by word list rendering to show wavy violation underlines without
/// calling the validator per-widget.
final lexemeViolationsProvider = Provider<Map<int, ValidationResult>>((ref) {
  final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];
  final validate = ref.watch(phonotacticValidatorProvider);
  return {
    for (final l in allLexemes)
      if (!l.isPhonologicalException) l.id: validate(word: l.ipa),
  };
});
