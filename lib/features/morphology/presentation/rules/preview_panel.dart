import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/phonology/data/phonotactic_providers.dart';
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
    final sampleWords = ref.read(generatedWordsProvider);
    final rule = widget.rule;

    // Take up to 8 sample words.
    final words = sampleWords.take(8).toList();

    if (rule == null) {
      setState(() {
        _pending = false;
        _rows = [];
      });
      return;
    }

    final engine = const MorphologyEngine();
    final rows = <_PreviewRow>[];

    for (final word in words) {
      final result = engine.applyRule(rule, word, inventory);
      switch (result) {
        case MorphSuccess(:final form):
          rows.add(_PreviewRow(root: word, derived: form, error: null));
        case MorphNoMatch(:final reason):
          rows.add(_PreviewRow(root: word, derived: null, error: reason));
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
    final sampleWords = ref.watch(generatedWordsProvider);

    final hasInventory = inventory.consonants.isNotEmpty || inventory.vowels.isNotEmpty;
    final hasTemplates = sampleWords.isNotEmpty;

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
          child: Text(
            'Preview',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
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

  TableRow _buildRow(_PreviewRow row, ThemeData theme, ColorScheme cs) {
    final monoStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
    );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(row.root, style: monoStyle),
        ),
        const Icon(Icons.arrow_forward, size: 14),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: row.derived != null
              ? Text(row.derived!, style: monoStyle)
              : Text(
                  row.error ?? 'no match',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
          child: Text(
            'Preview',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
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
  });

  final String root;
  final String? derived;
  final String? error;
}
