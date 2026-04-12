import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../data/culture_providers.dart';
import '../domain/block_splitter.dart';
import 'link_autocomplete.dart';
import 'wiki_link_syntax.dart';

// ---------------------------------------------------------------------------
// BlockEditor
// ---------------------------------------------------------------------------

/// Block-based Markdown editor where each heading-section is individually
/// editable inline (Wikipedia/Jupyter-style). Per D-05, D-06.
///
/// In read mode: renders all blocks as Markdown with [[wiki-link]] syntax.
/// Click any block to enter edit mode for that block only.
/// Escape or focus-loss saves the block and returns to read mode.
class BlockEditor extends ConsumerStatefulWidget {
  const BlockEditor({
    super.key,
    required this.content,
    required this.pageTitleIndex,
    required this.onContentChanged,
    required this.onLinkTap,
  });

  /// Full page Markdown content.
  final String content;

  /// Map of page title -> page id for wiki-link resolution.
  final Map<String, int> pageTitleIndex;

  /// Called when any block is saved with the full updated content.
  final void Function(String newContent) onContentChanged;

  /// Called when a wiki-link is tapped: (title, exists).
  final void Function(String title, bool exists) onLinkTap;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  late List<String> _blocks;

  // Hover preview state
  Timer? _hoverTimer;
  OverlayEntry? _previewOverlay;

  // Hint fade-out
  double _hintOpacity = 1.0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _blocks = splitIntoBlocks(widget.content);

    // Fade hint after 3 seconds
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _hintOpacity = 0.0);
      }
    });
  }

  @override
  void didUpdateWidget(BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-split if content changed externally (e.g. title update)
    if (oldWidget.content != widget.content) {
      _blocks = splitIntoBlocks(widget.content);
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hoverTimer?.cancel();
    _removePreviewOverlay();
    super.dispose();
  }

  void _onBlockSaved(int index, String newContent) {
    _blocks[index] = newContent;
    widget.onContentChanged(joinBlocks(_blocks));
  }

  void _onHoverStart(String title, int pageId, Offset globalPosition) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _showPreviewOverlay(title, pageId, globalPosition);
    });
  }

  void _onHoverEnd() {
    _hoverTimer?.cancel();
    _removePreviewOverlay();
  }

  void _showPreviewOverlay(String title, int pageId, Offset position) {
    _removePreviewOverlay();
    final overlay = Overlay.of(context);
    _previewOverlay = OverlayEntry(
      builder: (_) => _HoverPreviewOverlay(
        title: title,
        pageId: pageId,
        position: position,
        ref: ref,
      ),
    );
    overlay.insert(_previewOverlay!);
  }

  void _removePreviewOverlay() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final wikiLinkSyntax = WikiLinkSyntax();
    final wikiLinkBuilder = WikiLinkBuilder(
      pageTitleToId: widget.pageTitleIndex,
      onLinkTap: widget.onLinkTap,
      onHoverStart: _onHoverStart,
      onHoverEnd: _onHoverEnd,
    );

    final pageTitles = widget.pageTitleIndex.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Click any section to edit" hint
        AnimatedOpacity(
          opacity: _hintOpacity,
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Click any section to edit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),

        // Blocks
        ..._blocks.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;
          return _SectionBlock(
            key: ValueKey('block_$index'),
            blockContent: block,
            blockIndex: index,
            pageTitleIndex: widget.pageTitleIndex,
            pageTitles: pageTitles,
            wikiLinkSyntax: wikiLinkSyntax,
            wikiLinkBuilder: wikiLinkBuilder,
            onSaved: (newContent) => _onBlockSaved(index, newContent),
          );
        }),

        // Empty state: show a prompt if no blocks / all empty
        if (_blocks.isEmpty ||
            (_blocks.length == 1 && _blocks[0].trim().isEmpty))
          GestureDetector(
            onTap: () {
              // Would need to tap a block to edit; show first block in edit mode
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Start writing... (click to edit)',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionBlock
// ---------------------------------------------------------------------------

/// A single heading-delimited section block.
/// Read mode: renders Markdown. Edit mode: raw TextField.
class _SectionBlock extends StatefulWidget {
  const _SectionBlock({
    super.key,
    required this.blockContent,
    required this.blockIndex,
    required this.pageTitleIndex,
    required this.pageTitles,
    required this.wikiLinkSyntax,
    required this.wikiLinkBuilder,
    required this.onSaved,
  });

  final String blockContent;
  final int blockIndex;
  final Map<String, int> pageTitleIndex;
  final List<String> pageTitles;
  final WikiLinkSyntax wikiLinkSyntax;
  final WikiLinkBuilder wikiLinkBuilder;
  final void Function(String newContent) onSaved;

  @override
  State<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<_SectionBlock> {
  bool _editing = false;
  bool _hovering = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isInteractingWithOverlay = false;

  // TapRegion shared groupId prevents autocomplete overlay taps from
  // triggering focus-loss on the block. Per IPA keyboard pattern (01-08/01-10).
  final Object _tapRegionGroupId = Object();

  // LayerLink for autocomplete overlay positioning
  final LayerLink _layerLink = LayerLink();

  // Reference to autocomplete widget state for key event forwarding
  final GlobalKey<LinkAutocompleteState> _autocompleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.blockContent);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _editing) {
      // Per IPA keyboard pattern: 100ms delay before save to allow overlay
      // interaction to complete without prematurely saving.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        if (!_isInteractingWithOverlay && _editing) {
          _saveAndExitEdit();
        }
      });
    }
  }

  void _enterEdit() {
    _controller.text = widget.blockContent;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _saveAndExitEdit() {
    if (!mounted) return;
    widget.onSaved(_controller.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_editing) {
      return TapRegion(
        groupId: _tapRegionGroupId,
        onTapOutside: (_) {
          if (!_isInteractingWithOverlay) {
            _saveAndExitEdit();
          }
        },
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Stack(
            children: [
              KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  // Forward to autocomplete for arrow/enter/escape handling
                  final consumed =
                      _autocompleteKey.currentState?.handleKeyEvent(event) ??
                          false;
                  if (!consumed &&
                      event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    _saveAndExitEdit();
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _saveAndExitEdit(),
                ),
              ),

              // Autocomplete overlay controller (invisible)
              LinkAutocomplete(
                key: _autocompleteKey,
                controller: _controller,
                focusNode: _focusNode,
                pageTitles: widget.pageTitles,
                layerLink: _layerLink,
                tapRegionGroupId: _tapRegionGroupId,
                onSelected: (_) {
                  _isInteractingWithOverlay = false;
                },
              ),
            ],
          ),
        ),
      );
    }

    // Read mode
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _enterEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovering
                ? colorScheme.surfaceContainerLow
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Stack(
            children: [
              MarkdownBody(
                data: widget.blockContent.isEmpty
                    ? '*(empty)*'
                    : widget.blockContent,
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  [
                    widget.wikiLinkSyntax,
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  ],
                ),
                builders: {
                  'wikilink': widget.wikiLinkBuilder,
                },
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                  h1: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  h2: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  h3: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colorScheme.primary.withValues(alpha: 0.9),
                    backgroundColor:
                        colorScheme.surfaceContainerHigh,
                  ),
                  blockquote: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                softLineBreak: true,
              ),

              // Pencil edit handle for pre-heading intro block (block 0)
              if (widget.blockIndex == 0 && _hovering)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HoverPreviewOverlay
// ---------------------------------------------------------------------------

/// Hover preview tooltip shown when hovering over a resolved wiki-link.
/// Per D-16: shows first ~200 chars of target page content.
class _HoverPreviewOverlay extends ConsumerWidget {
  const _HoverPreviewOverlay({
    required this.title,
    required this.pageId,
    required this.position,
    required this.ref,
  });

  final String title;
  final int pageId;
  final Offset position;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageAsync = watchRef.watch(culturePageProvider(pageId));

    return Positioned(
      left: position.dx,
      top: position.dy + 16, // slightly below cursor
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainer,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: pageAsync.when(
            loading: () => SizedBox(
              width: 160,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            error: (e, st) => Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            data: (page) {
              if (page == null) {
                return Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                );
              }
              final preview = page.content.length > 200
                  ? '${page.content.substring(0, 200)}...'
                  : page.content;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (page.icon != null && page.icon!.isNotEmpty) ...[
                        Text(page.icon!,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
