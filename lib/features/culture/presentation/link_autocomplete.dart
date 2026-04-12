import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Autocomplete overlay for [[page title]] wiki-link input.
///
/// Per D-09: typing [[ in edit mode opens a dropdown of existing page titles.
/// Uses CompositedTransformFollower + OverlayEntry for precise positioning.
/// Reuses the established TapRegion groupId pattern from IPA keyboard popup
/// (STATE.md decisions 01-08, 01-10) to prevent overlay interaction from
/// triggering block focus-loss / save.
class LinkAutocomplete extends StatefulWidget {
  const LinkAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.pageTitles,
    required this.layerLink,
    required this.tapRegionGroupId,
    required this.onSelected,
  });

  /// The TextEditingController of the block editor TextField.
  final TextEditingController controller;

  /// The FocusNode of the block editor TextField.
  final FocusNode focusNode;

  /// All available page titles for autocomplete suggestions.
  final List<String> pageTitles;

  /// CompositedTransformTarget link for overlay positioning.
  final LayerLink layerLink;

  /// Shared TapRegion groupId — matches the block editor's TapRegion.
  /// Prevents autocomplete taps from triggering block focus-loss.
  final Object tapRegionGroupId;

  /// Called when user selects a page title from the dropdown.
  /// The caller is responsible for inserting [[title]] into the controller.
  final void Function(String title) onSelected;

  @override
  State<LinkAutocomplete> createState() => LinkAutocompleteState();
}

/// Public state class so block_editor.dart can forward key events via GlobalKey.
class LinkAutocompleteState extends State<LinkAutocomplete> {
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      _removeOverlay();
      return;
    }

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);

    // Find the last [[ before cursor that hasn't been closed with ]]
    final lastOpen = textBeforeCursor.lastIndexOf('[[');
    if (lastOpen == -1) {
      _removeOverlay();
      return;
    }

    // Check that there's no ]] between lastOpen and cursor
    final segment = textBeforeCursor.substring(lastOpen);
    if (segment.contains(']]')) {
      _removeOverlay();
      return;
    }

    // Extract the partial query after [[
    final query = segment.substring(2); // after [[

    // Filter titles
    final filtered = query.isEmpty
        ? widget.pageTitles.take(10).toList()
        : widget.pageTitles
            .where((t) => t.toLowerCase().contains(query.toLowerCase()))
            .take(10)
            .toList();

    if (filtered.isEmpty && query.isEmpty) {
      _removeOverlay();
      return;
    }

    setState(() {
      _suggestions = filtered;
      _selectedIndex = 0;
    });

    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _suggestions = [];
  }

  void _selectItem(String title) {
    // Replace the open [[ + partial query with [[title]]
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastOpen = textBeforeCursor.lastIndexOf('[[');
    if (lastOpen == -1) return;

    final textAfterCursor = text.substring(cursorPos);
    final newText =
        '${text.substring(0, lastOpen)}[[$title]]$textAfterCursor';
    final newCursorPos = lastOpen + title.length + 4; // [[ + title + ]]

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    _removeOverlay();
    widget.onSelected(title);

    // Keep focus on the block TextField
    widget.focusNode.requestFocus();
  }

  /// Handle keyboard navigation within the autocomplete list.
  /// Returns true if key was consumed.
  bool handleKeyEvent(KeyEvent event) {
    if (_overlayEntry == null || _suggestions.isEmpty) return false;
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      if (_selectedIndex < _suggestions.length) {
        _selectItem(_suggestions[_selectedIndex]);
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return false; // let escape propagate to block editor for save
    }
    return false;
  }

  Widget _buildOverlay() {
    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformFollower(
      link: widget.layerLink,
      offset: const Offset(0, 24), // below the text field line
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      child: TapRegion(
        groupId: widget.tapRegionGroupId,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          color: colorScheme.surfaceContainer,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 280,
              maxHeight: 240,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No matching pages — press Enter to create',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) {
                      final isSelected = i == _selectedIndex;
                      return InkWell(
                        onTap: () => _selectItem(_suggestions[i]),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _suggestions[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible — it only manages the overlay
    return const SizedBox.shrink();
  }
}
