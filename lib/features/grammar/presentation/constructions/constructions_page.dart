import 'package:flutter/material.dart';

/// Placeholder for the Constructions sub-tab. Full implementation in Plan 03.
class ConstructionsPage extends StatelessWidget {
  const ConstructionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Constructions', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text('No constructions yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}
