import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../../project/data/project_providers.dart';
import '../../data/typology_providers.dart';
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

  /// G-01: restore the per-POS last-selected lexeme from project_settings
  /// when a POS is picked (either by user action or initial auto-select on
  /// first build). Falls back to leaving `_selectedLexemeId` null (which
  /// keeps the "(template)" picker default) when no stored value exists or
  /// the stored lexeme has been deleted since.
  Future<void> _restoreLastSelectedWord(int posId) async {
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    final stored = await readParadigmLastSelectedWord(db, posId);
    if (!mounted || _selectedPosId != posId) return;
    if (stored == null) {
      setState(() => _selectedLexemeId = null);
      return;
    }
    // Confirm the lexeme still exists (could have been deleted since the
    // last session) — gracefully fall back to the template default if not.
    final lex = await (db.select(db.lexemes)
          ..where((t) => t.id.equals(stored)))
        .getSingleOrNull();
    if (!mounted || _selectedPosId != posId) return;
    setState(() => _selectedLexemeId = lex == null ? null : stored);
  }

  void _onPosChanged(int? posId) {
    setState(() {
      _selectedPosId = posId;
      _selectedLexemeId = null;
    });
    if (posId != null) {
      // Fire-and-forget — no await so the picker stays responsive.
      _restoreLastSelectedWord(posId);
    }
  }

  void _onWordChanged(int? lexemeId) {
    setState(() => _selectedLexemeId = lexemeId);
    final posId = _selectedPosId;
    if (posId == null || lexemeId == null) return;
    final db = ref.read(currentDatabaseProvider);
    if (db == null) return;
    // Fire-and-forget write.
    writeParadigmLastSelectedWord(db, posId: posId, lexemeId: lexemeId);
  }

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
                onChanged: _onPosChanged,
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
        onChanged: _onWordChanged,
      ),
    );
  }
}
