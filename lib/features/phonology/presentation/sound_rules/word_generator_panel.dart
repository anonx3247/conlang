import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/phonotactic_providers.dart';
import '../../data/romanization_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import '../../domain/word_generator.dart';

/// Live word generation preview panel.
///
/// Shows N generated IPA words alongside their romanized forms.
/// Words auto-regenerate on a 300ms debounce when templates or inventory
/// change. A "Regenerate" button forces a new batch.
///
/// Phonotactic violations are flagged with a red underline and tooltip
/// (spell-check style) when the active constraints mark a generated word's
/// subsequences as forbidden.
class WordGeneratorPanel extends ConsumerStatefulWidget {
  const WordGeneratorPanel({super.key});

  @override
  ConsumerState<WordGeneratorPanel> createState() => _WordGeneratorPanelState();
}

class _WordGeneratorPanelState extends ConsumerState<WordGeneratorPanel> {
  int _minSyllables = 1;
  int _maxSyllables = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Watch all inputs — rebuild triggers word regeneration below
    final romanize = ref.watch(romanizeProvider);
    final constraints = ref.watch(parsedConstraintsProvider).when(
          data: (v) => v,
          loading: () => <ConstraintRule>[],
          error: (_, e) => <ConstraintRule>[],
        );
    final inventory = ref.watch(phonemeInventoryProvider);
    final templates = ref.watch(parsedTemplatesProvider).when(
          data: (v) => v,
          loading: () => <ParsedTemplate>[],
          error: (_, e) => <ParsedTemplate>[],
        );
    final rewriteRules = ref.watch(parsedRewriteRulesProvider);

    // Generate words, then apply rewrite rules to each.
    final gen = WordGenerator();
    final rawWords = gen.generateWords(
      templates: templates,
      inventory: inventory,
      count: 20,
      minSyllables: _minSyllables,
      maxSyllables: _maxSyllables,
    );
    final words = rawWords.map((w) => gen.applyRewriteRules(
      word: w,
      rules: rewriteRules,
      inventory: inventory,
    )).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Header --------------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Word Preview',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Generated from active templates and inventory.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Regenerate words',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        ),

        // ---- Syllable count slider ------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Syllables:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text('$_minSyllables',
                  style: theme.textTheme.labelSmall),
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
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ),

        const Divider(height: 1),

        // ---- Word list ------------------------------------------------------
        Expanded(
          child: words.isEmpty
              ? Center(
                  child: Text(
                    'Define templates and add phonemes to preview words.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: words.length,
                  itemBuilder: (_, i) {
                    final word = words[i];
                    final validation = WordGenerator().validateWord(
                      word: word,
                      constraints: constraints,
                      inventory: inventory,
                    );
                    final romanized = romanize(word);
                    return _WordRow(
                      word: word,
                      romanized: romanized,
                      violations: validation.violations,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Word row with violation highlighting
// ---------------------------------------------------------------------------

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.word,
    required this.romanized,
    required this.violations,
  });

  final String word;
  final String romanized;
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasViolations = violations.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          // IPA word (with violation underline if any)
          Tooltip(
            message: hasViolations
                ? violations.map((v) => v.ruleDescription).join('; ')
                : '',
            child: hasViolations
                ? _ViolationText(word: word, violations: violations)
                : Text(
                    word,
                    style: theme.textTheme.bodyMedium,
                  ),
          ),

          // Romanized form
          if (romanized.isNotEmpty && romanized != word) ...[
            const SizedBox(width: 8),
            Text(
              '/ $romanized /',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],

          // Violation flag icon
          if (hasViolations)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: cs.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders a word with red wavy underline on violating character ranges.
class _ViolationText extends StatelessWidget {
  const _ViolationText({
    required this.word,
    required this.violations,
  });

  final String word;
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build a set of character indices that are in violation ranges.
    final violatedIndices = <int>{};
    for (final v in violations) {
      for (var i = v.position; i < v.position + v.length && i < word.length; i++) {
        violatedIndices.add(i);
      }
    }

    if (violatedIndices.isEmpty) {
      return Text(word, style: theme.textTheme.bodyMedium);
    }

    // Build TextSpans: normal runs and violated runs.
    final spans = <TextSpan>[];
    var i = 0;
    while (i < word.length) {
      if (violatedIndices.contains(i)) {
        // Start of a violation run
        var j = i;
        while (j < word.length && violatedIndices.contains(j)) {
          j++;
        }
        spans.add(TextSpan(
          text: word.substring(i, j),
          style: theme.textTheme.bodyMedium?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: cs.error,
            decorationStyle: TextDecorationStyle.wavy,
            color: cs.error,
          ),
        ));
        i = j;
      } else {
        // Normal run
        var j = i;
        while (j < word.length && !violatedIndices.contains(j)) {
          j++;
        }
        spans.add(TextSpan(
          text: word.substring(i, j),
          style: theme.textTheme.bodyMedium,
        ));
        i = j;
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}
