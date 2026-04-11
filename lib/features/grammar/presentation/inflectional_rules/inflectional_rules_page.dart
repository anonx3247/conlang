import 'package:flutter/material.dart';

/// Inflectional rules page — Phase 4 plan 04-04 stub.
///
/// Real implementation lands in plan 04-05 (Inflectional Rule Editor).
/// For 04-04 we ship a centered placeholder so the Grammar router resolves
/// and the tab is navigable.
class InflectionalRulesPage extends StatelessWidget {
  const InflectionalRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_fix_high_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Inflectional Rules',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coming in plan 04-05.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
