import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/project/data/project_providers.dart';
import 'romanization_section.dart';

/// Phoneme inventory page.
///
/// Shows the romanization mapping editor (and future phoneme inventory sections)
/// when a project is open, or a placeholder empty state when no project is
/// selected.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(currentDatabaseProvider);
    final theme = Theme.of(context);

    if (db == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or open a project to start defining phonemes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Project is open — show the inventory editor.
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Romanization section (IPA → Latin mapping editor).
          RomanizationSection(),

          // Additional sections (phoneme inventory table, natural classes, etc.)
          // will be added in subsequent plans.
        ],
      ),
    );
  }
}
