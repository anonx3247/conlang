import 'package:flutter/material.dart';

import '../domain/phrase_tokenizer.dart';

/// Leipzig-format interlinear gloss display.
///
/// Renders 2-4 tiers:
///  1. Original text — tokens with per-token error decoration
///  2. Gloss — Leipzig abbreviations per token
///  3. IPA (optional) — phonetic transcription via rewrite pipeline
///  4. Free translation — single editable text field spanning full width
///
/// Token alignment: each column uses [IntrinsicWidth] so gloss cells
/// align beneath their original text tokens.
class InterlinearBlock extends StatelessWidget {
  const InterlinearBlock({
    super.key,
    required this.tokens,
    required this.showIpa,
    required this.applyRewrite,
    required this.translationController,
    required this.onTranslationChanged,
  });

  final List<PhraseToken> tokens;
  final bool showIpa;
  final String Function(String phonemic) applyRewrite;
  final TextEditingController translationController;
  final ValueChanged<String> onTranslationChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Token grid: tiers 1-3
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < tokens.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                IntrinsicWidth(
                  child: _TokenColumn(
                    token: tokens[i],
                    showIpa: showIpa,
                    applyRewrite: applyRewrite,
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Tier separator
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(
            height: 1,
            color: colorScheme.outlineVariant,
          ),
        ),
        // Tier 4: Free translation (editable, spans full width)
        TextField(
          controller: translationController,
          onChanged: onTranslationChanged,
          decoration: InputDecoration(
            hintText: 'Add free translation\u2026',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// A single token column in the interlinear display, showing 2-3 tiers
/// vertically aligned for one token.
class _TokenColumn extends StatelessWidget {
  const _TokenColumn({
    required this.token,
    required this.showIpa,
    required this.applyRewrite,
    required this.isDark,
  });

  final PhraseToken token;
  final bool showIpa;
  final String Function(String phonemic) applyRewrite;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tier 1: Original text with error decoration
        Tooltip(
          message: token.isUnknown
              ? 'Unknown \u2014 not found in lexicon'
              : token.hasViolation
                  ? 'Phonotactic violation'
                  : '',
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: token.isUnknown
                  ? (isDark
                      ? Colors.amber.shade700.withValues(alpha: 0.3)
                      : Colors.amber.shade300.withValues(alpha: 0.3))
                  : null,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              token.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: token.hasViolation
                    ? TextDecoration.underline
                    : null,
                decorationColor: token.hasViolation
                    ? colorScheme.error
                    : null,
                decorationStyle: token.hasViolation
                    ? TextDecorationStyle.wavy
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2), // tier gap per UI-SPEC
        // Tier 2: Gloss label
        Container(
          constraints: const BoxConstraints(minWidth: 24),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            token.match.glossLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: token.isUnknown
                  ? colorScheme.onSurface.withValues(alpha: 0.4)
                  : null,
            ),
          ),
        ),
        // Tier 3: IPA (optional)
        if (showIpa) ...[
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '/${applyRewrite(token.match.ipa)}/',
              style: theme.textTheme.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
