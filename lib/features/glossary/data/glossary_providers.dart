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
class GlossaryOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Opens the glossary drawer.
  void open() => state = true;

  /// Closes the glossary drawer.
  void close() => state = false;

  /// Toggles the glossary drawer open/closed.
  void toggle() => state = !state;
}

/// Controls whether the glossary drawer/panel is open.
///
/// Use `ref.read(glossaryOpenProvider.notifier).open()` /
/// `.close()` / `.toggle()` to mutate.
final glossaryOpenProvider = NotifierProvider<GlossaryOpenNotifier, bool>(
  GlossaryOpenNotifier.new,
);

/// Notifier backing [glossarySearchProvider].
class GlossarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Updates the search query.
  void set(String query) => state = query;

  /// Clears the search query.
  void clear() => state = '';
}

/// The current search query text for glossary filtering.
///
/// Use `ref.read(glossarySearchProvider.notifier).set(query)` to mutate.
final glossarySearchProvider =
    NotifierProvider<GlossarySearchNotifier, String>(
  GlossarySearchNotifier.new,
);

/// Notifier backing [glossaryCategoryFilterProvider].
class GlossaryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Sets the active category filter.
  void set(String? category) => state = category;

  /// Clears the category filter.
  void clear() => state = null;
}

/// The active category filter, or null for no category restriction.
///
/// Use `ref.read(glossaryCategoryFilterProvider.notifier).set('Phonology')`
/// or `.clear()` to mutate.
final glossaryCategoryFilterProvider =
    NotifierProvider<GlossaryCategoryFilterNotifier, String?>(
  GlossaryCategoryFilterNotifier.new,
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
        entry.definition.toLowerCase().contains(query) ||
        entry.example.toLowerCase().contains(query);
    final matchesCategory = category == null || entry.category == category;
    return matchesSearch && matchesCategory;
  }).toList();
});
