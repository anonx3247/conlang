import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../phonology/data/romanization_providers.dart';
import '../../data/lexeme_providers.dart';

/// Visual derivation tree widget.
///
/// Computes derived forms on-the-fly via [computedDerivedFormsProvider]
/// (backed by [MorphologyEngine]) — no stored derived-form rows are read.
/// This satisfies LEX-02: "derived words appear automatically" whenever
/// morphological rules are active, without any separate storage trigger.
///
/// Exception overrides (per D-05) are shown in [Colors.amber] with an
/// "Exception" badge; the engine-computed form is shown in normal style.
class DerivationTreeWidget extends ConsumerWidget {
  const DerivationTreeWidget({
    super.key,
    required this.rootIpa,
    required this.rootId,
  });

  final String rootIpa;
  final int rootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final romanize = ref.watch(romanizeProvider);
    final derivedForms = ref.watch(computedDerivedFormsProvider(rootId));
    final exceptionsAsync = ref.watch(exceptionsForLexemeProvider(rootId));
    final exceptions = exceptionsAsync.asData?.value ?? [];

    // Build a map from ruleId -> overrideForm for O(1) lookup.
    final exceptionMap = {
      for (final e in exceptions) e.ruleId: e.overrideForm,
    };

    final romanizedRoot = romanize(rootIpa);
    final showRomanizedRoot = romanizedRoot.isNotEmpty && romanizedRoot != rootIpa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Derivations',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${derivedForms.length} derived form${derivedForms.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (derivedForms.isEmpty)
          Text(
            'No derivations. Add morphological rules to see derived forms.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          )
        else
          // Root node
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Root node row
              _TreeNode(
                label: showRomanizedRoot ? romanizedRoot : rootIpa,
                sublabel: showRomanizedRoot ? '[$rootIpa]' : null,
                level: 0,
                isException: false,
                theme: theme,
              ),
              // Derived form nodes
              ...derivedForms.map((result) {
                final overrideForm = exceptionMap[result.ruleId];
                final hasException = overrideForm != null;
                final ipa = hasException ? overrideForm : result.derivedIpa;
                final romanized = romanize(ipa);
                final showRomanized = romanized.isNotEmpty && romanized != ipa;
                return _TreeNode(
                  label: showRomanized ? romanized : ipa,
                  sublabel: hasException
                      ? '${result.ruleName} — Exception'
                      : result.ruleName,
                  ipaLabel: showRomanized ? '[$ipa]' : null,
                  level: 1,
                  isException: hasException,
                  theme: theme,
                );
              }),
            ],
          ),
      ],
    );
  }
}

/// A single node in the derivation tree with a connector line and indentation.
class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.label,
    required this.level,
    required this.isException,
    required this.theme,
    this.sublabel,
    this.ipaLabel,
  });

  final String label;
  final String? sublabel;
  final String? ipaLabel;
  final int level;
  final bool isException;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final indent = level * 24.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (level > 0) ...[
            // Connector line
            Container(
              width: 12,
              height: 1,
              color: cs.outlineVariant,
              margin: const EdgeInsets.only(right: 4),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: isException ? Colors.amber : cs.onSurface,
                    fontWeight: isException ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (ipaLabel != null)
                  Text(
                    ipaLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: isException
                          ? Colors.amber.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ),
          if (isException)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                'Exception',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: Colors.amber,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
