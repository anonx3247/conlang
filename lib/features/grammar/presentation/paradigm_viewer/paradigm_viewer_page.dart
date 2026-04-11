import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../domain/pos_resolver.dart';
import 'axis_config_bar.dart';
import 'coverage_matrix_panel.dart';
import 'paradigm_table_widget.dart';

/// Grammar → Paradigm Viewer sub-tab (D-27, D-34).
///
/// Layout:
/// ```
/// [ POS picker ][ Word picker (filtered to POS) ]
/// [ AxisConfigBar ]
/// [ ParadigmTableWidget (Expanded) | CoverageMatrixPanel (240px) ]
/// ```
///
/// When no POS is selected, shows an empty state with a table icon and
/// hint text ("Select a POS to view its paradigm.") — this is what the
/// 04-04 router smoke test renders with no DB configured.
///
/// The word picker lists every lexeme whose resolved POS matches the
/// selected POS (via `posForLexeme`). Leaving the word picker on its
/// "(template)" default passes `lexemeId: -1` down to ParadigmTableWidget,
/// which `computedInflectedParadigmProvider` treats as an empty lexeme →
/// the table renders structural shell (headers + uncovered cells) for
/// the user to explore the paradigm shape.
class ParadigmViewerPage extends ConsumerStatefulWidget {
  const ParadigmViewerPage({super.key});

  @override
  ConsumerState<ParadigmViewerPage> createState() => _ParadigmViewerPageState();
}

class _ParadigmViewerPageState extends ConsumerState<ParadigmViewerPage> {
  int? _selectedPosId;
  int? _selectedLexemeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? const <PartsOfSpeechData>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // POS picker + word picker row.
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text('POS:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedPosId,
                hint: const Text('Select a POS'),
                items: posList
                    .map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedPosId = v;
                  _selectedLexemeId = null;
                }),
              ),
              const SizedBox(width: 24),
              if (_selectedPosId != null) _buildWordPicker(posList),
            ],
          ),
        ),
        if (_selectedPosId != null) AxisConfigBar(posId: _selectedPosId!),
        Expanded(
          child: _selectedPosId == null
              ? _emptyState(theme, cs)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ParadigmTableWidget(
                        lexemeId: _selectedLexemeId ?? -1,
                        posId: _selectedPosId!,
                      ),
                    ),
                    VerticalDivider(width: 1, color: cs.outlineVariant),
                    CoverageMatrixPanel(posId: _selectedPosId!),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a POS to view its paradigm.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordPicker(List<PartsOfSpeechData> posList) {
    final lexemesAsync = ref.watch(allLexemeListProvider);
    final lexemes = lexemesAsync.asData?.value ?? const <Lexeme>[];
    // Filter lexemes whose resolved POS matches _selectedPosId.
    final filtered = lexemes.where((lex) {
      final pos = posForLexeme(lex, posList);
      return pos?.id == _selectedPosId;
    }).toList();

    return Expanded(
      child: DropdownButton<int?>(
        value: _selectedLexemeId,
        hint: const Text('Word (optional — blank for template)'),
        isExpanded: true,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('(template)')),
          for (final l in filtered)
            DropdownMenuItem<int?>(value: l.id, child: Text(l.ipa)),
        ],
        onChanged: (v) => setState(() => _selectedLexemeId = v),
      ),
    );
  }
}
