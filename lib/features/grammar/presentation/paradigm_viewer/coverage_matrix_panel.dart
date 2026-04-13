import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/grammar_providers.dart';
import '../../data/paradigm_coverage_provider.dart';
import '../../domain/coverage_matrix.dart';
import '../../domain/dimension_level.dart' show DimensionLevel, decodeLevelsJson, formatAbbr;

/// Coverage matrix side panel (D-15 / D-91).
///
/// 240px fixed-width column showing one row per Cartesian cell of the
/// referenced-dim axes (D-91 intrinsic-aware). Each row renders a
/// coloured dot: green when the cell is covered by at least one active
/// inflectional rule, red otherwise.
///
/// Data source: [paradigmCoverageMatrixProvider] which returns a
/// [CoverageMatrix] (BLOCKER-3: [FeatureSetKey]-keyed cells for value
/// equality). When no rules reference any dim, the empty-state hint
/// surfaces instead of an empty list.
class CoverageMatrixPanel extends ConsumerWidget {
  const CoverageMatrixPanel({super.key, required this.posId});

  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    final matrix = ref.watch(paradigmCoverageMatrixProvider(posId));

    // Index dims + levels by id so we can render human-readable labels.
    final dimsById = {for (final d in dims) d.id: d};
    final levelsByDim = <int, Map<int, DimensionLevel>>{
      for (final d in dims)
        d.id: {
          for (final l in decodeLevelsJson(d.levelsJson)) l.id: l,
        },
    };

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'COVERAGE',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (matrix.axes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'No inflectional rules define axes for this POS yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  for (final entry in matrix.cells.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.value
                                  ? Colors.green.shade600
                                  : cs.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cellLabel(
                                matrix.axes,
                                entry.key,
                                dimsById,
                                levelsByDim,
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a readable cell label from axis dim ids and the cell's
  /// [FeatureSetKey]. Format: `"Gender=M, Number=SG"`. Uses the dim's
  /// display name and the level's abbr (falling back to name) for
  /// compactness in the 240-wide panel.
  String _cellLabel(
    List<int> axes,
    FeatureSetKey key,
    Map<int, Dimension> dimsById,
    Map<int, Map<int, DimensionLevel>> levelsByDim,
  ) {
    final parts = <String>[];
    for (final dimId in axes) {
      final dim = dimsById[dimId];
      final levelId = key[dimId];
      if (dim == null || levelId == null) continue;
      final level = levelsByDim[dimId]?[levelId];
      final abbrFormatted = formatAbbr(level?.abbr);
      final levelLabel = abbrFormatted.isNotEmpty
          ? abbrFormatted
          : (level?.name ?? '?');
      parts.add('${dim.name}=$levelLabel');
    }
    return parts.join(', ');
  }
}
