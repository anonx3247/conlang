import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/morphology/data/morphology_providers.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../data/lexeme_providers.dart';

/// Left panel of the Dictionary master-detail layout.
///
/// Shows a scrollable list of root lexemes with:
///   - "Add root" action button
///   - Search bar (filters via [lexemeSearchQueryProvider])
///   - POS filter chips (filters via [lexemePosFilterProvider])
///   - List/table view toggle
///   - The filtered word list (list or table mode)
///   - Selection checkboxes for Anki export (D-18)
///
/// Background: [ColorScheme.surfaceContainer] per UI-SPEC.
class WordListPanel extends ConsumerStatefulWidget {
  const WordListPanel({
    super.key,
    required this.onWordSelected,
    required this.onAddRoot,
    this.selectedLexemeId,
    this.selectedForExport = const {},
    this.onToggleExport,
    this.onSelectAll,
    this.onDeselectAll,
    this.onExport,
  });

  final ValueChanged<int> onWordSelected;
  final VoidCallback onAddRoot;
  final int? selectedLexemeId;

  /// The set of lexeme IDs currently selected for Anki export.
  final Set<int> selectedForExport;

  /// Called when the user toggles the export checkbox for a single word.
  final ValueChanged<int>? onToggleExport;

  /// Called when the user taps "Select all".
  final VoidCallback? onSelectAll;

  /// Called when the user taps the select-all checkbox to deselect all.
  final VoidCallback? onDeselectAll;

  /// Called when the user taps "Export to Anki".
  final VoidCallback? onExport;

  @override
  ConsumerState<WordListPanel> createState() => _WordListPanelState();
}

class _WordListPanelState extends ConsumerState<WordListPanel> {
  bool _isTableView = false;
  final _searchController = TextEditingController();

  // Table sort state
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final filteredLexemes = ref.watch(filteredLexemeListProvider);
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];
    final posFilter = ref.watch(lexemePosFilterProvider);
    final searchQuery = ref.watch(lexemeSearchQueryProvider);
    final derivedMatches = ref.watch(derivedSearchMatchesProvider);

    // Determine select-all checkbox state
    final allIds = filteredLexemes.map((l) => l.id).toSet();
    final allSelected =
        allIds.isNotEmpty && allIds.every(widget.selectedForExport.contains);
    final someSelected = !allSelected &&
        allIds.any(widget.selectedForExport.contains);

    return ColoredBox(
      color: cs.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Add root button -------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.icon(
              onPressed: widget.onAddRoot,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add root'),
            ),
          ),

          // ---- Search bar -----------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  ref.read(lexemeSearchQueryProvider.notifier).set(value);
                },
              ),
            ),
          ),

          // ---- POS filter chips -----------------------------------------
          if (posList.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  // "All" chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: posFilter.isEmpty,
                      onSelected: (_) {
                        ref.read(lexemePosFilterProvider.notifier).set({});
                      },
                    ),
                  ),
                  ...posList.map((pos) {
                    final isSelected = posFilter.contains(pos.name);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(pos.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          final current = Set<String>.from(posFilter);
                          if (selected) {
                            current.add(pos.name);
                          } else {
                            current.remove(pos.name);
                          }
                          ref.read(lexemePosFilterProvider.notifier).set(current);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

          // ---- View toggle + count row + select-all checkbox ------------
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                // Select-all checkbox (D-18)
                Tooltip(
                  message: allSelected ? 'Deselect all' : 'Select all',
                  child: Checkbox(
                    value: allSelected ? true : (someSelected ? null : false),
                    tristate: true,
                    onChanged: filteredLexemes.isEmpty
                        ? null
                        : (_) {
                            if (allSelected) {
                              widget.onDeselectAll?.call();
                            } else {
                              widget.onSelectAll?.call();
                            }
                          },
                  ),
                ),
                Text(
                  '${filteredLexemes.length} word${filteredLexemes.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'List view',
                  child: IconButton(
                    icon: const Icon(Icons.list, size: 18),
                    tooltip: 'List view',
                    isSelected: !_isTableView,
                    onPressed: () => setState(() => _isTableView = false),
                    color: !_isTableView
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Semantics(
                  label: 'Table view',
                  child: IconButton(
                    icon: const Icon(Icons.table_rows, size: 18),
                    tooltip: 'Table view',
                    isSelected: _isTableView,
                    onPressed: () => setState(() => _isTableView = true),
                    color: _isTableView
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // ---- Word list / table ----------------------------------------
          Expanded(
            child: filteredLexemes.isEmpty
                ? _buildEmptyState(context, searchQuery)
                : _isTableView
                    ? _buildTableView(context, filteredLexemes)
                    : _buildListView(context, filteredLexemes, derivedMatches),
          ),

          // ---- Export footer (visible when 1+ words selected) -----------
          if (widget.selectedForExport.isNotEmpty)
            _buildExportFooter(context, cs),
        ],
      ),
    );
  }

  Widget _buildExportFooter(BuildContext context, ColorScheme cs) {
    final count = widget.selectedForExport.length;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: FilledButton.icon(
        onPressed: widget.onExport,
        icon: const Icon(Icons.download, size: 18),
        label: Text('Export $count to Anki'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          query.isNotEmpty
              ? 'No words match "$query"'
              : 'No words yet. Click "Add root" to add your first word.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<dynamic> lexemes,
    Set<int> derivedMatches,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Batch violations for all lexemes — avoids per-item validation calls.
    final violations = ref.watch(lexemeViolationsProvider);

    return ListView.builder(
      itemCount: lexemes.length,
      itemBuilder: (context, index) {
        final lexeme = lexemes[index];
        final isSelected = widget.selectedLexemeId == lexeme.id;
        final isCheckedForExport = widget.selectedForExport.contains(lexeme.id);

        // Count derived matches that belong to this root
        final rootIdStr = lexeme.id.toString();
        // derivedMatches contains IDs of derived forms that matched
        // We need to count how many derived forms belong to this root
        // derivedSearchMatchesProvider returns derived form IDs
        // We can approximate by checking allLexemeListProvider
        final allLexemes =
            ref.watch(allLexemeListProvider).asData?.value ?? [];
        final derivedMatchCount = derivedMatches
            .where((id) =>
                allLexemes.any((l) => l.id == id && l.rootId == rootIdStr))
            .length;

        // Violations for this specific lexeme (null if it's an exception).
        final lexemeViolation = violations[lexeme.id];
        final itemViolations = lexemeViolation?.violations ?? [];

        return Material(
          color: isSelected ? cs.primaryContainer : Colors.transparent,
          child: InkWell(
            onTap: () => widget.onWordSelected(lexeme.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Export selection checkbox (D-18)
                  Checkbox(
                    value: isCheckedForExport,
                    onChanged: (_) =>
                        widget.onToggleExport?.call(lexeme.id),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ViolationText(
                                text: lexeme.ipa,
                                violations: itemViolations,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (derivedMatchCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$derivedMatchCount derived match${derivedMatchCount == 1 ? '' : 'es'}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (lexeme.romanization != null &&
                            lexeme.romanization!.isNotEmpty)
                          Text(
                            lexeme.romanization!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (lexeme.meaning != null && lexeme.meaning!.isNotEmpty)
                          Text(
                            lexeme.meaning!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (lexeme.partOfSpeech != null &&
                            lexeme.partOfSpeech!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              lexeme.partOfSpeech!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView(BuildContext context, List<dynamic> lexemes) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Batch violations for table view IPA cells.
    final violations = ref.watch(lexemeViolationsProvider);

    // Sort lexemes based on current sort state
    final sorted = List.of(lexemes);
    sorted.sort((a, b) {
      String aVal;
      String bVal;
      switch (_sortColumnIndex) {
        case 0:
          aVal = a.ipa;
          bVal = b.ipa;
        case 1:
          aVal = a.romanization ?? '';
          bVal = b.romanization ?? '';
        case 2:
          aVal = a.partOfSpeech ?? '';
          bVal = b.partOfSpeech ?? '';
        case 3:
          aVal = a.meaning ?? '';
          bVal = b.meaning ?? '';
        default:
          aVal = a.ipa;
          bVal = b.ipa;
      }
      final cmp = aVal.compareTo(bVal);
      return _sortAscending ? cmp : -cmp;
    });

    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      letterSpacing: 0.5,
      color: cs.onSurface.withValues(alpha: 0.7),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        headingTextStyle: captionStyle,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columnSpacing: 12,
        horizontalMargin: 16,
        columns: [
          DataColumn(
            label: const Text('Word'),
            onSort: (col, asc) =>
                setState(() {
                  _sortColumnIndex = col;
                  _sortAscending = asc;
                }),
          ),
          DataColumn(
            label: const Text('IPA'),
            onSort: (col, asc) =>
                setState(() {
                  _sortColumnIndex = col;
                  _sortAscending = asc;
                }),
          ),
          DataColumn(
            label: const Text('POS'),
            onSort: (col, asc) =>
                setState(() {
                  _sortColumnIndex = col;
                  _sortAscending = asc;
                }),
          ),
          DataColumn(
            label: const Text('Meaning'),
            onSort: (col, asc) =>
                setState(() {
                  _sortColumnIndex = col;
                  _sortAscending = asc;
                }),
          ),
        ],
        rows: sorted.map((lexeme) {
          final isSelected = widget.selectedLexemeId == lexeme.id;
          final lexemeViolation = violations[lexeme.id];
          final itemViolations = lexemeViolation?.violations ?? [];
          return DataRow(
            selected: isSelected,
            onSelectChanged: (_) => widget.onWordSelected(lexeme.id),
            cells: [
              DataCell(
                ViolationText(
                  text: lexeme.ipa,
                  violations: itemViolations,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ),
              DataCell(
                Text(
                  lexeme.romanization ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              DataCell(
                Text(
                  lexeme.partOfSpeech ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              DataCell(
                Text(
                  lexeme.meaning ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
