import 'package:flutter_test/flutter_test.dart';
import 'package:conlang_workbench/features/glossary/domain/glossary_entry.dart';

void main() {
  group('GlossaryEntry.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'term': 'phoneme',
        'category': 'Phonology',
        'definition': 'The smallest unit of sound that distinguishes meaning.',
        'seeAlso': ['allophone', 'phonological rule'],
      };
      final entry = GlossaryEntry.fromJson(json);
      expect(entry.term, 'phoneme');
      expect(entry.category, 'Phonology');
      expect(entry.definition,
          'The smallest unit of sound that distinguishes meaning.');
      expect(entry.seeAlso, ['allophone', 'phonological rule']);
    });

    test('defaults seeAlso to empty list when key is absent', () {
      final json = {
        'term': 'morpheme',
        'category': 'Morphology',
        'definition': 'The smallest meaningful unit in a language.',
      };
      final entry = GlossaryEntry.fromJson(json);
      expect(entry.seeAlso, isEmpty);
    });

    test('parses empty seeAlso list', () {
      final json = {
        'term': 'syntax',
        'category': 'Syntax',
        'definition': 'The study of sentence structure.',
        'seeAlso': <String>[],
      };
      final entry = GlossaryEntry.fromJson(json);
      expect(entry.seeAlso, isEmpty);
    });
  });
}
