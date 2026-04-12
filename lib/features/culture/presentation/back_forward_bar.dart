import 'package:flutter/material.dart';

import '../domain/page_history.dart';

/// Back/forward navigation bar shown at the top of the culture content area.
///
/// Displays two arrow buttons (back and forward) that navigate through the
/// page history stack. Rebuilds automatically when [PageHistory] notifies.
class BackForwardBar extends StatelessWidget {
  const BackForwardBar({
    super.key,
    required this.history,
    required this.onNavigate,
  });

  final PageHistory history;
  final void Function(int pageId) onNavigate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              color: colorScheme.surfaceContainer,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  _NavButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    enabled: history.canGoBack,
                    onPressed: history.canGoBack
                        ? () {
                            final pageId = history.goBack();
                            if (pageId != null) onNavigate(pageId);
                          }
                        : null,
                  ),
                  _NavButton(
                    icon: Icons.arrow_forward,
                    tooltip: 'Forward',
                    enabled: history.canGoForward,
                    onPressed: history.canGoForward
                        ? () {
                            final pageId = history.goForward();
                            if (pageId != null) onNavigate(pageId);
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          ],
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        onPressed: onPressed,
        splashRadius: 16,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
