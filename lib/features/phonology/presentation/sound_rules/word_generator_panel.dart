import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/violation_text.dart';
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

    // Generate phonemic (raw) words, then derive their phonetic (surface)
    // transcription via the rewrite rules.
    //
    // IMPORTANT: Rewrite rules produce the PHONETIC transcription shown in
    // [brackets]. Romanization and phonotactic validation must both operate
    // on the RAW phonemic form, not the rewritten surface form — otherwise
    // `s -> z / V_V` would mangle romanization (e.g. /asa/ should romanize
    // as "asa", not "aza", even though it surfaces as [aza]).
    final gen = WordGenerator();
    final rawWords = gen.generateWords(
      templates: templates,
      inventory: inventory,
      count: 20,
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
          child: rawWords.isEmpty
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
                  itemCount: rawWords.length,
                  itemBuilder: (_, i) {
                    final rawWord = rawWords[i];
                    final phoneticWord = phoneticWords[i];
                    // Validate phonotactics on the phonemic (raw) form —
                    // phonotactic rules are defined over phonemes, not
                    // surface forms.
                    final validation = gen.validateWord(
                      word: rawWord,
                      constraints: constraints,
                      inventory: inventory,
                    );
                    // Romanize the raw phonemic form, NOT the rewritten
                    // form. See the rawWords comment above.
                    final romanized = romanize(rawWord);
                    return _WordRow(
                      word: phoneticWord,
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
          // Romanized form (primary) or plain IPA when no romanization
          if (romanized.isNotEmpty && romanized != word) ...[
            Text(
              romanized,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            // IPA in square brackets as secondary (with violation underline if any)
            ViolationText(
              text: '[$word]',
              violations: violations,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ] else ...[
            // Plain IPA only (no romanization to show)
            ViolationText(
              text: word,
              violations: violations,
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

