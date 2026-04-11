import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../morphology/data/morphology_providers.dart';
import 'dimension_editor_panel.dart';
import 'pos_crud_dialog.dart';

/// POS & Dimensions master-detail page — Phase 4 plan 04-04 (D-23 / D-32).
///
/// Left panel: POS list scoped to the current project with an "Add POS"
/// button that opens `showPosCrudDialog`.
/// Right panel: empty-state prompt or [DimensionEditorPanel] for the
/// currently-selected POS.
class PosDimensionsPage extends ConsumerStatefulWidget {
  const PosDimensionsPage({super.key});

  @override
  ConsumerState<PosDimensionsPage> createState() => _PosDimensionsPageState();
}

class _PosDimensionsPageState extends ConsumerState<PosDimensionsPage> {
  int? _selectedPosId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? const [];

    // Auto-select the first POS on first data arrival so the right pane
    // is not permanently empty in the common "one project, one POS" case.
    if (_selectedPosId == null && posList.isNotEmpty) {
      // no-op: selection is an explicit user action; leaving the right pane
      // at the "Select a POS" hint is the correct empty-state per UI-SPEC.
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Material(
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Parts of Speech',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add POS',
                        onPressed: () => showPosCrudDialog(context, ref),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: posList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No parts of speech yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: posList.length,
                          itemBuilder: (ctx, i) {
                            final pos = posList[i];
                            final selected = pos.id == _selectedPosId;
                            return ListTile(
                              title: Text('${pos.name} (${pos.abbreviation})'),
                              selected: selected,
                              selectedTileColor: cs.primaryContainer,
                              onTap: () =>
                                  setState(() => _selectedPosId = pos.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: cs.outlineVariant),
        Expanded(
          child: _selectedPosId == null
              ? Center(
                  child: Text(
                    'Select a Part of Speech to edit its dimensions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : DimensionEditorPanel(posId: _selectedPosId!),
        ),
      ],
    );
  }
}
