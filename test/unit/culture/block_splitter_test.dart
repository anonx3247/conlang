import 'package:conlang_workbench/features/culture/domain/block_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitIntoBlocks', () {
    // Test 1: empty string returns ['']
    test('empty string returns single empty string block', () {
      final result = splitIntoBlocks('');
      expect(result, equals(['']));
    });

    // Test 2: content with no headings returns [fullContent]
    test('content with no headings returns single block with full content', () {
      const content = 'Just some text\nwith multiple lines\nno headings here';
      final result = splitIntoBlocks(content);
      expect(result, equals([content]));
    });

    // Test 3: "## Heading\ncontent" returns ["## Heading\ncontent"]
    test('single heading with content returns one block', () {
      const content = '## Heading\ncontent';
      final result = splitIntoBlocks(content);
      expect(result, equals(['## Heading\ncontent']));
    });

    // Test 4: "intro\n## H1\nbody1\n## H2\nbody2" returns ["intro\n", "## H1\nbody1\n", "## H2\nbody2"]
    test('intro plus two headings splits into three blocks', () {
      const content = 'intro\n## H1\nbody1\n## H2\nbody2';
      final result = splitIntoBlocks(content);
      expect(result.length, equals(3));
      expect(result[0], equals('intro\n'));
      expect(result[1], equals('## H1\nbody1\n'));
      expect(result[2], equals('## H2\nbody2'));
    });

    // Test 5: "## H1\n## H2" returns ["## H1\n", "## H2"]
    test('two consecutive headings split into two blocks', () {
      const content = '## H1\n## H2';
      final result = splitIntoBlocks(content);
      expect(result.length, equals(2));
      expect(result[0], equals('## H1\n'));
      expect(result[1], equals('## H2'));
    });

    // Test 6: round-trip — joinBlocks(splitIntoBlocks(original)) == original
    test('round-trip joinBlocks(splitIntoBlocks(x)) == x', () {
      const original = 'intro paragraph\n\n## Section One\nContent here.\n\n## Section Two\nMore content.\n### Subsection\nDeep content.';
      final result = joinBlocks(splitIntoBlocks(original));
      expect(result, equals(original));
    });

    // Test 7: heading inside code fence is NOT split
    test('heading inside code fence is not treated as a block boundary', () {
      const content = 'preamble\n```\n## not a heading\n```\nafter fence';
      final result = splitIntoBlocks(content);
      expect(result.length, equals(1));
      expect(result[0], equals(content));
    });
  });

  group('joinBlocks', () {
    test('joinBlocks of single block returns same string', () {
      expect(joinBlocks(['hello world']), equals('hello world'));
    });

    test('joinBlocks of multiple blocks concatenates them', () {
      expect(joinBlocks(['a\n', '## B\nc']), equals('a\n## B\nc'));
    });

    test('joinBlocks of empty list returns empty string', () {
      expect(joinBlocks([]), equals(''));
    });
  });
}
