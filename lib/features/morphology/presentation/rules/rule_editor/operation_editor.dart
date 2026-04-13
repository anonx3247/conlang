// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../phonology/data/phonotactic_providers.dart';
import '../../../../phonology/data/romanization_providers.dart';
import '../../../../phonology/domain/word_generator.dart' show Violation;
import '../../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../../../../shared/widgets/violation_text.dart';
import '../../../domain/morphology_dsl.dart';
import '../../../domain/phoneme_literal_scanner.dart';
import 'form_state_models.dart';

// ---------------------------------------------------------------------------
// Operation row + fields — extracted from rule_editor_dialog.dart (D-14)
// ---------------------------------------------------------------------------

/// Renders a single operation row (type dropdown + type-specific fields +
/// optional remove button). Calls [onChanged] whenever the user edits any
/// field so the parent can trigger a rebuild.
class OperationRow extends ConsumerWidget {
  const OperationRow({
    super.key,
    required this.op,
    required this.branchOpCount,
    required this.onChanged,
    required this.onRemove,
  });

  final OpState op;

  /// Total number of ops in this branch — controls remove-button visibility.
  final int branchOpCount;

  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Type dropdown. Wrapped in a SizedBox(width: 120) so the intrinsic
          // width of the longest label ("Whole-word override (irregular)")
          // doesn't blow past the dialog's left-column budget — plan 04-05
          // Rule 3 fix (widget tests revealed a 165px overflow at 820px
          // dialog width).
          SizedBox(
            width: 120,
            child: DropdownButton<OpType>(
              value: op.type,
              isDense: true,
              isExpanded: true,
              items: OpType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                op.type = v;
                onChanged();
              },
            ),
          ),

          const SizedBox(width: 8),

          // Type-specific fields
          Expanded(child: _OpFields(op: op, onChanged: onChanged)),

          // Remove operation button (only if more than one op in this branch)
          if (branchOpCount > 1)
            IconButton(
              icon: Icon(Icons.close,
                  size: 14, color: cs.error.withValues(alpha: 0.7)),
              tooltip: 'Remove operation',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Type-specific fields for a single [OpState].
class _OpFields extends ConsumerWidget {
  const _OpFields({required this.op, required this.onChanged});

  final OpState op;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const fieldDecoration = InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );

    // D-73 + D-78 (plan 04-15): compute the rom-aware helper text once
    // per rebuild. When rom is enabled, every literal-phoneme field shows
    // the auto-convert blurb AND the `.` escape-hatch discoverability
    // hint. When rom is disabled, fields show a simple "phonemic IPA"
    // note so users know what notation the field expects.
    final romEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? true;
    final String literalHelperText = romEnabled
        ? 'rom (auto-converted to phonemic on save) — '
            'use . to force a glyph boundary (e.g. at.ha vs atha)'
        : 'phonemic IPA';

    void rebuild(String _) => onChanged();

    return switch (op.type) {
      OpType.prefix || OpType.suffix => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IpaTextField(
              controller: op.affixCtrl,
              decoration: fieldDecoration.copyWith(
                hintText: 'IPA affix, e.g. in, ɯ',
                helperText: literalHelperText,
                helperMaxLines: 2,
              ),
              onChanged: rebuild,
            ),
            PhonemeViolationRow(text: op.affixCtrl.text, scope: 'op'),
          ],
        ),
      OpType.infix => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: IpaTextField(
                    controller: op.affixCtrl,
                    decoration: fieldDecoration.copyWith(
                      hintText: 'IPA affix',
                      helperText: literalHelperText,
                      helperMaxLines: 2,
                    ),
                    onChanged: rebuild,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: op.posCtrl,
                    decoration: fieldDecoration.copyWith(hintText: 'after C#'),
                    keyboardType: TextInputType.number,
                    onChanged: rebuild,
                  ),
                ),
              ],
            ),
            PhonemeViolationRow(text: op.affixCtrl.text, scope: 'op'),
          ],
        ),
      OpType.ablaut => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: op.ablautFromCtrl,
                        decoration: fieldDecoration.copyWith(
                          hintText: 'from',
                          helperText: literalHelperText,
                          helperMaxLines: 2,
                        ),
                        onChanged: rebuild,
                      ),
                      PhonemeViolationRow(
                          text: op.ablautFromCtrl.text, scope: 'op'),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: op.ablautToCtrl,
                        decoration: fieldDecoration.copyWith(
                          hintText: 'to',
                          helperText: literalHelperText,
                          helperMaxLines: 2,
                        ),
                        onChanged: rebuild,
                      ),
                      PhonemeViolationRow(
                          text: op.ablautToCtrl.text, scope: 'op'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int?>(
                  value: op.ablautCount,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('all')),
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                  ],
                  onChanged: (v) {
                    op.ablautCount = v;
                    onChanged();
                  },
                ),
                Text(
                  'occurrences',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                DropdownButton<AblautDirection>(
                  value: op.ablautDirection,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: AblautDirection.fromStart,
                      child: Text('from beginning'),
                    ),
                    DropdownMenuItem(
                      value: AblautDirection.fromEnd,
                      child: Text('from end'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    op.ablautDirection = v;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      OpType.template => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: op.templateCtrl,
              decoration: fieldDecoration.copyWith(
                hintText: 'e.g. 1a23aa',
                helperText: 'Digits = consonant slots, other chars literal',
              ),
              onChanged: rebuild,
            ),
            PhonemeViolationRow(text: op.templateCtrl.text, scope: 'template'),
          ],
        ),
      OpType.reduplication => Row(
          children: [
            const Text('Scope:'),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: op.redupScope,
              isDense: true,
              items: ['full', 'CV', 'C']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                op.redupScope = v;
                onChanged();
              },
            ),
            const SizedBox(width: 12),
            const Text('Position:'),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: op.redupPosition,
              isDense: true,
              items: ['prefix', 'suffix']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                op.redupPosition = v;
                onChanged();
              },
            ),
          ],
        ),
      OpType.suppletive => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IpaTextField(
              controller: op.suppletiveCtrl,
              decoration: fieldDecoration.copyWith(
                  hintText:
                      'Replaces entire word (e.g. went for go, mice for mouse)'),
              onChanged: rebuild,
            ),
            PhonemeViolationRow(text: op.suppletiveCtrl.text, scope: 'op'),
          ],
        ),
    };
  }
}

/// D-81 plan 04-16 / G-69 — renders a compact inline phoneme-violation
/// warning beneath a literal rule-editor TextField. Returns
/// [SizedBox.shrink] when the scanner reports no violations for [text].
/// Watches [phonemeInventoryProvider] for reactivity — adding the
/// missing phoneme to the inventory clears the warning automatically.
///
/// This widget is intentionally SOFT-WARNING-ONLY: it never blocks
/// save, never triggers state changes, never exposes a callback. It is
/// a pure read-side indicator.
class PhonemeViolationRow extends ConsumerWidget {
  const PhonemeViolationRow({
    super.key,
    required this.text,
    required this.scope,
  });

  /// The literal text from the associated TextField's controller.
  final String text;

  /// One of:
  ///   - 'op'       — wrap in a synthetic SuffixOp (generic literal field)
  ///   - 'template' — wrap in a synthetic TemplateOp (digit-slot skipping)
  ///   - 'cond'     — wrap in a synthetic PatternCond (class-ref skipping)
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) return const SizedBox.shrink();
    final inventory = ref.watch(phonemeInventoryProvider);

    // D-81 04-16 user feedback fix (2026-04-11): when romanization is
    // enabled, the rule editor displays the rom form of stored phonemic
    // literals. The scanner must receive the DEROMANIZED phonemic form so
    // the inventory check compares phonemes against phonemes.
    final romEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? true;
    final deromanize = ref.watch(deromanizeProvider);
    final scanText = romEnabled ? deromanize(text) : text;

    // Build a minimal synthetic rule with a single branch + single
    // op/cond containing [scanText], run the scanner, and render a
    // ViolationText if any violations are reported.
    final synthetic = switch (scope) {
      'cond' => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: [PatternCond(scanText)],
              operations: const [SuffixOp('')],
            ),
          ],
        ),
      'template' => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: const [],
              operations: [TemplateOp(scanText)],
            ),
          ],
        ),
      _ => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: const [],
              operations: [SuffixOp(scanText)],
            ),
          ],
        ),
    };
    final parsed = ParsedMorphRule.success(source: '', rule: synthetic);
    final violations = const PhonemeLiteralScanner().scan(parsed, inventory);
    if (violations.isEmpty) return const SizedBox.shrink();

    // Map PhonemeViolation -> Violation for ViolationText.
    final mapped = violations
        .map((v) => Violation(
              position: v.literalOffset,
              length: v.length,
              ruleDescription:
                  "'${v.char}' is not in the phoneme inventory (did you mean to define it first?)",
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ViolationText(
        text: scanText,
        violations: mapped,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
