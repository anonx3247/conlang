// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/data/grammar_providers.dart';
import '../../../../grammar/domain/dimension_level.dart'
    show decodeLevelsJson, formatAbbr;
import '../../../../grammar/domain/tiebreak_detector.dart';

// ---------------------------------------------------------------------------
// POS / binding editor widgets — extracted from rule_editor_body.dart
// to keep each file under 500 lines.
// ---------------------------------------------------------------------------

/// Inflectional mode top section: multi-POS FilterChip picker (plan 04-11
/// D-55) + dimension chip rows per intersected dimension + validation hints +
/// live tiebreak banner (D-12).
///
/// Receives all needed state from [RuleEditorBody] via constructor parameters;
/// calls [onPosToggled], [onBindingChanged], and [onSaveBlockedReasonClear]
/// when the user interacts.
class InflectionalTopSection extends ConsumerWidget {
  const InflectionalTopSection({
    super.key,
    required this.posList,
    required this.inflectionalPosSet,
    required this.featureBindings,
    required this.tiebreakConflict,
    required this.cachedInflectionalRows,
    required this.existingRuleId,
    required this.onPosToggled,
    required this.onBindingChanged,
  });

  final List<db.PartsOfSpeechData> posList;
  final Set<int> inflectionalPosSet;
  final Map<int, int> featureBindings;
  final TiebreakConflict? tiebreakConflict;
  final List<db.MorphologicalRule> cachedInflectionalRows;
  final int? existingRuleId;

  /// Called when a POS chip is toggled. Passes the pos id and new selected state.
  final void Function(int posId, bool on) onPosToggled;

  /// Called when a dimension level chip is toggled.
  /// Passes the dim id and the level id (null = deselected).
  final void Function(int dimId, int? levelId) onBindingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Applies to', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),

        // Multi-POS picker (plan 04-11 D-55).
        Wrap(
          key: const ValueKey('inflectionalPosPickerWrap'),
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final pos in posList)
              FilterChip(
                label: Text('${pos.name} (${formatAbbr(pos.abbreviation)})'),
                tooltip: pos.name,
                selected: inflectionalPosSet.contains(pos.id),
                onSelected: (on) => onPosToggled(pos.id, on),
              ),
          ],
        ),
        if (inflectionalPosSet.isEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Select at least one POS above.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        const SizedBox(height: 12),

        // Dimension chip rows — only rendered when at least one POS selected.
        if (inflectionalPosSet.isNotEmpty)
          _DimensionChipRows(
            inflectionalPosSet: inflectionalPosSet,
            featureBindings: featureBindings,
            onBindingChanged: onBindingChanged,
          ),

        if (featureBindings.isEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Inflectional rules must bind at least one feature. '
            'Select at least one level chip above.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        if (tiebreakConflict != null)
          _TiebreakBanner(
            conflict: tiebreakConflict!,
            existingRuleId: existingRuleId,
          ),
      ],
    );
  }
}

/// Dimension chip rows for the intersected dimensions of [inflectionalPosSet].
class _DimensionChipRows extends ConsumerWidget {
  const _DimensionChipRows({
    required this.inflectionalPosSet,
    required this.featureBindings,
    required this.onBindingChanged,
  });

  final Set<int> inflectionalPosSet;
  final Map<int, int> featureBindings;
  final void Function(int dimId, int? levelId) onBindingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Watch every selected POS's dimension stream.
    final perPosDims = <List<db.Dimension>>[];
    for (final posId in inflectionalPosSet) {
      final async = ref.watch(dimensionsForPosProvider(posId));
      perPosDims.add(async.asData?.value ?? const <db.Dimension>[]);
    }

    // Intersect by dimension NAME.
    final List<db.Dimension> dims;
    if (perPosDims.any((l) => l.isEmpty)) {
      dims = const <db.Dimension>[];
    } else if (perPosDims.length == 1) {
      dims = perPosDims.first;
    } else {
      final names = perPosDims.first.map((d) => d.name).toSet();
      for (final list in perPosDims.skip(1)) {
        names.retainAll(list.map((d) => d.name));
      }
      dims = perPosDims.first.where((d) => names.contains(d.name)).toList();
    }

    if (dims.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          inflectionalPosSet.length > 1
              ? 'These POS share no common dimensions — rule cannot '
                  'bind any features.'
              : 'This POS has no dimensions yet. Add dimensions in '
                  'Grammar → POS & Dimensions to enable inflectional '
                  'binding.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final dim in dims)
          _DimensionChipRow(
            dim: dim,
            featureBindings: featureBindings,
            onBindingChanged: onBindingChanged,
          ),
      ],
    );
  }
}

/// A single dimension's chip row (label + level FilterChips).
class _DimensionChipRow extends StatelessWidget {
  const _DimensionChipRow({
    required this.dim,
    required this.featureBindings,
    required this.onBindingChanged,
  });

  final db.Dimension dim;
  final Map<int, int> featureBindings;
  final void Function(int dimId, int? levelId) onBindingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = decodeLevelsJson(dim.levelsJson);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(dim.name, style: theme.textTheme.bodyMedium),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: levels.map((l) {
                final selected = featureBindings[dim.id] == l.id;
                return FilterChip(
                  label: Text(formatAbbr(l.abbr)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) =>
                      onBindingChanged(dim.id, sel ? l.id : null),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiebreak conflict banner (D-12 / UI-SPEC).
class _TiebreakBanner extends StatelessWidget {
  const _TiebreakBanner({
    required this.conflict,
    required this.existingRuleId,
  });

  final TiebreakConflict conflict;
  final int? existingRuleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final otherNames = conflict.rules
        .where((r) => r.id != (existingRuleId ?? -1) && r.id != -1)
        .map((r) => r.name)
        .join(', ');
    final display = otherNames.isEmpty ? '(unnamed rule)' : otherNames;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        border: Border.all(color: cs.error),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_outlined, color: cs.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Conflict: This rule has the same specificity as '$display' "
              'and both match overlapping cells. '
              'Add a distinguishing dimension binding to resolve.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Derivational mode top section: Input POS + Output POS dropdowns (D-38) +
/// output intrinsic level pickers (plan 04-20-01) + auto-apply checkbox (D-59).
class DerivationalTopSection extends ConsumerWidget {
  const DerivationalTopSection({
    super.key,
    required this.posList,
    required this.inputPosId,
    required this.outputPosId,
    required this.outputIntrinsicLevels,
    required this.autoApply,
    required this.ruleName,
    required this.onInputPosChanged,
    required this.onOutputPosChanged,
    required this.onOutputIntrinsicLevelChanged,
    required this.onAutoApplyChanged,
  });

  final List<db.PartsOfSpeechData> posList;
  final int? inputPosId;
  final int? outputPosId;
  final Map<int, int> outputIntrinsicLevels;
  final bool autoApply;

  /// Used for template preview text ("parent meaning (ruleName)").
  final String ruleName;

  final void Function(int? posId) onInputPosChanged;
  final void Function(int? posId) onOutputPosChanged;
  final void Function(int dimId, int levelId) onOutputIntrinsicLevelChanged;
  final void Function(bool value) onAutoApplyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Input POS', style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: inputPosId,
          decoration: fieldDecoration,
          isExpanded: true,
          items: [
            for (final pos in posList)
              DropdownMenuItem<int>(
                value: pos.id,
                child: Text(
                  '${pos.name} (${formatAbbr(pos.abbreviation)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onInputPosChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.arrow_downward, size: 16),
            const SizedBox(width: 6),
            Text('Output POS', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: outputPosId,
          decoration: fieldDecoration,
          isExpanded: true,
          items: [
            for (final pos in posList)
              DropdownMenuItem<int>(
                value: pos.id,
                child: Text(
                  '${pos.name} (${formatAbbr(pos.abbreviation)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onOutputPosChanged,
        ),

        // Output intrinsic level pickers (plan 04-20-01).
        if (outputPosId != null)
          _OutputIntrinsicPicker(
            outputPosId: outputPosId!,
            outputIntrinsicLevels: outputIntrinsicLevels,
            onLevelChanged: onOutputIntrinsicLevelChanged,
          ),

        const SizedBox(height: 12),
        CheckboxListTile(
          value: autoApply,
          onChanged: (v) => onAutoApplyChanged(v ?? false),
          title: const Text('Auto-apply to all matching words'),
          subtitle: const Text(
            'Every matching-POS word gets a new derived lexeme automatically '
            'with a templated gloss',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (autoApply)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 2),
            child: Text(
              'Template: "parent meaning '
              '(${ruleName.isEmpty ? 'rule name' : ruleName})"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Output intrinsic level picker rows for derivational mode (plan 04-20-01).
class _OutputIntrinsicPicker extends ConsumerWidget {
  const _OutputIntrinsicPicker({
    required this.outputPosId,
    required this.outputIntrinsicLevels,
    required this.onLevelChanged,
  });

  final int outputPosId;
  final Map<int, int> outputIntrinsicLevels;
  final void Function(int dimId, int levelId) onLevelChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dimsAsync = ref.watch(dimensionsForPosProvider(outputPosId));
    final allDims = dimsAsync.asData?.value ?? const <db.Dimension>[];
    final intrinsicDims = allDims.where((d) => d.intrinsic).toList();
    if (intrinsicDims.isEmpty) return const SizedBox.shrink();

    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Output intrinsic levels', style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        for (final dim in intrinsicDims) ...[
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  dim.name,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: outputIntrinsicLevels[dim.id],
                  decoration: fieldDecoration,
                  isExpanded: true,
                  hint: const Text('Select level'),
                  items: [
                    for (final lvl in decodeLevelsJson(dim.levelsJson))
                      DropdownMenuItem<int>(
                        value: lvl.id,
                        child: Text(
                          '${lvl.name} (${formatAbbr(lvl.abbr)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onLevelChanged(dim.id, v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
