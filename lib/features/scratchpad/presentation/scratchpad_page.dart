import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scratchpad_providers.dart';
import 'phrase_editor_panel.dart';
import 'phrase_list_panel.dart';

/// Top-level scratchpad page with two-panel layout:
/// left sidebar (200px, phrase list) and right panel (editor + interlinear).
class ScratchpadPage extends ConsumerStatefulWidget {
  const ScratchpadPage({super.key});

  @override
  ConsumerState<ScratchpadPage> createState() => _ScratchpadPageState();
}

class _ScratchpadPageState extends ConsumerState<ScratchpadPage> {
  int? _selectedPhraseId;

  Future<void> _createNewPhrase() async {
    final dao = ref.read(scratchpadDaoProvider);
    if (dao == null) return;
    final id = await dao.createPhrase();
    setState(() => _selectedPhraseId = id);
  }

  Future<void> _deletePhrase(int id) async {
    final dao = ref.read(scratchpadDaoProvider);
    if (dao == null) return;
    await dao.deletePhrase(id);
    if (_selectedPhraseId == id) {
      setState(() => _selectedPhraseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrasesAsync = ref.watch(scratchpadPhrasesProvider);

    return Row(
      children: [
        // Left sidebar: phrase list (200px fixed width)
        SizedBox(
          width: 200,
          child: PhraseListPanel(
            phrasesAsync: phrasesAsync,
            selectedPhraseId: _selectedPhraseId,
            onPhraseSelected: (id) => setState(() => _selectedPhraseId = id),
            onNewPhrase: _createNewPhrase,
            onDeletePhrase: _deletePhrase,
          ),
        ),
        // Vertical divider
        const VerticalDivider(width: 1, thickness: 1),
        // Right panel: editor
        Expanded(
          child: _selectedPhraseId != null
              ? PhraseEditorPanel(
                  key: ValueKey(_selectedPhraseId),
                  phraseId: _selectedPhraseId!,
                )
              : _buildEmptyState(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No phrases yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Click "New Phrase" to start writing in your language.',
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
