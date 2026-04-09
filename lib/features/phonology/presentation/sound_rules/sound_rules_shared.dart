import 'package:flutter/material.dart';

/// Shared header widget with title, help text, and an "Add" button.
class SoundRulesSectionHeader extends StatelessWidget {
  const SoundRulesSectionHeader({
    super.key,
    required this.title,
    required this.helpText,
    required this.onAdd,
  });

  final String title;
  final String helpText;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  helpText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onAdd,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: 4),
                Text('Add'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state hint row.
class SoundRulesEmptyHint extends StatelessWidget {
  const SoundRulesEmptyHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Loading indicator row.
class SoundRulesLoadingRow extends StatelessWidget {
  const SoundRulesLoadingRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

/// Error display row.
class SoundRulesErrorRow extends StatelessWidget {
  const SoundRulesErrorRow({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Error: $message',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}
