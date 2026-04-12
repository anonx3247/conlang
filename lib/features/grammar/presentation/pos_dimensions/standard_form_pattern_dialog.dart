import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/grammar_providers.dart';
import '../../domain/standard_form_branch.dart';
import '../../../phonology/data/phonotactic_providers.dart';

/// D-98 -- 04-17. Dialog for editing the standard-form pattern (list of
/// [StandardFormBranch]es) for a specific (dimension, level) pair.
///
/// Branches are OR-combined: a lexeme whose intrinsic level matches this
/// level must satisfy at least one branch to pass standard-form validation.
///
/// Accessed from the level chip's standard-form icon in
/// `dimension_editor_panel.dart` (BLOCKER-2 slot order).
class StandardFormPatternDialog extends ConsumerStatefulWidget {
  const StandardFormPatternDialog({
    super.key,
    required this.dimId,
    required this.dimName,
    required this.levelId,
    required this.levelName,
  });

  final int dimId;
  final String dimName;
  final int levelId;
  final String levelName;

  @override
  ConsumerState<StandardFormPatternDialog> createState() =>
      _StandardFormPatternDialogState();
}

class _StandardFormPatternDialogState
    extends ConsumerState<StandardFormPatternDialog> {
  final List<_BranchDraft> _drafts = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final dao = ref.read(standardFormPatternDaoProvider);
    if (dao == null) {
      setState(() => _loaded = true);
      return;
    }
    final existing = await dao.getPattern(widget.dimId, widget.levelId);
    if (!mounted) return;
    setState(() {
      _drafts.clear();
      if (existing != null) {
        for (final b in existing) {
          _drafts.add(_BranchDraft(
            kind: b.kind,
            controller: TextEditingController(text: b.literal),
          ));
        }
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.controller.dispose();
    }
    super.dispose();
  }

  void _addBranch() {
    setState(() {
      _drafts.add(_BranchDraft(
        kind: BranchKind.endsWith,
        controller: TextEditingController(),
      ));
    });
  }

  void _removeBranch(int index) {
    setState(() {
      _drafts[index].controller.dispose();
      _drafts.removeAt(index);
    });
  }

  Future<void> _save() async {
    final dao = ref.read(standardFormPatternDaoProvider);
    if (dao == null) return;
    final branches = _drafts
        .where((d) => d.controller.text.trim().isNotEmpty)
        .map((d) => StandardFormBranch(
              kind: d.kind,
              literal: d.controller.text.trim(),
            ))
        .toList();
    if (branches.isEmpty) {
      await dao.deletePattern(widget.dimId, widget.levelId);
    } else {
      await dao.upsertPattern(widget.dimId, widget.levelId, branches);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Best-effort live preview for a branch literal: expands V/C class refs
  /// using the project's phoneme inventory and returns sample match strings.
  String _livePreview(String literal, BranchKind kind) {
    final inventory = ref.read(phonemeInventoryProvider);
    if (literal.isEmpty) return '';

    // Simple expansion: replace each V with each vowel, each C with each
    // consonant, and produce the first few results. This is a best-effort
    // preview, not the full engine evaluation.
    final samples = <String>[];
    _expand(literal, 0, '', inventory.vowels, inventory.consonants, samples);
    if (samples.isEmpty) return '(no expansions)';
    final preview = samples.take(8).join(', ');
    return samples.length > 8 ? '$preview, ...' : preview;
  }

  static void _expand(
    String pattern,
    int pos,
    String current,
    List<String> vowels,
    List<String> consonants,
    List<String> results,
  ) {
    if (results.length >= 12) return; // cap expansion
    if (pos >= pattern.length) {
      results.add(current);
      return;
    }
    final ch = pattern[pos];
    if (ch == 'V' && vowels.isNotEmpty) {
      for (final v in vowels) {
        _expand(pattern, pos + 1, current + v, vowels, consonants, results);
      }
    } else if (ch == 'C' && consonants.isNotEmpty) {
      for (final c in consonants) {
        _expand(pattern, pos + 1, current + c, vowels, consonants, results);
      }
    } else {
      _expand(pattern, pos + 1, current + ch, vowels, consonants, results);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AlertDialog(
        content: Center(child: CircularProgressIndicator()),
      );
    }

    return AlertDialog(
      title: Text('${widget.dimName} \u2192 ${widget.levelName}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Standard-form branches (OR-combined):',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _drafts.length; i++) _buildBranchRow(i),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addBranch,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add branch'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildBranchRow(int index) {
    final draft = _drafts[index];
    final preview = _livePreview(draft.controller.text, draft.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<BranchKind>(
                value: draft.kind,
                items: const [
                  DropdownMenuItem(
                    value: BranchKind.startsWith,
                    child: Text('starts with'),
                  ),
                  DropdownMenuItem(
                    value: BranchKind.endsWith,
                    child: Text('ends with'),
                  ),
                  DropdownMenuItem(
                    value: BranchKind.contains,
                    child: Text('contains'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => draft.kind = v);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.controller,
                  decoration: const InputDecoration(
                    hintText: 'Pattern (e.g. ar, Vr)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _removeBranch(index),
              ),
            ],
          ),
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                'Matches: $preview',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BranchDraft {
  _BranchDraft({required this.kind, required this.controller});
  BranchKind kind;
  final TextEditingController controller;
}
