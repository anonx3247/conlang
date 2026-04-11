import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/pos_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Lexeme _lex(String? pos) => Lexeme(
      id: 1,
      ipa: 'xyz',
      rootId: null,
      ruleIds: null,
      computedForm: null,
      romanization: null,
      meaning: null,
      partOfSpeech: pos,
      isPhonologicalException: false,
      skippedDimensionsJson: null,
      rootOnlyViaDerivations: false,
    );

PartsOfSpeechData _pos(int id, String name, String abbr) =>
    PartsOfSpeechData(id: id, name: name, abbreviation: abbr);

void main() {
  group('posForLexeme', () {
    final noun = _pos(1, 'Noun', 'N');
    final verb = _pos(2, 'Verb', 'V');

    test('empty POS list returns null', () {
      expect(posForLexeme(_lex('noun'), const []), isNull);
    });

    test('null partOfSpeech returns null', () {
      expect(posForLexeme(_lex(null), [noun, verb]), isNull);
    });

    test('empty partOfSpeech string returns null', () {
      expect(posForLexeme(_lex(''), [noun, verb]), isNull);
    });

    test('matches by name (case-insensitive, lowercase input)', () {
      expect(posForLexeme(_lex('noun'), [noun, verb])?.id, equals(1));
    });

    test('matches by name (case-insensitive, uppercase input)', () {
      expect(posForLexeme(_lex('NOUN'), [noun, verb])?.id, equals(1));
    });

    test('matches by abbreviation', () {
      expect(posForLexeme(_lex('N'), [noun, verb])?.id, equals(1));
    });

    test('matches by abbreviation case-insensitive', () {
      expect(posForLexeme(_lex('n'), [noun, verb])?.id, equals(1));
    });

    test('selects the correct POS from a list', () {
      expect(posForLexeme(_lex('Verb'), [noun, verb])?.id, equals(2));
    });

    test('returns null when no match', () {
      expect(posForLexeme(_lex('adjective'), [noun, verb]), isNull);
    });

    test('name match takes precedence over abbreviation match', () {
      final aName = _pos(10, 'V', 'X'); // name == 'V'
      final bAbbr = _pos(20, 'Verb', 'V'); // abbr == 'V'
      // Searching for 'V' must match aName (id=10) via name precedence.
      expect(
        posForLexeme(_lex('V'), [aName, bAbbr])?.id,
        equals(10),
      );
    });

    test('trims whitespace before matching', () {
      expect(posForLexeme(_lex('  Noun  '), [noun, verb])?.id, equals(1));
    });
  });
}
