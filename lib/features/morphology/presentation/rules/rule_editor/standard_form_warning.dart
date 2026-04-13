// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/data/grammar_providers.dart';
import '../../../../grammar/data/standard_form_pattern_dao.dart';
import '../../../../grammar/domain/dimension_level.dart' show decodeLevelsJson;
import '../../../../grammar/domain/standard_form_branch.dart';
import '../../../../grammar/domain/standard_form_matcher.dart';
import '../../../../phonology/data/phonotactic_providers.dart';
import '../../../../phonology/data/romanization_bijection.dart';
import '../../../../phonology/data/romanization_providers.dart';
import '../../../../phonology/domain/word_generator.dart';
import '../../../domain/morphology_dsl.dart';
import '../../../domain/morphology_engine.dart';

// ---------------------------------------------------------------------------
// Shared warning widgets for rule_editor_body.dart — extracted to stay under
// 500 lines per file.
// ---------------------------------------------------------------------------

/// Shown in place of the full editor body when the romanization bijection
/// has conflicts (D-72).
class BijectionLockedView extends StatelessWidget {
  const BijectionLockedView({super.key, required this.violations});
  final List<BijectionViolation> violations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rule editor is locked until romanization conflicts '
                    'are resolved — see Phonology → Romanization.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final v in violations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${v.detail}', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D-gap-3 (plan 04-19-03): Applies [previewRule] to a sample generated word
/// and checks whether the output form violates any standard-form pattern for
/// [outputPosId]'s intrinsic dimensions. Shows a warning banner if found.
class StandardFormDerivationWarning extends ConsumerWidget {
  const StandardFormDerivationWarning({
    super.key,
    required this.outputPosId,
    required this.previewRule,
    this.outputIntrinsicLevels = const {},
  });

  final int outputPosId;
  final MorphologicalRule previewRule;

  /// Selected output intrinsic levels (dimId -> levelId). When non-empty,
  /// only the selected level per dimension is checked — avoids false warnings.
  final Map<int, int> outputIntrinsicLevels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(phonemeInventoryProvider);
    final romanize = ref.watch(romanizeProvider);
    final templates = ref.watch(parsedTemplatesProvider);
    final constraintsAsync = ref.watch(parsedConstraintsProvider);
    final constraints = constraintsAsync.asData?.value ?? const [];
    final templateList = templates.asData?.value ?? const [];

    if (templateList.isEmpty ||
        (inventory.consonants.isEmpty && inventory.vowels.isEmpty)) {
      return const SizedBox.shrink();
    }

    final gen = WordGenerator();
    final candidates = gen.generateWords(
      templates: templateList,
      inventory: inventory,
      count: 20,
      minSyllables: 1,
      maxSyllables: 2,
    );

    String? sampleOutput;
    final engine = const MorphologyEngine();
    for (final word in candidates) {
      if (constraints.isNotEmpty) {
        final v = gen.validateWord(
            word: word, constraints: constraints, inventory: inventory);
        if (!v.isValid) continue;
      }
      final result = engine.applyRule(previewRule, word, inventory);
      if (result case MorphSuccess(:final form)) {
        sampleOutput = form;
        break;
      }
    }
    if (sampleOutput == null) return const SizedBox.shrink();
    final romForm = romanize(sampleOutput);

    final dimsAsync = ref.watch(dimensionsForPosProvider(outputPosId));
    final dims = dimsAsync.asData?.value ?? const [];
    final intrinsicDims = dims.where((d) => d.intrinsic).toList();
    if (intrinsicDims.isEmpty) return const SizedBox.shrink();

    final dao = ref.read(standardFormPatternDaoProvider);
    if (dao == null) return const SizedBox.shrink();

    return FutureBuilder<List<String>>(
      future: _computeViolations(
          intrinsicDims, dao, romForm, inventory, outputIntrinsicLevels),
      builder: (context, snap) {
        final warnings = snap.data ?? const [];
        if (warnings.isEmpty) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 18, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warnings.join('; '),
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<String>> _computeViolations(
    List<db.Dimension> intrinsicDims,
    StandardFormPatternDao dao,
    String romForm,
    PhonemeInventory inventory,
    Map<int, int> selectedLevels,
  ) async {
    const matcher = StandardFormMatcher();
    final warnings = <String>[];
    for (final dim in intrinsicDims) {
      final levels = decodeLevelsJson(dim.levelsJson);
      final selectedLevelId = selectedLevels[dim.id];
      final levelsToCheck = selectedLevelId != null
          ? levels.where((l) => l.id == selectedLevelId)
          : levels;
      for (final level in levelsToCheck) {
        final branches = await dao.getPattern(dim.id, level.id);
        if (branches == null || branches.isEmpty) continue;
        if (matcher.matches(romForm, branches, inventory)) continue;
        final kindLabel = branches.map((b) {
          final kl = switch (b.kind) {
            BranchKind.startsWith => 'starts with',
            BranchKind.endsWith => 'ends with',
            BranchKind.contains => 'contains',
          };
          return '$kl "${b.literal}"';
        }).join(' OR ');
        warnings.add('${level.name} ${dim.name}: should $kindLabel');
      }
    }
    return warnings;
  }
}
