import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/glossary_entry.dart';

// ---------------------------------------------------------------------------
// Raw data provider
// ---------------------------------------------------------------------------

/// Loads and parses the glossary from the bundled JSON asset.
///
/// Returns a list of [GlossaryEntry] objects covering linguistic terminology
/// across Phonology, Morphology, Syntax, Semantics, and Typology.
final glossaryProvider = FutureProvider<List<GlossaryEntry>>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/glossary.json');
  final jsonList = json.decode(jsonStr) as List<dynamic>;
  return jsonList
      .map((e) => GlossaryEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// UI state providers
// ---------------------------------------------------------------------------

/// Notifier backing [glossaryOpenProvider].
///
/// StateProvider was removed in flutter_riverpod 3.x — use NotifierProvider.
class _GlossaryOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

/// Controls whether the glossary drawer/panel is open.
///
/// Set via `ref.read(glossaryOpenProvider.notifier).state = true`.
final glossaryOpenProvider = NotifierProvider<_GlossaryOpenNotifier, bool>(
  _GlossaryOpenNotifier.new,
);

/// Notifier backing [glossarySearchProvider].
class _GlossarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';
}

/// The current search query text for glossary filtering.
///
/// Set via `ref.read(glossarySearchProvider.notifier).state = query`.
final glossarySearchProvider =
    NotifierProvider<_GlossarySearchNotifier, String>(
  _GlossarySearchNotifier.new,
);

/// Notifier backing [glossaryCategoryFilterProvider].
class _GlossaryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

/// The active category filter, or null for no category restriction.
///
/// Set via `ref.read(glossaryCategoryFilterProvider.notifier).state = 'Phonology'`.
final glossaryCategoryFilterProvider =
    NotifierProvider<_GlossaryCategoryFilterNotifier, String?>(
  _GlossaryCategoryFilterNotifier.new,
);

// ---------------------------------------------------------------------------
// Filtered results provider
// ---------------------------------------------------------------------------

/// Returns a filtered list of [GlossaryEntry] based on the current search
/// query and category filter.
///
/// - Search matches are case-insensitive substring checks against both
///   [GlossaryEntry.term] and [GlossaryEntry.definition].
/// - Category filter is an exact match on [GlossaryEntry.category].
/// - Both filters are applied with AND logic.
/// - Returns all entries when search is empty and category is null.
final filteredGlossaryProvider = Provider<List<GlossaryEntry>>((ref) {
  final entries = ref.watch(glossaryProvider).asData?.value ?? [];
  final query = ref.watch(glossarySearchProvider).toLowerCase();
  final category = ref.watch(glossaryCategoryFilterProvider);

  return entries.where((entry) {
    final matchesSearch = query.isEmpty ||
        entry.term.toLowerCase().contains(query) ||
        entry.definition.toLowerCase().contains(query);
    final matchesCategory = category == null || entry.category == category;
    return matchesSearch && matchesCategory;
  }).toList();
});
