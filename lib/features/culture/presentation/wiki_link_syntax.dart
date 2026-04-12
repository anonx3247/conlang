import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Custom InlineSyntax that matches [[page title]] wiki-link patterns.
/// Per D-09: renders as clickable links in Markdown content.
class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax() : super(r'\[\[([^\]]+)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match.group(1)!.trim();
    final el = md.Element.text('wikilink', title);
    el.attributes['title'] = title;
    parser.addNode(el);
    return true;
  }
}

/// MarkdownElementBuilder that renders wiki-link AST nodes as tappable widgets.
/// Per D-10: broken links show ? badge. Per D-16: hover preview on resolved links.
class WikiLinkBuilder extends MarkdownElementBuilder {
  WikiLinkBuilder({
    required this.pageTitleToId,
    required this.onLinkTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  final Map<String, int> pageTitleToId;
  final void Function(String title, bool exists) onLinkTap;
  final void Function(String title, int pageId, Offset globalPosition)
      onHoverStart;
  final void Function() onHoverEnd;

  // Track hover timer to debounce hover start
  Timer? _hoverTimer;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final title = element.attributes['title'] ?? element.textContent;
    final exists = pageTitleToId.containsKey(title);
    final pageId = pageTitleToId[title];
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (event) {
        _hoverTimer?.cancel();
        if (exists && pageId != null) {
          _hoverTimer = Timer(const Duration(milliseconds: 400), () {
            onHoverStart(title, pageId, event.position);
          });
        }
      },
      onExit: (_) {
        _hoverTimer?.cancel();
        onHoverEnd();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onLinkTap(title, exists),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            if (!exists)
              // Per D-10: broken link ? badge
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
