import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';

/// Left sidebar panel showing saved phrases ordered newest-first.
///
/// Each item shows a truncated preview of the original text (or an em-dash
/// if empty) and a relative timestamp below. Tapping selects the phrase
/// for editing in the right panel.
class PhraseListPanel extends StatelessWidget {
  const PhraseListPanel({
    super.key,
    required this.phrasesAsync,
    required this.selectedPhraseId,
    required this.onPhraseSelected,
    required this.onNewPhrase,
    required this.onDeletePhrase,
  });

  final AsyncValue<List<ScratchpadPhrase>> phrasesAsync;
  final int? selectedPhraseId;
  final ValueChanged<int> onPhraseSelected;
  final VoidCallback onNewPhrase;
  final ValueChanged<int> onDeletePhrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Toolbar with "New Phrase" button
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onNewPhrase,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Phrase'),
            ),
          ),
        ),
        const Divider(height: 1),
        // Phrase list
        Expanded(
          child: phrasesAsync.when(
            data: (phrases) {
              if (phrases.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No phrases yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: phrases.length,
                itemBuilder: (context, index) {
                  final phrase = phrases[index];
                  final isSelected = phrase.id == selectedPhraseId;
                  final preview = phrase.originalText.isEmpty
                      ? '\u2014' // em-dash for empty phrases
                      : phrase.originalText;
                  return _PhraseListItem(
                    phrase: phrase,
                    preview: preview,
                    isSelected: isSelected,
                    onTap: () => onPhraseSelected(phrase.id),
                    onDelete: () => onDeletePhrase(phrase.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _PhraseListItem extends StatelessWidget {
  const _PhraseListItem({
    required this.phrase,
    required this.preview,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final ScratchpadPhrase phrase;
  final String preview;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(phrase.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Delete button
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(Icons.close,
                      color: colorScheme.onSurface.withValues(alpha: 0.3)),
                  onPressed: onDelete,
                  tooltip: 'Delete phrase',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
