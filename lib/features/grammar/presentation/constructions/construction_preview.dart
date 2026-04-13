import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/construction_providers.dart';
import '../../data/particle_providers.dart';

/// Live preview widget for a phrase construction.
///
/// Substitutes real lexicon words for each slot:
/// - gloss_tag slots: looks up the first closed-class word with that gloss tag
/// - pos slots: looks up the first root lexeme with that POS abbreviation
///
/// Phase 10 AGRAM-02.
class ConstructionPreview extends ConsumerWidget {
  const ConstructionPreview({
    super.key,
    required this.constructionId,
  });

  final int constructionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slotsAsync = ref.watch(constructionSlotsProvider(constructionId));
    final closedClassAsync = ref.watch(closedClassLexemeListProvider);
    final rootLexemesAsync = ref.watch(rootLexemeListProvider);
    final posListAsync = ref.watch(posListProvider);

    final slots = slotsAsync.asData?.value ?? [];
    final closedClassWords = closedClassAsync.asData?.value ?? [];
    final rootLexemes = rootLexemesAsync.asData?.value ?? [];
    final posList = posListAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: slots.isEmpty
              ? Text(
                  'Add slots to define this construction\'s pattern.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              : _buildPreviewText(
                  context,
                  theme,
                  slots,
                  closedClassWords,
                  rootLexemes,
                  posList,
                ),
        ),
      ],
    );
  }

  Widget _buildPreviewText(
    BuildContext context,
    ThemeData theme,
    List<ConstructionSlot> slots,
    List<Lexeme> closedClassWords,
    List<Lexeme> rootLexemes,
    List<PartsOfSpeechData> posList,
  ) {
    final spans = <InlineSpan>[];

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (i > 0) {
        spans.add(const TextSpan(text: ' '));
      }

      if (slot.slotType == 'gloss_tag') {
        final match = closedClassWords.where(
          (l) =>
              l.glossTag?.toUpperCase() == slot.slotValue.toUpperCase(),
        ).firstOrNull;

        if (match != null) {
          spans.add(TextSpan(text: match.ipa));
        } else {
          spans.add(
            TextSpan(
              text: '(no ${slot.slotValue} particle defined)',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
      } else {
        // pos slot — find first lexeme whose POS abbreviation matches
        final matchingPos = posList.where(
          (p) =>
              p.abbreviation.toUpperCase() == slot.slotValue.toUpperCase(),
        ).firstOrNull;

        Lexeme? match;
        if (matchingPos != null) {
          match = rootLexemes.where(
            (l) => l.partOfSpeech == matchingPos.name,
          ).firstOrNull;
        }

        if (match != null) {
          spans.add(TextSpan(text: match.ipa));
        } else {
          spans.add(
            TextSpan(
              text: '(no ${slot.slotValue} word in lexicon)',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
