import 'package:flutter/material.dart';

/// Placeholder for the Particles sub-tab. Full implementation in Plan 02.
class ParticlesPage extends StatelessWidget {
  const ParticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Particles', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text('No particles yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}
