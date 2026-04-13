import 'package:flutter/material.dart';

/// A thin vertical draggable divider that resizes an adjacent panel.
///
/// Place between two children in a [Row]. The [onDrag] callback receives
/// the horizontal delta on each drag update. The handle is 4px wide,
/// transparent by default, shows a subtle 1px line on hover, and changes
/// cursor to [SystemMouseCursors.resizeColumn].
///
/// Example — resizable left sidebar:
/// ```dart
/// Row(children: [
///   SizedBox(width: _sidebarWidth, child: sidebar),
///   ResizableDivider(onDrag: (d) => setState(() {
///     _sidebarWidth = (_sidebarWidth + d).clamp(140, 320);
///   })),
///   Expanded(child: content),
/// ])
/// ```
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({super.key, required this.onDrag});

  /// Called on each drag update with the horizontal pixel delta.
  final void Function(double delta) onDrag;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final outlineVariant = Theme.of(context).colorScheme.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        child: SizedBox(
          width: 4,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 1,
              color: _hovered
                  ? outlineVariant
                  : outlineVariant.withValues(alpha: 0),
            ),
          ),
        ),
      ),
    );
  }
}
