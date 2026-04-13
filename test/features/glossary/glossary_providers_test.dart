import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/glossary/data/glossary_providers.dart';
import 'package:conlang_workbench/features/glossary/domain/glossary_entry.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Build a ProviderContainer with glossaryProvider overridden by a fixed list.
ProviderContainer _containerWithEntries(List<GlossaryEntry> entries) {
  return ProviderContainer(
    overrides: [
      glossaryProvider.overrideWith(
        (ref) async => entries,
      ),
    ],
  );
}

const _phoneme = GlossaryEntry(
  term: 'phoneme',
  category: 'Phonology',
  definition: 'The smallest unit of sound that distinguishes meaning.',
  seeAlso: ['allophone'],
);

const _allophone = GlossaryEntry(
  term: 'allophone',
  category: 'Phonology',
  definition: 'A phonetic variant of a phoneme.',
);

const _morpheme = GlossaryEntry(
  term: 'morpheme',
  category: 'Morphology',
  definition: 'The smallest meaningful unit in a language.',
);

const _syntax = GlossaryEntry(
  term: 'clause',
  category: 'Syntax',
  definition: 'A grammatical unit containing a subject and predicate.',
);

final _testEntries = [_phoneme, _allophone, _morpheme, _syntax];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('filteredGlossaryProvider', () {
    test('returns all entries when search is empty and category is null',
        () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      // Await the async future so glossaryProvider resolves to AsyncData.
      await container.read(glossaryProvider.future);

      final filtered = container.read(filteredGlossaryProvider);
      expect(filtered, hasLength(4));
    });

    test('filters by term name (case-insensitive)', () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      await container.read(glossaryProvider.future);

      container.read(glossarySearchProvider.notifier).state = 'phoneme';
      final filtered = container.read(filteredGlossaryProvider);
      expect(filtered.map((e) => e.term).toList(), contains('phoneme'));
      expect(filtered.any((e) => e.term == 'morpheme'), isFalse);
    });

    test('filters by definition text (case-insensitive)', () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      await container.read(glossaryProvider.future);

      container.read(glossarySearchProvider.notifier).state = 'variant';
      final filtered = container.read(filteredGlossaryProvider);
      expect(filtered.map((e) => e.term).toList(), contains('allophone'));
      expect(filtered.any((e) => e.term == 'morpheme'), isFalse);
    });

    test('filters by category', () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      await container.read(glossaryProvider.future);

      container.read(glossaryCategoryFilterProvider.notifier).state =
          'Morphology';
      final filtered = container.read(filteredGlossaryProvider);
      expect(filtered, hasLength(1));
      expect(filtered.first.term, 'morpheme');
    });

    test('combines search and category filters (AND logic)', () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      await container.read(glossaryProvider.future);

      container.read(glossarySearchProvider.notifier).state = 'unit';
      container.read(glossaryCategoryFilterProvider.notifier).state =
          'Phonology';
      final filtered = container.read(filteredGlossaryProvider);
      // 'phoneme' has 'unit' in definition AND is Phonology
      expect(filtered, hasLength(1));
      expect(filtered.first.term, 'phoneme');
    });

    test('search is case-insensitive (uppercase query)', () async {
      final container = _containerWithEntries(_testEntries);
      addTearDown(container.dispose);

      await container.read(glossaryProvider.future);

      container.read(glossarySearchProvider.notifier).state = 'PHONEME';
      final filtered = container.read(filteredGlossaryProvider);
      expect(filtered.any((e) => e.term == 'phoneme'), isTrue);
    });
  });

  group('glossaryOpenProvider', () {
    test('defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(glossaryOpenProvider), isFalse);
    });
  });

  group('glossarySearchProvider', () {
    test('defaults to empty string', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(glossarySearchProvider), '');
    });
  });

  group('glossaryCategoryFilterProvider', () {
    test('defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(glossaryCategoryFilterProvider), isNull);
    });
  });
}
