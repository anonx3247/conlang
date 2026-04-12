import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/glossary_providers.dart';
import '../domain/glossary_entry.dart';

/// A 320px right-side glossary panel with search, category filter indicator,
/// and an accordion list of linguistic terms.
///
/// Opened/closed via [glossaryOpenProvider]. Category pre-filtering is driven
/// by [glossaryCategoryFilterProvider] (set by per-tab contextual ? buttons).
class GlossaryDrawer extends ConsumerStatefulWidget {
  const GlossaryDrawer({super.key});

  @override
  ConsumerState<GlossaryDrawer> createState() => _GlossaryDrawerState();
}

class _GlossaryDrawerState extends ConsumerState<GlossaryDrawer> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns the colorScheme token for a given category name.
  Color _chipColor(ColorScheme colorScheme, String category) {
    return switch (category) {
      'Phonology' => colorScheme.primaryContainer,
      'Morphology' => colorScheme.secondaryContainer,
      'Syntax' => colorScheme.tertiaryContainer,
      'Semantics' => colorScheme.errorContainer,
      _ => colorScheme.surfaceContainerHighest, // Typology + unknown
    };
  }

  Color _chipOnColor(ColorScheme colorScheme, String category) {
    return switch (category) {
      'Phonology' => colorScheme.onPrimaryContainer,
      'Morphology' => colorScheme.onSecondaryContainer,
      'Syntax' => colorScheme.onTertiaryContainer,
      'Semantics' => colorScheme.onErrorContainer,
      _ => colorScheme.onSurface,
    };
  }

  void _navigateToTerm(String term) {
    ref.read(glossaryCategoryFilterProvider.notifier).clear();
    ref.read(glossarySearchProvider.notifier).set(term);
    _searchController.text = term;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredEntries = ref.watch(filteredGlossaryProvider);
    final activeCategory = ref.watch(glossaryCategoryFilterProvider);

    return SizedBox(
      width: 320,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    'GLOSSARY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close glossary',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      ref.read(glossaryOpenProvider.notifier).close();
                    },
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodySmall,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search terms...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                onChanged: (value) {
                  ref.read(glossarySearchProvider.notifier).set(value);
                },
              ),
            ),

            // Active category chip (shows & allows clearing the current filter)
            if (activeCategory != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: Wrap(
                  children: [
                    FilterChip(
                      label: Text(
                        activeCategory,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _chipOnColor(colorScheme, activeCategory),
                        ),
                      ),
                      backgroundColor: _chipColor(colorScheme, activeCategory),
                      selected: true,
                      onSelected: (_) {},
                      onDeleted: () {
                        ref
                            .read(glossaryCategoryFilterProvider.notifier)
                            .clear();
                      },
                      deleteIconColor: _chipOnColor(colorScheme, activeCategory),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // Term list
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Text(
                        'No matching terms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return _GlossaryTile(
                          entry: entry,
                          chipColor: _chipColor(colorScheme, entry.category),
                          chipOnColor: _chipOnColor(colorScheme, entry.category),
                          onSeeAlsoTap: _navigateToTerm,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual term tile (ExpansionTile)
// ---------------------------------------------------------------------------

class _GlossaryTile extends StatelessWidget {
  const _GlossaryTile({
    required this.entry,
    required this.chipColor,
    required this.chipOnColor,
    required this.onSeeAlsoTap,
  });

  final GlossaryEntry entry;
  final Color chipColor;
  final Color chipOnColor;
  final void Function(String term) onSeeAlsoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      childrenPadding: EdgeInsets.zero,
      title: Text(
        entry.term,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Chip(
          label: Text(
            entry.category,
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipOnColor,
              fontSize: 10,
            ),
          ),
          backgroundColor: chipColor,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.definition,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              if (entry.seeAlso.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'See also:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final related in entry.seeAlso)
                      ActionChip(
                        label: Text(
                          related,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        onPressed: () => onSeeAlsoTap(related),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.08),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
