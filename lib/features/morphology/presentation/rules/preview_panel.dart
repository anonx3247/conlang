import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/phonology/data/phonotactic_providers.dart';
import '../../../../features/phonology/data/romanization_providers.dart';
import '../../../../features/phonology/domain/phonotactic_dsl.dart';
import '../../../../features/phonology/domain/word_generator.dart';
import '../../data/morphology_providers.dart';
import '../../domain/morphology_dsl.dart';
import '../../domain/morphology_engine.dart';

/// Preview table that shows sample words and their derived forms for a given rule.
///
/// Accepts the current [MorphologicalRule] built from the editor form state.
/// Re-evaluates with a 300ms debounce whenever [rule] changes.
class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({
    super.key,
    required this.rule,
  });

  /// The rule to preview. May be null if the form state is incomplete.
  final MorphologicalRule? rule;

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  Timer? _debounce;
  List<_PreviewRow> _rows = [];
  bool _pending = false;
  bool _stackMode = false;

  @override
  void didUpdateWidget(PreviewPanel old) {
    super.didUpdateWidget(old);
    // Restart debounce whenever rule changes.
    if (old.rule != widget.rule) {
      _scheduleRefresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    setState(() => _pending = true);
    _debounce = Timer(const Duration(milliseconds: 300), _evaluate);
  }

  void _evaluate() {
    if (!mounted) return;

    final inventory = ref.read(phonemeInventoryProvider);
    final rule = widget.rule;

    // Generate words locally (not from cached provider) so regenerate works.
    final templates = ref.read(parsedTemplatesProvider).when(
      data: (v) => v,
      loading: () => <ParsedTemplate>[],
      error: (_, _) => <ParsedTemplate>[],
    );
    final constraintsAsync = ref.read(parsedConstraintsProvider);
    final constraints = constraintsAsync.asData?.value ?? [];
    final gen = WordGenerator();

    // Generate extra candidates, filter to only words that pass
    // phonotactic constraints, then feed PHONEMIC (raw) forms into the
    // morphology engine. Rewrite rules are applied LATER, to produce the
    // phonetic [bracket] transcription. See morphology_preview_panel.dart
    // for the full rationale.
    final candidates = gen.generateWords(
      templates: templates,
      inventory: inventory,
      count: 40, // over-generate to have enough after filtering
      minSyllables: 1,
      maxSyllables: 3,
    );
    final words = <String>[];
    for (final raw in candidates) {
      // Validate phonotactics on the phonemic (raw) form.
      if (constraints.isEmpty) {
        words.add(raw);
      } else {
        final v = gen.validateWord(
          word: raw,
          constraints: constraints,
          inventory: inventory,
        );
        if (v.isValid) words.add(raw);
      }
      if (words.length >= 8) break;
    }

    if (rule == null) {
      setState(() {
        _pending = false;
        _rows = [];
      });
      return;
    }

    // Reuse gen and constraints from above for post-morph violation checking.
    final engine = const MorphologyEngine();
    final rows = <_PreviewRow>[];

    if (_stackMode) {
      // Stack mode: apply all active rules in order, with the current rule
      // replacing its counterpart (or appended if new).
      final allRulesAsync = ref.read(morphologicalRuleListProvider);
      final allDbRules = allRulesAsync.asData?.value ?? [];

      // Build the ordered list of domain rules to apply.
      final orderedRules = <MorphologicalRule>[];
      var currentRuleInserted = false;
      for (final dbRule in allDbRules) {
        if (!dbRule.isActive) continue;
        if (dbRule.id == rule.id) {
          // Replace in-progress edit.
          orderedRules.add(rule);
          currentRuleInserted = true;
        } else {
          final parsed = parseMorphDsl(dbRule.source, id: dbRule.id, name: dbRule.name);
          if (parsed.isValid && parsed.rule != null) {
            orderedRules.add(parsed.rule!);
          }
        }
      }
      if (!currentRuleInserted) {
        // New rule not yet saved — append at end.
        orderedRules.add(rule);
      }

      for (final word in words) {
        var current = word;
        var rulesApplied = 0;
        // WR-02 fix: track whether any rule produced a MorphSuccess, so we
        // don't flag "no match" just because a later rule reverted the form
        // (e.g. A: a->e, B: e->a). The single-rule branch uses the engine
        // result directly; stack mode must match that semantics.
        var anySuccess = false;
        for (final r in orderedRules) {
          final result = engine.applyRule(r, current, inventory);
          switch (result) {
            case MorphSuccess(:final form):
              current = form;
              rulesApplied++;
              anySuccess = true;
            case MorphNoMatch():
            // no-op: continue with current form (Dart 3 pattern switches
            // do not fall through, so no explicit break is needed).
          }
        }

        // Validate the final derived form.
        ValidationResult? validation;
        if (constraints.isNotEmpty) {
          validation = gen.validateWord(
            word: current,
            constraints: constraints,
            inventory: inventory,
          );
        }

        rows.add(_PreviewRow(
          root: word,
          derived: anySuccess ? current : null,
          error: anySuccess ? null : 'no match',
          violations: validation,
          rulesApplied: rulesApplied,
          stackMode: true,
        ));
      }
    } else {
      // Single rule mode.
      for (final word in words) {
        final result = engine.applyRule(rule, word, inventory);
        switch (result) {
          case MorphSuccess(:final form):
            // Validate derived form against phonotactic constraints.
            ValidationResult? validation;
            if (constraints.isNotEmpty) {
              validation = gen.validateWord(
                word: form,
                constraints: constraints,
                inventory: inventory,
              );
            }
            rows.add(_PreviewRow(
              root: word,
              derived: form,
              error: null,
              violations: validation,
              rulesApplied: 1,
              stackMode: false,
            ));
          case MorphNoMatch(:final reason):
            rows.add(_PreviewRow(
              root: word,
              derived: null,
              error: reason,
              violations: null,
              rulesApplied: 0,
              stackMode: false,
            ));
        }
      }
    }

    setState(() {
      _pending = false;
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final inventory = ref.watch(phonemeInventoryProvider);
    final templates = ref.watch(parsedTemplatesProvider);
    // Watch so the [bracket] phonetic transcription refreshes when
    // rewrite rules are edited.
    ref.watch(parsedRewriteRulesProvider);

    // WR-01 fix: re-evaluate the morphology preview whenever the upstream
    // inputs change. Without this, `_rows` holds stale root/derived strings
    // computed against an old inventory/template/constraint snapshot while
    // `_buildRow` recomputes the [bracket] transcription against the NEW
    // rewrite rules — producing visibly inconsistent rows.
    ref.listen(phonemeInventoryProvider, (_, _) => _scheduleRefresh());
    ref.listen(parsedTemplatesProvider, (_, _) => _scheduleRefresh());
    ref.listen(parsedConstraintsProvider, (_, _) => _scheduleRefresh());
    ref.listen(parsedRewriteRulesProvider, (_, _) => _scheduleRefresh());

    final hasInventory = inventory.consonants.isNotEmpty || inventory.vowels.isNotEmpty;
    final hasTemplates = templates.asData?.value.isNotEmpty ?? false;

    if (!hasInventory) {
      return _emptyState(
        theme,
        cs,
        icon: Icons.piano_outlined,
        message: 'Define phonemes and phonotactic templates first to see a preview.',
      );
    }

    if (!hasTemplates) {
      return _emptyState(
        theme,
        cs,
        icon: Icons.sort_by_alpha_outlined,
        message: 'Add phonotactic templates on the Sound Rules page to generate sample words.',
      );
    }

    if (widget.rule == null) {
      return _emptyState(
        theme,
        cs,
        icon: Icons.preview_outlined,
        message: 'Build a rule above to see a preview.',
      );
    }

    if (_pending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rows.isEmpty) {
      return _emptyState(
        theme,
        cs,
        icon: Icons.hourglass_empty_outlined,
        message: 'No preview rows — check your rule definition.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: _stackMode ? 'Showing stacked rules' : 'Show single rule',
                child: IconButton(
                  icon: Icon(
                    Icons.layers,
                    size: 18,
                    color: _stackMode
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    setState(() => _stackMode = !_stackMode);
                    _scheduleRefresh();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Regenerate preview',
                onPressed: _scheduleRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FixedColumnWidth(32),
            2: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: _rows.map((row) => _buildRow(row, theme, cs)).toList(),
        ),
      ],
    );
  }

  // D-111 (plan 04-17): the preview panel MUST render via the same
  // romanize pipeline as paradigm_table_widget.dart cells. Specifically:
  //   - Use ref.watch(romanizeProvider), not ref.read — the preview must
  //     refresh when the mapping changes.
  //   - romanize() receives the RAW PHONEMIC form (engine output), never
  //     the post-rewrite phonetic. D-112 invariant.
  //   - showRomanized compares romanized != phonemic (not != phonetic).
  //   - When rom is hidden, display the phonemic form, not the phonetic.
  TableRow _buildRow(_PreviewRow row, ThemeData theme, ColorScheme cs) {
    // D-111: watch, not read — preview refreshes on mapping changes.
    final romanize = ref.watch(romanizeProvider);
    final rewriteRules = ref.read(parsedRewriteRulesProvider);
    final inventory = ref.read(phonemeInventoryProvider);
    final gen = WordGenerator();

    // Compute the phonetic (surface) transcription for display in
    // [brackets]. Romanization uses the phonemic (raw) form — D-112.
    String toPhonetic(String raw) => gen.applyRewriteRules(
          word: raw,
          rules: rewriteRules,
          inventory: inventory,
        );

    final monoStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
    );

    Widget derivedWidget;
    if (row.derived != null) {
      final hasViolation = row.violations != null && !row.violations!.isValid;
      // D-112: romanize the raw phonemic (row.derived), not the phonetic.
      final romanized = romanize(row.derived!);
      final phoneticDerived = toPhonetic(row.derived!);
      // D-112 parity: show rom when it differs from the PHONEMIC form,
      // not from the phonetic form. Mirrors _FilledCell in
      // paradigm_table_widget.dart.
      final showRomanized =
          romanized.isNotEmpty && romanized != row.derived;

      Widget ipaLabel = Text(
        '[$phoneticDerived]',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.55),
          decoration: hasViolation ? TextDecoration.underline : null,
          decorationColor: hasViolation ? cs.error : null,
          decorationStyle: hasViolation ? TextDecorationStyle.wavy : null,
        ),
      );

      if (hasViolation) {
        final tooltipParts = row.violations!.violations.map((v) {
          final desc = v.ruleDescription.isNotEmpty
              ? '${v.ruleDescription} at position ${v.position}'
              : 'Phonotactic violation at position ${v.position}';
          return desc;
        }).toList();
        ipaLabel = Tooltip(
          message: tooltipParts.join('\n'),
          child: ipaLabel,
        );
      }

      derivedWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRomanized)
            Text(romanized, style: monoStyle),
          ipaLabel,
        ],
      );
    } else {
      derivedWidget = Text(
        row.error ?? 'no match',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.error,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final arrowIcon = const Icon(Icons.arrow_forward, size: 14);

    // D-112 parity: romanize the raw phonemic root, compare against phonemic.
    // When rom is hidden, show the phonemic form (not phonetic).
    final romanizedRoot = romanize(row.root);
    final phoneticRoot = toPhonetic(row.root);
    final showRomanizedRoot =
        romanizedRoot.isNotEmpty && romanizedRoot != row.root;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            showRomanizedRoot ? romanizedRoot : '[$phoneticRoot]',
            style: monoStyle,
          ),
        ),
        row.stackMode && row.rulesApplied > 1
            ? Tooltip(
                message: '${row.rulesApplied} rules applied',
                child: arrowIcon,
              )
            : arrowIcon,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: derivedWidget,
        ),
      ],
    );
  }

  Widget _emptyState(
    ThemeData theme,
    ColorScheme cs, {
    required IconData icon,
    required String message,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: _stackMode ? 'Showing stacked rules' : 'Show single rule',
                child: IconButton(
                  icon: Icon(
                    Icons.layers,
                    size: 18,
                    color: _stackMode
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    setState(() => _stackMode = !_stackMode);
                    _scheduleRefresh();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Regenerate preview',
                onPressed: _scheduleRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewRow {
  const _PreviewRow({
    required this.root,
    required this.derived,
    required this.error,
    required this.violations,
    required this.rulesApplied,
    required this.stackMode,
  });

  final String root;
  final String? derived;
  final String? error;
  final ValidationResult? violations;
  final int rulesApplied;
  final bool stackMode;
}
