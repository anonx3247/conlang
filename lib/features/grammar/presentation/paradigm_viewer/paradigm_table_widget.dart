import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../lexicon/data/phonotactic_validation_provider.dart';
import '../../../lexicon/presentation/widgets/lexeme_display_label.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../morphology/presentation/rules/rule_editor_dialog.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/word_generator.dart';
import '../../../project/data/project_providers.dart';
import '../../data/grammar_providers.dart';
import '../../data/intrinsic_levels_codec.dart';
import '../../data/paradigm_cell_override_dao.dart';
import '../../data/standard_form_validation_provider.dart';
import '../../data/typology_providers.dart';
import '../../domain/dimension_level.dart';
import '../../domain/paradigm_axes.dart';
import '../../domain/paradigm_cell.dart';
import '../../domain/pos_resolver.dart';
import '../../domain/rule_kind.dart';
import 'cell_override_dialog.dart';

/// D-52 / plan 04-13 — Controls what happens when a user taps a paradigm
/// cell. Two host contexts consume [ParadigmTableWidget]:
///
/// - [ParadigmClickMode.ruleEditor] — Grammar > Inflections sub-tab host
///   (D-51). Tapping any cell opens [RuleEditorDialog] with the cell's
///   feature bindings pre-filled. Empty cells create a new rule; filled
///   cells open the topmost rule in the chain for edit.
///
/// - [ParadigmClickMode.wordOverride] — Lexicon word-detail paradigm
///   embed host (D-54). Tapping a cell opens [CellOverrideDialog] for a
///   per-word rom/ipa override. This is the pre-plan-04-13 click behavior,
///   now scoped to a single host context.
enum ParadigmClickMode { ruleEditor, wordOverride }

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
    this.clickMode = ParadigmClickMode.ruleEditor,
    this.lexemeIds,
  });

  final int lexemeId;
  final int posId;

  /// D-52 — Determines the click handler branch for paradigm cells.
  /// Defaults to [ParadigmClickMode.ruleEditor] since the Grammar host
  /// is the primary consumer post-plan-04-13. The Lexicon word-detail
  /// embed explicitly passes [ParadigmClickMode.wordOverride].
  final ParadigmClickMode clickMode;

  /// Issue 37c — 04-18-03. Optional set of lexeme IDs for multi-word
  /// intrinsic selection in the grammar tab. When non-null and non-empty,
  /// the stacked-slice viewer filters each intrinsic slice to only show
  /// lexemes whose IDs appear in this set. Null = template / single-word
  /// behavior (unchanged).
  final List<int>? lexemeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];

    // D-94 — 04-17. Check for intrinsic dimensions. If present, render
    // stacked slices (one section per intrinsic combination) instead of
    // the single-table layout.
    final hasIntrinsic = dims.any((d) => d.intrinsic);
    if (hasIntrinsic) {
      return _buildStackedIntrinsicSlices(context, ref, theme, cs, dims);
    }

    return _buildSingleParadigmTable(context, ref, theme, cs, dims);
  }

  /// Non-intrinsic POS: the original single-table render path.
  Widget _buildSingleParadigmTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    List<Dimension> dims,
  ) {
    final axesAsync = ref.watch(paradigmAxesProvider(posId));
    final axes = axesAsync.asData?.value ?? const ParadigmAxes();

    if (dims.isEmpty) {
      return Center(
        child: Text(
          'This POS has no dimensions. Add dimensions to build a paradigm.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    // Issue 37a — 04-18-03. A POS with exactly 1 dimension renders a
    // single-row flat table: that dimension supplies the column headers
    // and there is exactly one data row with the base stem.
    if (dims.length == 1) {
      final singleDim = dims.first;
      final effectiveLexemeId = lexemeId != -1
          ? lexemeId
          : (ref.watch(firstMatchingLexemeForPosProvider(posId))?.id ?? -1);
      final chart =
          ref.watch(computedInflectedParadigmProvider(effectiveLexemeId));
      ParadigmCell? cellFor(Map<int, int> featureSet) =>
          chart.cellFor(featureSet);
      return _buildSingleDimTable(
        context,
        ref,
        theme,
        cs,
        dim: singleDim,
        cellFor: cellFor,
        activeLexemeId: effectiveLexemeId,
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

    // D-95 — 04-17. Default to first matching lexeme when no explicit
    // selection. For non-intrinsic POSes, first-matching applies at the
    // top level.
    final effectiveLexemeId = lexemeId != -1
        ? lexemeId
        : (ref.watch(firstMatchingLexemeForPosProvider(posId))?.id ?? -1);

    // Compute the paradigm for the current lexeme (may be synthetic / -1
    // for the template case — computedInflectedParadigmProvider then returns
    // an empty chart which is still a valid render target).
    final chart = ref.watch(computedInflectedParadigmProvider(effectiveLexemeId));

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
        activeLexemeId: effectiveLexemeId,
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
                          activeLexemeId: effectiveLexemeId,
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
        activeLexemeId: effectiveLexemeId,
      ),
      labelFor: (s) => _sliceLabel(extraDims, extraLevelLists, s),
    );
  }

  /// D-94 — 04-17. Stacked intrinsic slice rendering. Enumerates the
  /// Cartesian product of intrinsic combinations and renders one section
  /// per combination (even for empty buckets — show the hint).
  ///
  /// Issues 37b/37c/39b — 04-18-03:
  /// - When [lexemeId] != -1 (word-detail mode), only the combination
  ///   matching that lexeme's own intrinsic levels is shown (no dropdowns).
  /// - When [lexemeIds] is non-null/non-empty (grammar-tab multi-select),
  ///   each slice's pool is filtered to the selected IDs, skipping slices
  ///   with no matching word.
  Widget _buildStackedIntrinsicSlices(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    List<Dimension> dims,
  ) {
    final intrinsicDims = dims.where((d) => d.intrinsic).toList();
    final nonIntrinsicDims = dims.where((d) => !d.intrinsic).toList();

    // Build all possible intrinsic combinations.
    List<Map<int, int>> combinations = [<int, int>{}];
    for (final d in intrinsicDims) {
      final levels = decodeLevelsJson(d.levelsJson);
      combinations = [
        for (final partial in combinations)
          for (final lv in levels) {...partial, d.id: lv.id},
      ];
    }

    // Issue 37b/39b — 04-18-03. Word-detail mode: filter to the specific
    // lexeme's own intrinsic combination and render exactly one slice.
    if (lexemeId != -1) {
      final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
      final lexeme = lexemeAsync.asData?.value;
      final ownLevels = IntrinsicLevelsCodec.decode(lexeme?.intrinsicLevelsJson);
      // Build the single combination key that matches this word's intrinsic
      // levels. Fall back to the first combo if levels are not yet stored.
      Map<int, int> ownCombo = {};
      for (final d in intrinsicDims) {
        if (ownLevels.containsKey(d.id)) {
          ownCombo[d.id] = ownLevels[d.id]!;
        }
      }
      final filteredCombinations = ownCombo.length == intrinsicDims.length
          ? [ownCombo]
          : combinations.take(1).toList();

      // For word-detail, show no-dropdown slice (pool = [lexeme]).
      final pool = lexeme != null ? [lexeme] : <Lexeme>[];

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final combo in filteredCombinations)
              _IntrinsicSliceSection(
                posId: posId,
                combination: combo,
                intrinsicDims: intrinsicDims,
                allDims: dims,
                pool: pool,
                clickMode: clickMode,
                // Word-detail: lock the word, hide the dropdown.
                lockedLexemeId: lexemeId,
              ),
          ],
        ),
      );
    }

    // Lookup grouped lexemes.
    final grouped = ref.watch(lexemesByIntrinsicCombinationProvider(posId));

    // Issue 37a — 04-18-03. 0 non-intrinsic dims: POS is entirely intrinsic
    // (e.g. a gender-only POS). Show base forms only — no paradigm axes.
    if (nonIntrinsicDims.isEmpty) {
      final allLexemes = ref.watch(allLexemeListProvider).asData?.value ?? const <Lexeme>[];
      final posList = ref.watch(posListProvider).asData?.value ?? const <PartsOfSpeechData>[];
      final posLexemes = allLexemes.where((lex) {
        final pos = posForLexeme(lex, posList);
        return pos?.id == posId;
      }).toList();
      return _buildBaseFormDisplay(context, theme, cs, posLexemes, intrinsicDims);
    }

    // Issue 37a — 04-18-03. 1 non-intrinsic dim: render a single-row
    // paradigm table per intrinsic slice instead of rejecting.
    // (2+ non-intrinsic dims: existing multi-axis table rendering below.)
    //
    // Multi-select filtering (issue 37c): when [lexemeIds] is set, filter
    // each combo's pool and skip combos with no matching word.
    final effectiveLexemeIds = lexemeIds;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final combo in combinations) ...[
            Builder(builder: (ctx) {
              var pool = _lookupPool(grouped, combo, intrinsicDims);
              // Issue 37c: filter pool when lexemeIds selection is active.
              if (effectiveLexemeIds != null && effectiveLexemeIds.isNotEmpty) {
                pool = pool
                    .where((l) => effectiveLexemeIds.contains(l.id))
                    .toList();
                // Skip combos where no selected word has these intrinsic levels.
                if (pool.isEmpty) return const SizedBox.shrink();
              }
              return _IntrinsicSliceSection(
                posId: posId,
                combination: combo,
                intrinsicDims: intrinsicDims,
                allDims: dims,
                pool: pool,
                clickMode: clickMode,
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Issue 37a — 04-18-03. Base-form display for POSes with 0 non-intrinsic
  /// dimensions. Lists words grouped by their intrinsic combination — no
  /// paradigm axes to generate.
  Widget _buildBaseFormDisplay(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<Lexeme> posLexemes,
    List<Dimension> intrinsicDims,
  ) {
    if (posLexemes.isEmpty) {
      return Center(
        child: Text(
          'No words for this POS yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All dimensions are intrinsic — no paradigm axes. '
              'Base forms listed below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            for (final lex in posLexemes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(lex.ipa, style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }

  /// Look up the pool of lexemes for an intrinsic combination from the
  /// grouped map (which uses string keys for identity equality).
  static List<Lexeme> _lookupPool(
    Map<String, List<Lexeme>> grouped,
    Map<int, int> combo,
    List<Dimension> intrinsicDims,
  ) {
    final keyStr = combo.entries.map((e) => '${e.key}:${e.value}').join(',');
    return grouped[keyStr] ?? const [];
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
    int activeLexemeId = -1,
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
                      lexemeId: activeLexemeId,
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
                      clickMode: clickMode,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Issue 37a — 04-18-03. Single-dimension table: one row of cells,
  /// one column header per level. The "row" header area is omitted since
  /// there is only one row (the base form row).
  Widget _buildSingleDimTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs, {
    required Dimension dim,
    required ParadigmCell? Function(Map<int, int>) cellFor,
    int activeLexemeId = -1,
  }) {
    final levels = decodeLevelsJson(dim.levelsJson);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: one cell per level.
          Row(
            children: [
              for (final lvl in levels)
                Container(
                  width: 80,
                  height: 32,
                  alignment: Alignment.center,
                  color: cs.surfaceContainerLow,
                  child: Text(
                    lvl.abbr,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          // Data row: one cell per level.
          Row(
            children: [
              for (final lvl in levels)
                _ParadigmCellWidget(
                  lexemeId: activeLexemeId,
                  featureSet: {dim.id: lvl.id},
                  cell: cellFor({dim.id: lvl.id}),
                  clickMode: clickMode,
                ),
            ],
          ),
        ],
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
    required this.clickMode,
  });

  final int lexemeId;
  final Map<int, int> featureSet;
  final ParadigmCell? cell;
  final ParadigmClickMode clickMode;

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
      switch (clickMode) {
        case ParadigmClickMode.wordOverride:
          // D-54: Lexicon word-detail host — preserve the per-word rom/ipa
          // override flow (the pre-plan-04-13 click behavior).
          showDialog<void>(
            context: context,
            builder: (_) => CellOverrideDialog(
              lexemeId: lexemeId,
              featureSet: featureSet,
              currentCell: cell,
              existingOverride: override,
            ),
          );
          break;
        case ParadigmClickMode.ruleEditor:
          // D-51: Grammar > Inflections host — open RuleEditorDialog with
          // the cell's bindings pre-filled. Filled cells try to resolve
          // the topmost rule in the chain so the dialog opens in edit
          // mode; empty cells open in create mode with preFilledBindings.
          //
          // D-103 (plan 04-18-05): ParadigmUnmarked cells open the dialog
          // in marker mode (markerId set) so the user edits the matching
          // marker rather than creating a new rule.
          final localCell = cell;

          if (localCell is ParadigmUnmarked) {
            // D-103: click on ∅ cell → edit the matching marker.
            showDialog<void>(
              context: context,
              builder: (_) => RuleEditorDialog(
                kind: RuleKind.inflectional,
                markerId: localCell.source.id,
                markerBindings: localCell.source.bindings,
              ),
            );
            break;
          }

          MorphologicalRule? existingRule;
          if (localCell is ParadigmFilled && localCell.ruleChain.isNotEmpty) {
            final topRuleId = localCell.ruleChain.first.id;
            final rules =
                ref.read(morphologicalRuleListProvider).asData?.value ??
                    const <MorphologicalRule>[];
            for (final r in rules) {
              if (r.id == topRuleId) {
                existingRule = r;
                break;
              }
            }
          }
          showDialog<void>(
            context: context,
            builder: (_) => RuleEditorDialog(
              kind: RuleKind.inflectional,
              existing: existingRule,
              preFilledBindings: existingRule == null ? featureSet : null,
            ),
          );
          break;
      }
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
          ParadigmFilled(:final form, :final phonemic) =>
            _FilledCell(form: form, phonemic: phonemic, lexemeId: lexemeId),
          // D-47: bare root in muted gray with trailing ∅ badge. Click
          // handler intentionally reuses the existing openDialog() path
          // in this plan — plan 04-13 replaces the entire ParadigmTable
          // click flow per D-51/D-52 (clicking any cell opens
          // RuleEditorDialog; unmarked cells open a Marker tab there).
          ParadigmUnmarked(:final root) =>
            _UnmarkedCell(root: root, lexemeId: lexemeId),
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
///
/// D-112 (plan 04-17): [phonemic] is the raw morphological output
/// (pre-rewrite); [form] is the phonetic surface (post-rewrite). The rom
/// line uses `romanize(phonemic)` — NEVER `romanize(form)` — so that
/// sound-change rewrites do not leak into the romanization display.
class _FilledCell extends ConsumerWidget {
  const _FilledCell({
    required this.form,
    required this.phonemic,
    required this.lexemeId,
  });

  /// Phonetic surface form (post-rewrite). Used for `[bracket]` display.
  final String form;

  /// Raw morphological output (pre-rewrite). Used as input to `romanize()`.
  final String phonemic;

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

    // D-112: romanize the raw phonemic, not the post-rewrite phonetic.
    final romText = romanize(phonemic);
    final ValidationResult result =
        isException ? const ValidationResult(violations: []) : validate(word: phonemic);

    // G-04 / D-29: show romanization as the primary top line ONLY when it
    // actually differs from the phonemic form. Mirrors the "showRomanizedRoot"
    // idiom in derivation_tree_widget.dart:41-42 so users never see the
    // same glyphs duplicated when no romanization mapping is configured.
    final showRom = romText.isNotEmpty && romText != phonemic;

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
            // D-29 bottom line: phonetic surface in brackets, dimmed.
            Text(
              '[$form]',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else
            // No distinct romanization: single phonetic-only dimmed line so
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

/// D-47 render: bare root in muted gray with a trailing ∅ badge.
///
/// Visually distinct from:
///   - [_FilledCell] — normal rom+IPA two-line layout at full opacity
///   - [_ParadigmCellWidget._uncoveredCell] — em-dash `—` placeholder
///   - [_OverrideCell] — amber background + warning icon
///
/// The muted gray treatment is `cs.onSurface.withValues(alpha: 0.45)` on
/// the primary text and `alpha: 0.35` on the IPA bottom line. The trailing
/// ∅ badge sits in the top-right of the cell as a small labelSmall glyph
/// at `alpha: 0.55` so it reads as a subtle annotation rather than a
/// warning (which is the visual role reserved for override cells).
///
/// Click handler is intentionally left to the parent [_ParadigmCellWidget]
/// — plan 04-13 replaces the entire cell click flow per D-51/D-52.
class _UnmarkedCell extends ConsumerWidget {
  const _UnmarkedCell({required this.root, required this.lexemeId});

  final String root;
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

    final romText = romanize(root);
    // D-29 parity with _FilledCell: only show rom as a separate primary
    // line when it actually differs from the IPA form — avoids double
    // rendering when no romanization mapping is configured.
    final showRom = romText.isNotEmpty && romText != root;
    final ValidationResult result = isException
        ? const ValidationResult(violations: [])
        : validate(word: root);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showRom) ...[
                  // Muted rom top line with violation underlines.
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                    child: ViolationText(
                      text: romText,
                      violations: result.violations,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '[$root]',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ] else
                  // No distinct romanization — single IPA-only dimmed line
                  // so the cell never double-renders identical text.
                  ViolationText(
                    text: '[$root]',
                    violations: result.violations,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // D-47 trailing ∅ badge in the top-right.
        Positioned(
          top: 2,
          right: 2,
          child: Text(
            '∅',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
// D-94 — 04-17. Per-intrinsic-combination section with its own lexeme picker.
// ---------------------------------------------------------------------------

class _IntrinsicSliceSection extends ConsumerStatefulWidget {
  const _IntrinsicSliceSection({
    required this.posId,
    required this.combination,
    required this.intrinsicDims,
    required this.allDims,
    required this.pool,
    required this.clickMode,
    this.lockedLexemeId,
  });

  final int posId;
  final Map<int, int> combination;
  final List<Dimension> intrinsicDims;
  final List<Dimension> allDims;
  final List<Lexeme> pool;
  final ParadigmClickMode clickMode;

  /// Issue 37b/39b — 04-18-03. When set, skip the word-picker dropdown
  /// and render the paradigm for exactly this lexeme. Used in word-detail
  /// mode where the host has already determined the correct intrinsic slice.
  final int? lockedLexemeId;

  @override
  ConsumerState<_IntrinsicSliceSection> createState() =>
      _IntrinsicSliceSectionState();
}

class _IntrinsicSliceSectionState
    extends ConsumerState<_IntrinsicSliceSection> {
  int? _selectedLexemeId;

  String _combinationLabel() {
    final parts = <String>[];
    for (final d in widget.intrinsicDims) {
      final levelId = widget.combination[d.id];
      if (levelId == null) continue;
      final levels = decodeLevelsJson(d.levelsJson);
      final level = levels.where((l) => l.id == levelId).firstOrNull;
      if (level != null) {
        parts.add('${d.name}: ${level.name}');
      }
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = _combinationLabel();

    // Issue 37b/39b: when lockedLexemeId is set, bypass the pool/dropdown
    // and render the paradigm for exactly that word.
    final lockedId = widget.lockedLexemeId;
    if (lockedId != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 4),
            _IntrinsicSliceTable(
              posId: widget.posId,
              lexemeId: lockedId,
              allDims: widget.allDims,
              clickMode: widget.clickMode,
            ),
            const Divider(),
          ],
        ),
      );
    }

    // Default selection = pool.first.id (D-95 per-slice first-matching).
    final effectiveId =
        _selectedLexemeId ?? (widget.pool.isNotEmpty ? widget.pool.first.id : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with intrinsic combination label.
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.pool.isNotEmpty) ...[
                const SizedBox(width: 16),
                // D-110 (plan 04-17): rom-aware display labels in the
                // per-intrinsic-slice word selector dropdown.
                Builder(builder: (context) {
                  final romEnabled =
                      ref.watch(romanizationEnabledProvider).asData?.value ?? true;
                  final romanize = ref.watch(romanizeProvider);
                  return DropdownButton<int>(
                    value: effectiveId,
                    items: [
                      for (final lex in widget.pool)
                        DropdownMenuItem(
                          value: lex.id,
                          child: Text(lexemeDisplayLabel(
                            lex,
                            romEnabled: romEnabled,
                            romanize: romanize,
                          )),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedLexemeId = v),
                  );
                }),
                // D-99 -- 04-17: base-form standard-form violations (base form only).
                if (effectiveId != null) ...[
                  const SizedBox(width: 8),
                  _BaseFormViolationBadge(lexemeId: effectiveId),
                ],
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (widget.pool.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No word with [$label] intrinsic levels yet. '
                'Create one to view this paradigm.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            _IntrinsicSliceTable(
              posId: widget.posId,
              lexemeId: effectiveId!,
              allDims: widget.allDims,
              clickMode: widget.clickMode,
            ),
          const Divider(),
        ],
      ),
    );
  }
}

/// Renders the paradigm table for a single intrinsic slice, using only
/// non-intrinsic dimensions as axes.
class _IntrinsicSliceTable extends ConsumerWidget {
  const _IntrinsicSliceTable({
    required this.posId,
    required this.lexemeId,
    required this.allDims,
    required this.clickMode,
  });

  final int posId;
  final int lexemeId;
  final List<Dimension> allDims;
  final ParadigmClickMode clickMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nonIntrinsicDims = allDims.where((d) => !d.intrinsic).toList();
    final axesAsync = ref.watch(paradigmAxesProvider(posId));
    final axes = axesAsync.asData?.value ?? const ParadigmAxes();

    // Issue 37a — 04-18-03. Handle 1 non-intrinsic dim: render a single-row
    // flat table (one column header per level, one data row).
    if (nonIntrinsicDims.length == 1) {
      final singleDim = nonIntrinsicDims.first;
      final chart = ref.watch(computedInflectedParadigmProvider(lexemeId));
      ParadigmCell? cellFor(Map<int, int> featureSet) =>
          chart.cellFor(featureSet);
      return _buildSingleDimSliceTable(
          context, ref, theme, cs, singleDim, cellFor);
    }
    if (nonIntrinsicDims.isEmpty) {
      return Center(
        child: Text(
          'No non-intrinsic dimensions.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    // Resolve row/col from non-intrinsic dims only.
    Dimension? rowDim = nonIntrinsicDims
        .where((d) => d.id == axes.rows)
        .cast<Dimension?>()
        .firstOrNull;
    Dimension? colDim = nonIntrinsicDims
        .where((d) => d.id == axes.cols)
        .cast<Dimension?>()
        .firstOrNull;
    if (rowDim == null || colDim == null) {
      if (nonIntrinsicDims.length >= 2) {
        rowDim ??= nonIntrinsicDims[0];
        colDim ??= nonIntrinsicDims[1];
      } else {
        return const Center(child: Text('Need 2+ non-intrinsic dimensions.'));
      }
    }

    final extraDims = nonIntrinsicDims
        .where((d) => d.id != rowDim!.id && d.id != colDim!.id)
        .toList();
    final extraLevelLists =
        extraDims.map((d) => decodeLevelsJson(d.levelsJson)).toList();

    // Single slice for this sub-table (extra non-intrinsic dims).
    var slices = <Map<int, int>>[const {}];
    if (extraDims.isNotEmpty) {
      var acc = <Map<int, int>>[{}];
      for (var i = 0; i < extraDims.length; i++) {
        final dim = extraDims[i];
        final levels = extraLevelLists[i];
        final next = <Map<int, int>>[];
        for (final a in acc) {
          for (final l in levels) {
            next.add({...a, dim.id: l.id});
          }
        }
        acc = next;
      }
      slices = acc;
    }

    final chart = ref.watch(computedInflectedParadigmProvider(lexemeId));
    ParadigmCell? cellFor(Map<int, int> featureSet) =>
        chart.cellFor(featureSet);

    final rowLevels = decodeLevelsJson(rowDim.levelsJson);
    final colLevels = decodeLevelsJson(colDim.levelsJson);

    // For simplicity, render the first slice (or the only slice).
    // Multi-slice sub-tables within intrinsic slices would need tabs,
    // but for now render sequentially.
    return Column(
      children: [
        for (final sliceKey in slices) ...[
          if (slices.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                extraDims
                    .map((d) {
                      final levels = decodeLevelsJson(d.levelsJson);
                      final lid = sliceKey[d.id];
                      final level =
                          levels.where((l) => l.id == lid).firstOrNull;
                      return level?.abbr ?? '?';
                    })
                    .join(' · '),
                style: theme.textTheme.labelSmall,
              ),
            ),
          _buildSliceTable(
            context, ref, theme, cs, rowDim, colDim, rowLevels, colLevels,
            sliceKey, cellFor,
          ),
        ],
      ],
    );
  }

  Widget _buildSliceTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    Dimension rowDim,
    Dimension colDim,
    List<DimensionLevel> rowLevels,
    List<DimensionLevel> colLevels,
    Map<int, int> sliceKey,
    ParadigmCell? Function(Map<int, int>) cellFor,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    clickMode: clickMode,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Issue 37a — 04-18-03. Single-dim slice table for intrinsic POSes with
  /// exactly 1 non-intrinsic dimension. Renders a header row + one data row.
  Widget _buildSingleDimSliceTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
    Dimension dim,
    ParadigmCell? Function(Map<int, int>) cellFor,
  ) {
    final levels = decodeLevelsJson(dim.levelsJson);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final lvl in levels)
                Container(
                  width: 80,
                  height: 32,
                  alignment: Alignment.center,
                  color: cs.surfaceContainerLow,
                  child: Text(
                    lvl.abbr,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              for (final lvl in levels)
                _ParadigmCellWidget(
                  lexemeId: lexemeId,
                  featureSet: {dim.id: lvl.id},
                  cell: cellFor({dim.id: lvl.id}),
                  clickMode: clickMode,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// D-99 -- 04-17. Base-form violation badge for the paradigm viewer header.
// Shows combined phonotactic + standard-form violations for the selected
// lexeme's IPA (base form only, NOT inflected cells).
// ---------------------------------------------------------------------------

class _BaseFormViolationBadge extends ConsumerWidget {
  const _BaseFormViolationBadge({required this.lexemeId});

  final int lexemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
    final lexeme = lexemeAsync.asData?.value;
    if (lexeme == null) return const SizedBox.shrink();
    if (lexeme.isPhonologicalException) return const SizedBox.shrink();

    final validate = ref.watch(phonotacticValidatorProvider);
    final phonoResult = validate(word: lexeme.ipa);
    final sfViolations =
        ref.watch(standardFormViolationsProvider(lexemeId)).asData?.value ??
            const [];
    final combined = [...phonoResult.violations, ...sfViolations];
    if (combined.isEmpty) return const SizedBox.shrink();

    return ViolationText(
      text: '[${lexeme.ipa}]',
      violations: combined,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
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
