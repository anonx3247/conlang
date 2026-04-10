import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../phonology/data/phonotactic_providers.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/phonotactic_dsl.dart';
import '../../../phonology/domain/word_generator.dart';

/// Inspiration panel for the word creation form.
///
/// Adapts the [WordGeneratorPanel] pattern: generates candidate IPA words
/// from active phonotactic templates and phoneme inventory. Tapping a word
/// calls [onWordSelected] to fill the creation form's IPA field.
///
/// Per D-08 — shown to the right of the word creation form.
class InspirationPanel extends ConsumerStatefulWidget {
  const InspirationPanel({
    super.key,
    required this.onWordSelected,
  });

  /// Called when the user taps a word candidate.
  final ValueChanged<String> onWordSelected;

  @override
  ConsumerState<InspirationPanel> createState() => _InspirationPanelState();
}

class _InspirationPanelState extends ConsumerState<InspirationPanel> {
  int _minSyllables = 1;
  int _maxSyllables = 3;
  // Counter used to force rebuild (regenerate) on button press.
  int _regenerateKey = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final inventory = ref.watch(phonemeInventoryProvider);
    final romanize = ref.watch(romanizeProvider);
    final templates = ref.watch(parsedTemplatesProvider).when(
          data: (v) => v,
          loading: () => <ParsedTemplate>[],
          error: (_, __) => <ParsedTemplate>[],
        );
    final rewriteRules = ref.watch(parsedRewriteRulesProvider);

    // Rebuild _words whenever _regenerateKey changes.
    // ignore: unused_local_variable
    final _ = _regenerateKey;

    // Generate phonemic (raw) candidates and compute their phonetic
    // (surface) transcription for display. The tap handler passes the
    // RAW form downstream so the word creation form's romanize() call
    // sees phonemic input, not the rewritten surface form. See
    // word_generator_panel.dart for the full rationale.
    final gen = WordGenerator();
    final rawWords = gen.generateWords(
      templates: templates,
      inventory: inventory,
      count: 12,
      minSyllables: _minSyllables,
      maxSyllables: _maxSyllables,
    );
    final phoneticWords = rawWords
        .map((w) => gen.applyRewriteRules(
              word: w,
              rules: rewriteRules,
              inventory: inventory,
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Header -------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspiration',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Tap a word to use it.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Regenerate',
                onPressed: () => setState(() => _regenerateKey++),
              ),
            ],
          ),
        ),

        // ---- Syllable controls -------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
              Text(
                'Syllables:',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text('$_minSyllables',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
              Expanded(
                child: RangeSlider(
                  values: RangeValues(
                    _minSyllables.toDouble(),
                    _maxSyllables.toDouble(),
                  ),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  labels: RangeLabels(
                    _minSyllables.toString(),
                    _maxSyllables.toString(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _minSyllables = v.start.round();
                      _maxSyllables = v.end.round();
                    });
                  },
                ),
              ),
              Text('$_maxSyllables',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),

        const Divider(height: 1),

        // ---- Word candidates -----------------------------------------------
        Expanded(
          child: rawWords.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Define templates and add phonemes to see word suggestions.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: rawWords.length,
                  itemBuilder: (context, index) {
                    final rawWord = rawWords[index];
                    final phoneticWord = phoneticWords[index];
                    final romanized = romanize(rawWord);
                    final showRomanized =
                        romanized.isNotEmpty && romanized != phoneticWord;
                    return InkWell(
                      // Pass the RAW (phonemic) form so word_creation_form
                      // can romanize() it correctly.
                      onTap: () => widget.onWordSelected(rawWord),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: showRomanized
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    romanized,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '[$phoneticWord]',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                phoneticWord,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  color: cs.primary,
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
