import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../project/data/project_providers.dart';
import '../../data/grammar_providers.dart';
import '../../data/typology_providers.dart';
import '../../domain/paradigm_axes.dart';

/// Row/column dimension selector for a paradigm table (D-26).
///
/// Renders two dropdowns (Rows, Columns) over the POS's dimensions. Changes
/// are persisted to `project_settings` via [writeParadigmAxes] — no explicit
/// save button, matching the TypologyPage auto-save pattern from 04-04.
///
/// Hidden entirely when the POS has fewer than 2 dimensions (nothing
/// meaningful to configure).
class AxisConfigBar extends ConsumerWidget {
  const AxisConfigBar({super.key, required this.posId});

  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    final axesAsync = ref.watch(paradigmAxesProvider(posId));
    final axes = axesAsync.asData?.value ?? const ParadigmAxes();
    if (dims.length < 2) return const SizedBox.shrink();

    final db = ref.watch(currentDatabaseProvider);

    Future<void> persist(ParadigmAxes newAxes) async {
      if (db == null) return;
      await writeParadigmAxes(db, posId: posId, axes: newAxes);
    }

    List<int> tabsFor(int? rows, int? cols) => dims
        .where((d) => d.id != rows && d.id != cols)
        .map((d) => d.id)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Text('Rows:', style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: axes.rows,
            items: dims
                .map((d) =>
                    DropdownMenuItem(value: d.id, child: Text(d.name)))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              // Picking rows == cols bumps the cols slot to null so the user
              // has to re-pick it — prevents a silently-collapsed table.
              final nextCols = axes.cols == v ? null : axes.cols;
              await persist(ParadigmAxes(
                rows: v,
                cols: nextCols,
                tabs: tabsFor(v, nextCols),
              ));
            },
          ),
          const SizedBox(width: 16),
          Text('Columns:', style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: axes.cols,
            items: dims
                .where((d) => d.id != axes.rows)
                .map((d) =>
                    DropdownMenuItem(value: d.id, child: Text(d.name)))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              await persist(ParadigmAxes(
                rows: axes.rows,
                cols: v,
                tabs: tabsFor(axes.rows, v),
              ));
            },
          ),
        ],
      ),
    );
  }
}
