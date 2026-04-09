import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ipa_keyboard_popup.dart';

/// A drop-in replacement for [TextField] that adds an on-screen IPA keyboard
/// popup.
///
/// The popup appears when the field gains focus (or when the user taps the
/// small keyboard icon button appended to the field decoration). It is
/// positioned below the field via [OverlayPortal] +
/// [CompositedTransformFollower].
///
/// Tapping an IPA symbol inserts it at the current cursor position while
/// keeping focus on the text field. Regular keyboard input continues to work
/// normally — the popup is supplementary, not exclusive.
///
/// Dismiss the popup by:
/// - Clicking outside the field and popup
/// - Pressing the Escape key
/// - Tapping the close button inside the popup
class IpaTextField extends StatefulWidget {
  const IpaTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.enabled,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.showIpaKeyboard = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Decoration applied to the inner [TextField].
  ///
  /// If null, [InputDecoration] defaults are used. The IPA keyboard icon
  /// button is always appended as a suffix icon regardless of the provided
  /// decoration.
  final InputDecoration? decoration;

  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  /// When false, the IPA keyboard popup is disabled and [IpaTextField]
  /// behaves exactly like a plain [TextField].
  final bool showIpaKeyboard;

  @override
  State<IpaTextField> createState() => _IpaTextFieldState();
}

class _IpaTextFieldState extends State<IpaTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();

  // Shared tap-region group so that clicks inside the popup are not treated
  // as "outside" the TextField, preventing premature popup dismissal.
  final _tapGroupId = Object();

  bool _ownController = false;
  bool _ownFocusNode = false;
  bool _popupVisible = false;

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _controller = TextEditingController();
      _ownController = true;
    } else {
      _controller = widget.controller!;
    }

    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _ownFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(IpaTextField old) {
    super.didUpdateWidget(old);

    // Swap controller if the parent provides a new one
    if (widget.controller != old.controller) {
      if (_ownController) _controller.dispose();
      if (widget.controller == null) {
        _controller = TextEditingController();
        _ownController = true;
      } else {
        _controller = widget.controller!;
        _ownController = false;
      }
    }

    // Swap focus node if the parent provides a new one
    if (widget.focusNode != old.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownFocusNode) _focusNode.dispose();
      if (widget.focusNode == null) {
        _focusNode = FocusNode();
        _ownFocusNode = true;
      } else {
        _focusNode = widget.focusNode!;
        _ownFocusNode = false;
      }
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownController) _controller.dispose();
    if (_ownFocusNode) _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Focus handling
  // ---------------------------------------------------------------------------

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      _showPopup();
    } else {
      // Only hide if nothing inside the popup has focus.
      // We use a short delay so that a tap on a popup button (which briefly
      // removes focus from the text field before calling onTap) does not
      // collapse the popup prematurely.
      Future.microtask(() {
        if (mounted && !_focusNode.hasFocus) {
          _hidePopup();
        }
      });
    }
  }

  void _showPopup() {
    if (!widget.showIpaKeyboard) return;
    if (_popupVisible) return;
    setState(() => _popupVisible = true);
    _overlayController.show();
  }

  void _hidePopup() {
    if (!_popupVisible) return;
    if (_overlayController.isShowing) _overlayController.hide();
    setState(() => _popupVisible = false);
  }

  void _togglePopup() {
    if (_popupVisible) {
      _hidePopup();
    } else {
      // Bring focus back to the text field so typing continues to work.
      _focusNode.requestFocus();
      _showPopup();
    }
  }

  // ---------------------------------------------------------------------------
  // Symbol insertion
  // ---------------------------------------------------------------------------

  void _insertSymbol(String symbol) {
    final text = _controller.text;
    final selection = _controller.selection;

    // If there is no valid selection (e.g., field never focused), append.
    if (!selection.isValid) {
      _controller.text = text + symbol;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } else {
      final before = selection.textBefore(text);
      final after = selection.textAfter(text);
      final newText = before + symbol + after;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: before.length + symbol.length),
      );
    }

    widget.onChanged?.call(_controller.text);

    // Keep focus on the text field so the user can continue typing.
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Merge the IPA keyboard icon into the field's suffix, preserving any
    // suffixIcon the caller already provided (e.g. validation checkmark).
    final baseDecoration = widget.decoration ?? const InputDecoration();
    final callerSuffixIcon = baseDecoration.suffixIcon;

    final keyboardIcon = IconButton(
      icon: Icon(
        _popupVisible ? Icons.keyboard_hide : Icons.keyboard_alt_outlined,
        size: 18,
      ),
      tooltip: _popupVisible ? 'Hide IPA keyboard' : 'Show IPA keyboard',
      onPressed: _togglePopup,
    );

    Widget? mergedSuffixIcon;
    if (widget.showIpaKeyboard) {
      if (callerSuffixIcon != null) {
        // Caller has an icon AND we have the keyboard toggle — show both.
        mergedSuffixIcon = Row(
          mainAxisSize: MainAxisSize.min,
          children: [callerSuffixIcon, keyboardIcon],
        );
      } else {
        mergedSuffixIcon = keyboardIcon;
      }
    }
    // If showIpaKeyboard is false, leave suffixIcon as-is from the caller.

    final decoration = widget.showIpaKeyboard
        ? baseDecoration.copyWith(suffixIcon: mergedSuffixIcon)
        : baseDecoration;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TapRegion(
          groupId: _tapGroupId,
          // When a tap lands outside BOTH the field and popup (i.e. truly
          // outside the group), unfocus the field so _onFocusChanged hides
          // the popup.
          onTapOutside: (_) => _focusNode.unfocus(),
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _hidePopup();
              }
            },
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: decoration,
              // Disable the TextField's built-in onTapOutside unfocus — our
              // outer TapRegion with groupId handles this correctly, taking
              // the popup into account.
              onTapOutside: (_) {},
              style: widget.style,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              expands: widget.expands,
              enabled: widget.enabled,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the floating popup anchored below (or above) the text field.
  Widget _buildOverlay(BuildContext context) {
    const popupHeight = 260.0;
    const popupWidth = 360.0;

    // Determine whether to render above or below the text field.
    // We use the global position of the render box to decide.
    Offset offset = const Offset(0, 0);
    Alignment targetAnchor = Alignment.bottomLeft;
    Alignment followerAnchor = Alignment.topLeft;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final fieldBottom = renderBox.localToGlobal(
        Offset(0, renderBox.size.height),
      );
      final screenHeight = MediaQuery.of(context).size.height;
      final spaceBelow = screenHeight - fieldBottom.dy;

      if (spaceBelow < popupHeight + 8) {
        // Not enough space below — show above.
        targetAnchor = Alignment.topLeft;
        followerAnchor = Alignment.bottomLeft;
        offset = const Offset(0, -4);
      } else {
        offset = const Offset(0, 4);
      }
    }

    return Positioned(
      width: popupWidth,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        offset: offset,
        child: TapRegion(
          // Popup is in the same tap group as the TextField so that clicks
          // inside it are NOT treated as outside taps — preventing dismissal
          // before the symbol button's onTap fires.
          groupId: _tapGroupId,
          child: IpaKeyboardPopup(
            onSymbolSelected: _insertSymbol,
            onClose: _hidePopup,
          ),
        ),
      ),
    );
  }
}
