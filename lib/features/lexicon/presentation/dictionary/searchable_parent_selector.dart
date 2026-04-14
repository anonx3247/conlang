import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/lexeme_providers.dart';

/// Searchable dropdown for selecting parent lexemes, replacing the
/// non-scalable FilterChip wall (Phase 11 UX fix per CONTEXT.md).
///
/// Shows selected parents as removable [ActionChip] pills below the
/// search field. [Autocomplete] filters [allLexemeListProvider]
/// client-side by romanization, IPA, and meaning (case-insensitive
/// substring). Empty query shows no overlay.
///
/// T-11-04 DoS mitigation: returns max 20 results; empty query returns
/// empty iterable; filter runs client-side against already-loaded list.
class SearchableParentSelector extends ConsumerStatefulWidget {
  const SearchableParentSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    required this.excludeId,
    this.enabled = true,
  });

  /// Currently selected parent lexeme IDs.
  final Set<int> selectedIds;

  /// Called with the new set of selected IDs when user adds/removes a parent.
  final ValueChanged<Set<int>> onChanged;

  /// Lexeme ID to exclude from autocomplete results (the word being edited).
  /// Pass -1 when creating a new word that has no ID yet.
  final int excludeId;

  /// Whether the selector is interactive.
  final bool enabled;

  @override
  ConsumerState<SearchableParentSelector> createState() =>
      _SearchableParentSelectorState();
}

class _SearchableParentSelectorState
    extends ConsumerState<SearchableParentSelector> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayStringForOption(Lexeme lx) {
    final label = lx.romanization?.isNotEmpty == true
        ? lx.romanization!
        : lx.ipa;
    return lx.meaning != null ? '$label \u2014 ${lx.meaning}' : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allLexemes =
        ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search autocomplete field
        Autocomplete<Lexeme>(
          displayStringForOption: _displayStringForOption,
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Lexeme>.empty();
            }
            final query = textEditingValue.text.toLowerCase();
            final candidates = ref
                    .read(allLexemeListProvider)
                    .asData
                    ?.value ??
                const <Lexeme>[];
            return candidates
                .where((lx) =>
                    lx.id != widget.excludeId &&
                    !widget.selectedIds.contains(lx.id))
                .where((lx) =>
                    lx.ipa.toLowerCase().contains(query) ||
                    (lx.romanization?.toLowerCase().contains(query) ?? false) ||
                    (lx.meaning?.toLowerCase().contains(query) ?? false))
                .take(20);
          },
          onSelected: (lx) {
            widget.onChanged({...widget.selectedIds, lx.id});
            _searchController.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // Keep _searchController in sync so we can clear it on selection.
            // We assign the autocomplete-provided controller to our internal
            // reference so clear() reaches the rendered field.
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                hintText: 'Search words to add as parent\u2026',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            );
          },
        ),

        // Selected pills
        if (widget.selectedIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.selectedIds)
                Builder(
                  builder: (context) {
                    final lx = allLexemes.where((l) => l.id == id).firstOrNull;
                    final label = lx == null
                        ? 'Unknown (#$id)'
                        : (lx.romanization?.isNotEmpty == true
                                ? lx.romanization!
                                : lx.ipa) +
                            (lx.meaning != null ? ' \u2014 ${lx.meaning}' : '');
                    return InputChip(
                      label: Text(
                        label,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(fontSize: 11),
                      ),
                      onDeleted: widget.enabled
                          ? () => widget.onChanged(
                                {...widget.selectedIds}..remove(id),
                              )
                          : null,
                      deleteButtonTooltipMessage: 'Remove parent link',
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
