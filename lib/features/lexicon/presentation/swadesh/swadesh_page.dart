import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/lexeme_providers.dart';
import '../../data/semantic_providers.dart';

/// Swadesh List page — shows 207 Swadesh concepts as a checklist with coverage
/// progress. Covered concepts show a green checkmark and the linked word.
/// Uncovered concepts have an "Add word" action that navigates to the
/// dictionary with the meaning pre-filled.
///
/// Implements D-13 from 03-CONTEXT.md and the UI-SPEC Swadesh interaction
/// contract.
class SwadeshPage extends ConsumerWidget {
  const SwadeshPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final swadeshAsync = ref.watch(swadeshListProvider);
    final coverage = ref.watch(swadeshCoverageProvider);
    final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? [];

    return swadeshAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Could not load Swadesh list.',
          style: TextStyle(color: colorScheme.error),
        ),
      ),
      data: (items) {
        // Compute aggregate coverage statistics.
        final coveredCount = coverage.values.where((v) => v != null).length;
        final total = items.length;
        final percent =
            total > 0 ? (coveredCount / total * 100).round() : 0;

        // Empty state: no lexicon entries at all.
        if (allLexemes.isEmpty) {
          return _buildEmptyState(context, colorScheme, items, coveredCount,
              total, percent);
        }

        return _buildContent(
            context, colorScheme, items, coverage, coveredCount, total, percent);
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    List<SwadeshItem> items,
    int coveredCount,
    int total,
    int percent,
  ) {
    return Container(
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverageHeader(
              coveredCount: coveredCount, total: total, percent: percent),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No lexicon entries yet. Use this list to guide your first vocabulary choices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    List<SwadeshItem> items,
    Map<int, dynamic> coverage,
    int coveredCount,
    int total,
    int percent,
  ) {
    // Group items by category for display.
    final Map<String, List<SwadeshItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Container(
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverageHeader(
              coveredCount: coveredCount, total: total, percent: percent),
          Expanded(
            child: ListView(
              children: [
                for (final category in grouped.keys) ...[
                  _CategoryHeader(category: category),
                  for (final item in grouped[category]!)
                    _SwadeshConceptTile(
                      item: item,
                      lexeme: coverage[item.id],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coverage header widget
// ---------------------------------------------------------------------------

class _CoverageHeader extends StatelessWidget {
  const _CoverageHeader({
    required this.coveredCount,
    required this.total,
    required this.percent,
  });

  final int coveredCount;
  final int total;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$coveredCount/$total — $percent%',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: total > 0 ? coveredCount / total : 0.0,
            minHeight: 8,
            color: colorScheme.primary,
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category header
// ---------------------------------------------------------------------------

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual concept tile
// ---------------------------------------------------------------------------

class _SwadeshConceptTile extends StatelessWidget {
  const _SwadeshConceptTile({
    required this.item,
    required this.lexeme,
  });

  final SwadeshItem item;
  final dynamic lexeme; // Lexeme? — nullable

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCovered = lexeme != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // Coverage icon
          Icon(
            isCovered ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isCovered
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          // Concept text
          Expanded(
            child: Text(
              item.concept,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Covered: show linked word as tappable label
          // Uncovered: show "Add word" TextButton
          if (isCovered) ...[
            _LinkedWordLabel(lexeme: lexeme, colorScheme: colorScheme),
          ] else ...[
            _AddWordButton(concept: item.concept, colorScheme: colorScheme),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Linked word label (for covered concepts)
// ---------------------------------------------------------------------------

class _LinkedWordLabel extends StatelessWidget {
  const _LinkedWordLabel({
    required this.lexeme,
    required this.colorScheme,
  });

  final dynamic lexeme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    // Extract display form — prefer romanization, fall back to IPA.
    final displayForm = (lexeme.romanization as String?)?.isNotEmpty == true
        ? lexeme.romanization as String
        : lexeme.ipa as String;

    return GestureDetector(
      onTap: () {
        // Navigate to dictionary page where the word can be viewed.
        context.go('/lexicon/dictionary');
      },
      child: Text(
        displayForm,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Add word" button (for uncovered concepts)
// ---------------------------------------------------------------------------

class _AddWordButton extends StatelessWidget {
  const _AddWordButton({
    required this.concept,
    required this.colorScheme,
  });

  final String concept;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: colorScheme.primary,
      ),
      onPressed: () {
        // Navigate to dictionary with create mode and pre-filled meaning.
        context.go(
          '/lexicon/dictionary?create=true&meaning=${Uri.encodeComponent(concept)}',
        );
      },
      child: const Text('Add word', style: TextStyle(fontSize: 12)),
    );
  }
}
