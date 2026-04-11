import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../lexicon/data/phonotactic_validation_provider.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/word_generator.dart';
import '../../../project/data/project_providers.dart';
import '../../data/grammar_providers.dart';
import '../../data/paradigm_cell_override_dao.dart';
import '../../data/typology_providers.dart';
import '../../domain/dimension_level.dart';
import '../../domain/paradigm_axes.dart';
import '../../domain/paradigm_cell.dart';
import 'cell_override_dialog.dart';

/// Shared paradigm table widget (D-25, D-28, D-29, D-30).
///
/// Consumers:
///   - Grammar → Paradigm Viewer sub-tab (plan 04-06 — this plan)
///   - Lexicon word detail embed (plan 04-07 — showAxisConfig=false)
///
/// Behavior highlights:
///   - 2-dim POS: flat rows × columns table.
///   - 3+-dim POS: rows/cols become the two axes, the remaining dimensions
///     are flattened into a slice selector. Up to 6 slices render as a
///     `TabBar`; more than 6 render as a `DropdownButton` (D-25).
///   - Each filled cell shows romanization via `ViolationText` (D-29 / D-30
///     per-cell violation highlighting) with the IPA on a dimmed second
///     line. Validation is skipped for lexemes whose `isPhonologicalException`
///     flag is set (Phase 3 per-word toggle).
///   - Overridden cells render with an amber background + border +
///     `Icons.warning_amber_outlined` overlay; the override's romanization
///     (or IPA if no rom) is the primary text.
///   - Uncovered cells render em-dash `—` with a small plus icon.
///   - Tapping any cell opens `CellOverrideDialog`.
class ParadigmTableWidget extends ConsumerWidget {
  const ParadigmTableWidget({
    super.key,
    required this.lexemeId,
    required this.posId,
  });

  final int lexemeId;
  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    final axesAsync = ref.watch(paradigmAxesProvider(posId));
    final axes = axesAsync.asData?.value ?? const ParadigmAxes();

    if (dims.length < 2) {
      return Center(
        child: Text(
          'This POS has fewer than 2 dimensions; no paradigm to render.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    // Resolve the rows/cols Dimension rows from the axis ids. Fall back to
    // `ParadigmAxes.defaultsFor(dims)` (first two dims) when the stored
    // axes don't match the current dims list — this happens the first time
    // a POS is viewed before any explicit axis config is written.
    Dimension? rowDim =
        dims.where((d) => d.id == axes.rows).cast<Dimension?>().firstOrNull;
    Dimension? colDim =
        dims.where((d) => d.id == axes.cols).cast<Dimension?>().firstOrNull;
    if (rowDim == null || colDim == null) {
      final defaults = ParadigmAxes.defaultsFor(dims);
      rowDim ??=
          dims.where((d) => d.id == defaults.rows).cast<Dimension?>().firstOrNull;
      colDim ??=
          dims.where((d) => d.id == defaults.cols).cast<Dimension?>().firstOrNull;
    }
    if (rowDim == null || colDim == null) {
      return const Center(child: Text('Configure row and column dimensions.'));
    }

    // D-25: extra dimensions become the slice selector.
    final extraDims =
        dims.where((d) => d.id != rowDim!.id && d.id != colDim!.id).toList();
    final extraLevelLists =
        extraDims.map((d) => decodeLevelsJson(d.levelsJson)).toList();
    final slices = _cartesianSlices(extraDims, extraLevelLists);

    // Compute the paradigm for the current lexeme (may be synthetic / -1
    // for the template case — computedInflectedParadigmProvider then returns
    // an empty chart which is still a valid render target).
    final chart = ref.watch(computedInflectedParadigmProvider(lexemeId));

    // Resolve a single unified cell lookup function so the nested cell
    // builders don't need to know about the ParadigmChart structure.
    ParadigmCell? cellFor(Map<int, int> featureSet) => chart.cellFor(featureSet);

    if (slices.length == 1) {
      return _buildTable(
        context,
        ref,
        theme,
        cs,
        rowDim: rowDim,
        colDim: colDim,
        sliceKey: slices.first,
        cellFor: cellFor,
      );
    }

    if (slices.length <= 6) {
      return DefaultTabController(
        length: slices.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: slices
                  .map((s) =>
                      Tab(text: _sliceLabel(extraDims, extraLevelLists, s)))
                  .toList(),
            ),
            Expanded(
              child: TabBarView(
                children: slices
                    .map((s) => _buildTable(
                          context,
                          ref,
                          theme,
                          cs,
                          rowDim: rowDim!,
                          colDim: colDim!,
                          sliceKey: s,
                          cellFor: cellFor,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return _DropdownSliceSelector(
      slices: slices,
      extraDims: extraDims,
      extraLevelLists: extraLevelLists,
      buildTable: (sliceKey) => _buildTable(
        context,
        ref,
        theme,
        cs,
        rowDim: rowDim!,
        colDim: colDim!,
        sliceKey: sliceKey,
        cellFor: cellFor,
      ),
      labelFor: (s) => _sliceLabel(extraDims, extraLevelLists, s),
    );
  }

  // -------------------------------------------------------------------------
  // Slice helpers
  // -------------------------------------------------------------------------

  /// Cartesian product of the extra dimensions' level lists. Returns a
  /// single empty slice key when no extra dimensions exist (meaning the
  /// entire table renders without a slice selector).
  List<Map<int, int>> _cartesianSlices(
    List<Dimension> extraDims,
    List<List<DimensionLevel>> lists,
  ) {
    if (extraDims.isEmpty) return [const <int, int>{}];
    var acc = <Map<int, int>>[{}];
    for (var i = 0; i < extraDims.length; i++) {
      final dim = extraDims[i];
      final levels = lists[i];
      final next = <Map<int, int>>[];
      for (final a in acc) {
        for (final l in levels) {
          next.add({...a, dim.id: l.id});
        }
      }
      acc = next;
    }
    return acc;
  }

  String _sliceLabel(
    List<Dimension> extraDims,
    List<List<DimensionLevel>> lists,
    Map<int, int> sliceKey,
  ) {
    final parts = <String>[];
    for (var i = 0; i < extraDims.length; i++) {
      final dim = extraDims[i];
      final levelId = sliceKey[dim.id];
      DimensionLevel? level;
      for (final l in lists[i]) {
        if (l.id == levelId) {
          level = l;
          break;
        }
      }
      if (level != null) parts.add(level.abbr);
    }
    return parts.join(' · ');
  }

  // -------------------------------------------------------------------------
  // Table rendering
  // -------------------------------------------------------------------------

  Widget _buildTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs, {
    required Dimension rowDim,
    required Dimension colDim,
    required Map<int, int> sliceKey,
    required ParadigmCell? Function(Map<int, int>) cellFor,
  }) {
    final rowLevels = decodeLevelsJson(rowDim.levelsJson);
    final colLevels = decodeLevelsJson(colDim.levelsJson);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column-header row (empty top-left corner + one header cell per
            // col level).
            Row(
              children: [
                const SizedBox(width: 80),
                for (final col in colLevels)
                  Container(
                    width: 80,
                    height: 32,
                    alignment: Alignment.center,
                    color: cs.surfaceContainerLow,
                    child: Text(
                      col.abbr,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            for (final row in rowLevels)
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 64,
                    alignment: Alignment.center,
                    color: cs.surfaceContainerLow,
                    child: Text(
                      row.abbr,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final col in colLevels)
                    _ParadigmCellWidget(
                      lexemeId: lexemeId,
                      featureSet: {
                        rowDim.id: row.id,
                        colDim.id: col.id,
                        ...sliceKey,
                      },
                      cell: cellFor({
                        rowDim.id: row.id,
                        colDim.id: col.id,
                        ...sliceKey,
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-cell widget (separate so it can nest its own override stream Consumer
// without rebuilding the whole table on override changes).
// ---------------------------------------------------------------------------

/// Per-lexeme override stream provider (file-scoped — trivial wrapper
/// around `ParadigmCellOverrideDao.watchOverridesForLexeme`). Lives here
/// rather than in `paradigm_coverage_provider.dart` so this file owns its
/// own leaf dependency.
final overridesForLexemeProvider =
    StreamProvider.family<Map<String, ParadigmCellOverride>, int>(
  (ref, lexemeId) {
    final db = ref.watch(currentDatabaseProvider);
    if (db == null) {
      return const Stream<Map<String, ParadigmCellOverride>>.empty();
    }
    return ParadigmCellOverrideDao(db).watchOverridesForLexeme(lexemeId);
  },
);

class _ParadigmCellWidget extends ConsumerWidget {
  const _ParadigmCellWidget({
    required this.lexemeId,
    required this.featureSet,
    required this.cell,
  });

  final int lexemeId;
  final Map<int, int> featureSet;
  final ParadigmCell? cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final overridesAsync = ref.watch(overridesForLexemeProvider(lexemeId));
    final overrides =
        overridesAsync.asData?.value ?? const <String, ParadigmCellOverride>{};
    final key = featureSetKeyForOverride(featureSet);
    final override = overrides[key];

    void openDialog() {
      showDialog<void>(
        context: context,
        builder: (_) => CellOverrideDialog(
          lexemeId: lexemeId,
          featureSet: featureSet,
          currentCell: cell,
          existingOverride: override,
        ),
      );
    }

    if (override != null) {
      return _OverrideCell(
        row: override,
        onTap: openDialog,
        cs: cs,
        theme: theme,
      );
    }

    return InkWell(
      onTap: openDialog,
      child: Container(
        width: 80,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: switch (cell) {
          null => _uncoveredCell(cs, theme),
          ParadigmUncovered() => _uncoveredCell(cs, theme),
          ParadigmAmbiguous() =>
            Icon(Icons.error_outline, color: cs.error, size: 16),
          ParadigmFilled(:final form) =>
            _FilledCell(form: form, lexemeId: lexemeId),
        },
      ),
    );
  }

  Widget _uncoveredCell(ColorScheme cs, ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          '—',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Icon(
            Icons.add_circle_outline,
            size: 14,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }
}

/// Filled-cell body: romanization (via [ViolationText]) stacked over IPA.
///
/// D-30: phonotactic validation runs via `phonotacticValidatorProvider` —
/// the same validator already used by the lexicon — so the violation set
/// is consistent with the word list's red wavy underlines. If the lexeme
/// has `isPhonologicalException == true` (Phase 3 per-word toggle) the
/// validation is skipped and no violations are shown.
class _FilledCell extends ConsumerWidget {
  const _FilledCell({required this.form, required this.lexemeId});

  final String form;
  final int lexemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final romanize = ref.watch(romanizeProvider);
    final validate = ref.watch(phonotacticValidatorProvider);
    final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
    final lexeme = lexemeAsync.asData?.value;
    final isException = lexeme?.isPhonologicalException ?? false;

    final romText = romanize(form);
    final ValidationResult result =
        isException ? const ValidationResult(violations: []) : validate(word: form);

    // G-04 / D-29: show romanization as the primary top line ONLY when it
    // actually differs from the IPA form. Mirrors the "showRomanizedRoot"
    // idiom in derivation_tree_widget.dart:41-42 so users never see the
    // same glyphs duplicated when no romanization mapping is configured.
    final showRom = romText.isNotEmpty && romText != form;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showRom) ...[
            // D-29 top line: rom primary, ViolationText-wrapped for
            // per-cell phonotactic underlines (D-30).
            ViolationText(text: romText, violations: result.violations),
            const SizedBox(height: 2),
            // D-29 bottom line: IPA dimmed.
            Text(
              '[$form]',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else
            // No distinct romanization: single IPA-only dimmed line so
            // the cell doesn't double-render identical text.
            ViolationText(
              text: '[$form]',
              violations: result.violations,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Amber override cell rendering (D-28).
class _OverrideCell extends StatelessWidget {
  const _OverrideCell({
    required this.row,
    required this.onTap,
    required this.cs,
    required this.theme,
  });

  final ParadigmCellOverride row;
  final VoidCallback onTap;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final primary = row.overrideRomanization ?? row.overrideIpa;
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  primary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '[${row.overrideIpa}]',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Icon(
              Icons.warning_amber_outlined,
              size: 12,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// >6 slices → dropdown selector (stateful wrapper).
// ---------------------------------------------------------------------------

class _DropdownSliceSelector extends StatefulWidget {
  const _DropdownSliceSelector({
    required this.slices,
    required this.extraDims,
    required this.extraLevelLists,
    required this.buildTable,
    required this.labelFor,
  });

  final List<Map<int, int>> slices;
  final List<Dimension> extraDims;
  final List<List<DimensionLevel>> extraLevelLists;
  final Widget Function(Map<int, int> sliceKey) buildTable;
  final String Function(Map<int, int> sliceKey) labelFor;

  @override
  State<_DropdownSliceSelector> createState() => _DropdownSliceSelectorState();
}

class _DropdownSliceSelectorState extends State<_DropdownSliceSelector> {
  // Dart Maps have identity equality, so we cannot use `Map<int, int>` as
  // the `DropdownButton<T>` value type — the DropdownButton's internal
  // equality check would never match any item. Instead we index into
  // `widget.slices` by integer position.
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.slices[_currentIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Slice:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _currentIndex,
                items: [
                  for (var i = 0; i < widget.slices.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(widget.labelFor(widget.slices[i])),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _currentIndex = v);
                },
              ),
            ],
          ),
        ),
        Expanded(child: widget.buildTable(current)),
      ],
    );
  }
}
