import 'package:conlang_workbench/features/culture/domain/page_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PageHistory', () {
    late PageHistory history;

    setUp(() {
      history = PageHistory();
    });

    // Test 1: push(1), push(2) -> canGoBack=true, canGoForward=false
    test('push two pages: canGoBack=true, canGoForward=false', () {
      history.push(1);
      history.push(2);
      expect(history.canGoBack, isTrue);
      expect(history.canGoForward, isFalse);
      expect(history.currentPageId, equals(2));
    });

    // Test 2: push(1), push(2), goBack() returns 1, canGoForward=true
    test('goBack returns previous page and enables canGoForward', () {
      history.push(1);
      history.push(2);
      final result = history.goBack();
      expect(result, equals(1));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isTrue);
      expect(history.currentPageId, equals(1));
    });

    // Test 3: push(1), push(2), goBack(), goForward() returns 2
    test('goForward returns next page after going back', () {
      history.push(1);
      history.push(2);
      history.goBack();
      final result = history.goForward();
      expect(result, equals(2));
      expect(history.canGoForward, isFalse);
      expect(history.currentPageId, equals(2));
    });

    // Test 4: push(1), push(2), goBack(), push(3) clears forward stack -> canGoForward=false
    test('push after going back clears forward history', () {
      history.push(1);
      history.push(2);
      history.goBack();
      history.push(3);
      expect(history.canGoForward, isFalse);
      expect(history.currentPageId, equals(3));
    });

    // Test 5: fresh history -> canGoBack=false, canGoForward=false
    test('fresh history has canGoBack=false and canGoForward=false', () {
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
      expect(history.currentPageId, isNull);
    });

    // Test 6: push(1), goBack() at start returns null
    test('goBack at start of history returns null', () {
      history.push(1);
      final result = history.goBack();
      expect(result, isNull);
      expect(history.currentPageId, equals(1));
    });
  });
}
