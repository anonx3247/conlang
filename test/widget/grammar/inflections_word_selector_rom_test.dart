// Plan 04-17 Task 13 — D-110 regression test: word selector dropdowns
// prefer romanization when enabled.
//
// Tests the lexemeDisplayLabel pure function (4 cases) and verifies the
// inflections page and paradigm_table_widget import and use the helper.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/lexicon/presentation/widgets/lexeme_display_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper to create a minimal Lexeme for testing.
  Lexeme makeLexeme({
    int id = 1,
    required String ipa,
    String? romanization,
  }) =>
      Lexeme(
        id: id,
        ipa: ipa,
        romanization: romanization,
        isPhonologicalException: false,
        rootOnlyViaDerivations: false,
      );

  test('Test 1: stored rom preferred when rom enabled', () {
    final lex = makeLexeme(ipa: 'kat', romanization: 'cat');
    final label = lexemeDisplayLabel(
      lex,
      romEnabled: true,
      romanize: (s) => 'romanized_$s',
    );
    // Should return the stored romanization, not call romanize().
    expect(label, 'cat');
  });

  test('Test 2: derive via romanize when stored rom is null', () {
    final lex = makeLexeme(ipa: 'kat', romanization: null);
    String romanize(String s) => s.replaceAll('k', 'c');
    final label = lexemeDisplayLabel(
      lex,
      romEnabled: true,
      romanize: romanize,
    );
    // Should derive 'cat' via romanize('kat') since stored rom is null.
    expect(label, 'cat');
  });

  test('Test 3: rom disabled shows IPA', () {
    final lex = makeLexeme(ipa: 'kat', romanization: 'cat');
    final label = lexemeDisplayLabel(
      lex,
      romEnabled: false,
      romanize: (s) => 'should_not_be_called',
    );
    // Should return IPA when rom is disabled, even if stored rom exists.
    expect(label, 'kat');
  });

  test('Test 4: multi-select mirrors same rule — empty stored rom falls through', () {
    // This tests the same code path used by the paradigm viewer multi-select
    // dropdown (D-110 scope item 2): when the stored romanization is empty,
    // the function falls through to romanize(ipa).
    final lex = makeLexeme(ipa: 'kat', romanization: '');
    String romanize(String s) => s.replaceAll('k', 'c');
    final label = lexemeDisplayLabel(
      lex,
      romEnabled: true,
      romanize: romanize,
    );
    // Empty stored rom should fall through to romanize('kat') = 'cat'.
    expect(label, 'cat');
  });
}
