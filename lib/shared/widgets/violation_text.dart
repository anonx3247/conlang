import 'package:flutter/material.dart';

import '../../features/phonology/domain/word_generator.dart';

/// Renders a word with a red wavy underline on phonotactic violation ranges.
///
/// Extracted from the private `_ViolationText` widget in
/// `word_generator_panel.dart` for reuse across the app (PHON-05).
///
/// Shows a tooltip with pipe-separated violation descriptions on hover.
/// When there are no violations, renders as a plain [Text] widget.
///
/// Usage:
/// ```dart
/// ViolationText(
///   text: 'ptaki',
///   validationResult: result,
/// )
/// ```
class ViolationText extends StatelessWidget {
  const ViolationText({
    super.key,
    required this.text,
    required this.violations,
    this.style,
  });

  /// The IPA word string to display.
  final String text;

  /// The list of phonotactic violations for this word.
  final List<Violation> violations;

  /// Optional base text style. Falls back to [TextTheme.bodyMedium].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseStyle = style ?? theme.textTheme.bodyMedium;
    final hasViolations = violations.isNotEmpty;

    // Build a set of character indices that are in violation ranges.
    final violatedIndices = <int>{};
    for (final v in violations) {
      for (var i = v.position; i < v.position + v.length && i < text.length; i++) {
        violatedIndices.add(i);
      }
    }

    Widget wordWidget;
    if (violatedIndices.isEmpty) {
      wordWidget = Text(text, style: baseStyle);
    } else {
      // Build TextSpans: normal runs and violated runs.
      final spans = <TextSpan>[];
      var i = 0;
      while (i < text.length) {
        if (violatedIndices.contains(i)) {
          // Start of a violation run
          var j = i;
          while (j < text.length && violatedIndices.contains(j)) {
            j++;
          }
          spans.add(TextSpan(
            text: text.substring(i, j),
            style: baseStyle?.copyWith(
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
          while (j < text.length && !violatedIndices.contains(j)) {
            j++;
          }
          spans.add(TextSpan(
            text: text.substring(i, j),
            style: baseStyle,
          ));
          i = j;
        }
      }
      wordWidget = RichText(text: TextSpan(children: spans));
    }

    if (!hasViolations) return wordWidget;

    // Wrap in Tooltip with pipe-separated violation descriptions (per UI-SPEC
    // Copywriting Contract: "[Violated rule description]" pipe-separated).
    return Tooltip(
      message: violations.map((v) => v.ruleDescription).join(' | '),
      child: wordWidget,
    );
  }
}
