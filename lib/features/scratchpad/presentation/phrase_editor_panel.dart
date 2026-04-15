import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lexicon/data/phonotactic_validation_provider.dart';
import '../../phonology/data/phonotactic_providers.dart';
import '../data/gloss_index_provider.dart';
import '../data/scratchpad_providers.dart';
import '../domain/phrase_tokenizer.dart';
import 'interlinear_block.dart';

/// Right panel: text input field + live interlinear display + IPA toggle.
///
/// Owns two debounce timers:
/// - 300ms parse debounce: re-tokenizes input after typing pauses
/// - 1s auto-save debounce: persists to ScratchpadPhrases table
///
/// IPA toggle is per-phrase local state (reset when switching phrases).
class PhraseEditorPanel extends ConsumerStatefulWidget {
  const PhraseEditorPanel({
    super.key,
    required this.phraseId,
  });

  final int phraseId;

  @override
  ConsumerState<PhraseEditorPanel> createState() => _PhraseEditorPanelState();
}

class _PhraseEditorPanelState extends ConsumerState<PhraseEditorPanel> {
  final _textController = TextEditingController();
  final _translationController = TextEditingController();
  Timer? _parseDebounce;
  Timer? _saveDebounce;
  Timer? _translationSaveDebounce;
  List<PhraseToken> _tokens = const [];
  bool _showIpa = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPhrase();
  }

  Future<void> _loadPhrase() async {
    final dao = ref.read(scratchpadDaoProvider);
    if (dao == null) return;
    final phrase = await dao.getPhraseById(widget.phraseId);
    if (!mounted || phrase == null) return;
    _textController.text = phrase.originalText;
    _translationController.text = phrase.freeTranslation ?? '';
    setState(() => _loaded = true);
    // Initial parse
    _triggerParse();
  }

  void _onTextChanged(String value) {
    _parseDebounce?.cancel();
    _saveDebounce?.cancel();
    _parseDebounce = Timer(
      const Duration(milliseconds: 300),
      _triggerParse,
    );
    _saveDebounce = Timer(
      const Duration(milliseconds: 1000),
      _triggerSaveText,
    );
  }

  void _onTranslationChanged(String value) {
    _translationSaveDebounce?.cancel();
    _translationSaveDebounce = Timer(
      const Duration(milliseconds: 1000),
      _triggerSaveTranslation,
    );
  }

  void _triggerParse() {
    final glossIndex = ref.read(glossIndexProvider);
    final validate = ref.read(phonotacticValidatorProvider);
    final tokens = tokenizePhrase(
      input: _textController.text,
      glossIndex: glossIndex,
      validateWord: ({required String word}) => validate(word: word).isValid,
    );
    if (mounted) setState(() => _tokens = tokens);
  }

  Future<void> _triggerSaveText() async {
    final dao = ref.read(scratchpadDaoProvider);
    if (dao == null) return;
    await dao.updateOriginalText(widget.phraseId, _textController.text);
  }

  Future<void> _triggerSaveTranslation() async {
    final dao = ref.read(scratchpadDaoProvider);
    if (dao == null) return;
    final text = _translationController.text;
    await dao.updateFreeTranslation(
      widget.phraseId,
      text.isEmpty ? null : text,
    );
  }

  @override
  void dispose() {
    _parseDebounce?.cancel();
    _saveDebounce?.cancel();
    _translationSaveDebounce?.cancel();
    _textController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch the rewrite pipeline for IPA transcription
    final applyRewrite = ref.watch(applyRewritePipelineProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar row: IPA toggle
          Row(
            children: [
              const Spacer(),
              Tooltip(
                message: 'Toggle IPA transcription',
                child: IconButton(
                  icon: Text(
                    '/aɪ/',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _showIpa
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: () => setState(() => _showIpa = !_showIpa),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text input field
          TextField(
            controller: _textController,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              hintText: 'Type a phrase in your language...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
            style: theme.textTheme.bodyMedium,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          // Interlinear display
          if (_tokens.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: InterlinearBlock(
                  tokens: _tokens,
                  showIpa: _showIpa,
                  applyRewrite: applyRewrite,
                  translationController: _translationController,
                  onTranslationChanged: _onTranslationChanged,
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}
