import 'package:flutter/foundation.dart';

/// Browser-style back/forward page navigation stack.
/// Ephemeral session state — NOT persisted to database.
/// Per D-13: back/forward arrows at top of culture page view.
class PageHistory extends ChangeNotifier {
  final _stack = <int>[];
  int _cursor = -1;

  bool get canGoBack => _cursor > 0;
  bool get canGoForward => _cursor < _stack.length - 1;
  int? get currentPageId => _cursor >= 0 ? _stack[_cursor] : null;

  void push(int pageId) {
    // If already on this page, skip
    if (_cursor >= 0 && _stack[_cursor] == pageId) return;
    // Discard forward history
    if (_cursor < _stack.length - 1) {
      _stack.removeRange(_cursor + 1, _stack.length);
    }
    _stack.add(pageId);
    _cursor = _stack.length - 1;
    notifyListeners();
  }

  int? goBack() {
    if (!canGoBack) return null;
    _cursor--;
    notifyListeners();
    return _stack[_cursor];
  }

  int? goForward() {
    if (!canGoForward) return null;
    _cursor++;
    notifyListeners();
    return _stack[_cursor];
  }
}
