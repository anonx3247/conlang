import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/grammar_providers.dart';
import '../../data/paradigm_coverage_provider.dart';
import '../../domain/dimension_level.dart';

/// Coverage matrix side panel (D-15).
///
/// 240px fixed-width column showing one row per (dimension, level) pair for
/// the selected POS. Each row renders a coloured dot: green when the pair
/// is covered by at least one active inflectional rule, red otherwise.
///
/// Data source: `paradigmCoverageMatrixProvider(posId)` (Task 1).
class CoverageMatrixPanel extends ConsumerWidget {
  const CoverageMatrixPanel({super.key, required this.posId});

  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    final coverage = ref.watch(paradigmCoverageMatrixProvider(posId));

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
          Expanded(
            child: ListView(
              children: [
                for (final dim in dims) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      dim.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final l in decodeLevelsJson(dim.levelsJson))
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (coverage[(dim.id, l.id)] ?? false)
                                  ? Colors.green.shade600
                                  : cs.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.abbr,
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
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
