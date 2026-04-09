import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../phonology/data/phonotactic_providers.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/phonotactic_dsl.dart';
import '../../../phonology/domain/word_generator.dart';
import '../../data/morphology_providers.dart';
import '../../domain/morphology_dsl.dart';
import '../../domain/morphology_engine.dart';

/// Standalone morphology preview panel for the rules page.
///
/// Modeled on [WordGeneratorPanel] from the phonology feature.
/// Shows sample words with all active rules applied in sequence,
/// displaying both IPA and romanized forms. Regenerate button produces
/// fresh random words.
class MorphologyPreviewPanel extends ConsumerStatefulWidget {
  const MorphologyPreviewPanel({super.key});

  @override
  ConsumerState<MorphologyPreviewPanel> createState() =>
      _MorphologyPreviewPanelState();
}

class _MorphologyPreviewPanelState
    extends ConsumerState<MorphologyPreviewPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Watch all inputs — rebuild triggers fresh word generation
    final romanize = ref.watch(romanizeProvider);
    final inventory = ref.watch(phonemeInventoryProvider);
    final templates = ref.watch(parsedTemplatesProvider).when(
          data: (v) => v,
          loading: () => <ParsedTemplate>[],
          error: (_, _) => <ParsedTemplate>[],
        );
    final constraints = ref.watch(parsedConstraintsProvider).when(
          data: (v) => v,
          loading: () => <ConstraintRule>[],
          error: (_, _) => <ConstraintRule>[],
        );
    final rulesAsync = ref.watch(morphologicalRuleListProvider);
    final allDbRules = rulesAsync.asData?.value ?? [];

    final rewriteRules = ref.watch(parsedRewriteRulesProvider);

    // Generate extra candidates, apply rewrite rules, then filter to only
    // words that pass phonotactic constraints — so base words are valid
    // before morphological transforms are applied.
    final gen = WordGenerator();
    final candidates = gen.generateWords(
      templates: templates,
      inventory: inventory,
      count: 80, // over-generate to have enough after filtering
      minSyllables: 1,
      maxSyllables: 3,
    );
    final words = <String>[];
    for (final raw in candidates) {
      final rewritten = gen.applyRewriteRules(
        word: raw,
        rules: rewriteRules,
        inventory: inventory,
      );
      if (constraints.isEmpty) {
        words.add(rewritten);
      } else {
        final v = gen.validateWord(
          word: rewritten,
          constraints: constraints,
          inventory: inventory,
        );
        if (v.isValid) words.add(rewritten);
      }
      if (words.length >= 20) break;
    }

    // Parse all active rules into domain models
    final activeRules = <MorphologicalRule>[];
    for (final dbRule in allDbRules) {
      if (!dbRule.isActive) continue;
      final parsed =
          parseMorphDsl(dbRule.source, id: dbRule.id, name: dbRule.name);
      if (parsed.isValid && parsed.rule != null) {
        activeRules.add(parsed.rule!);
      }
    }

    final engine = const MorphologyEngine();

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
                      'Morphology Preview',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      activeRules.isEmpty
                          ? 'No active rules.'
                          : '${activeRules.length} active rule(s) applied in order.',
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

        const Divider(height: 1),

        // ---- Word list ------------------------------------------------------
        Expanded(
          child: words.isEmpty
              ? Center(
                  child: Text(
                    'Define phonotactic templates and phonemes to preview.',
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
                    final root = words[i];

                    // Apply all active rules in sequence
                    var current = root;
                    var rulesApplied = 0;
                    for (final rule in activeRules) {
                      final result =
                          engine.applyRule(rule, current, inventory);
                      if (result case MorphSuccess(:final form)) {
                        current = form;
                        rulesApplied++;
                      }
                    }

                    final derived = current != root ? current : null;

                    // Validate derived form
                    ValidationResult? validation;
                    if (derived != null && constraints.isNotEmpty) {
                      validation = gen.validateWord(
                        word: derived,
                        constraints: constraints,
                        inventory: inventory,
                      );
                    }

                    final romanizedRoot = romanize(root);
                    final romanizedDerived =
                        derived != null ? romanize(derived) : null;

                    return _MorphWordRow(
                      root: root,
                      romanizedRoot: romanizedRoot,
                      derived: derived,
                      romanizedDerived: romanizedDerived,
                      rulesApplied: rulesApplied,
                      violations: validation?.violations ?? [],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MorphWordRow extends StatelessWidget {
  const _MorphWordRow({
    required this.root,
    required this.romanizedRoot,
    required this.derived,
    required this.romanizedDerived,
    required this.rulesApplied,
    required this.violations,
  });

  final String root;
  final String romanizedRoot;
  final String? derived;
  final String? romanizedDerived;
  final int rulesApplied;
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasViolations = violations.isNotEmpty;
    final showRomanizedRoot =
        romanizedRoot.isNotEmpty && romanizedRoot != root;
    final showRomanizedDerived = romanizedDerived != null &&
        romanizedDerived!.isNotEmpty &&
        romanizedDerived != derived;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Root word
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(root, style: theme.textTheme.bodyMedium),
                if (showRomanizedRoot)
                  Text(
                    '/ $romanizedRoot /',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),

          // Arrow
          if (derived != null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Icon(Icons.arrow_forward, size: 14),
            ),

          // Derived word
          if (derived != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: hasViolations
                        ? violations
                            .map((v) => v.ruleDescription)
                            .join('; ')
                        : '',
                    child: hasViolations
                        ? Text(
                            derived!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: cs.error,
                              decorationStyle: TextDecorationStyle.wavy,
                            ),
                          )
                        : Text(derived!, style: theme.textTheme.bodyMedium),
                  ),
                  if (showRomanizedDerived)
                    Text(
                      '/ $romanizedDerived /',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),

          if (derived == null)
            Expanded(
              child: Text(
                'no match',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Violation icon
          if (hasViolations)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.warning_amber_outlined,
                size: 14,
                color: cs.error,
              ),
            ),

          // Rules applied count
          if (rulesApplied > 1)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: '$rulesApplied rules applied',
                child: Text(
                  '($rulesApplied)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
