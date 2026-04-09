import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart' as db;
import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../data/morphology_providers.dart';
import '../../domain/morphology_dsl.dart';
import 'preview_panel.dart';

// ---------------------------------------------------------------------------
// Form state models
// ---------------------------------------------------------------------------

/// Operation types the editor supports (matches MorphOperation sealed class).
enum OpType {
  prefix('Prefix (add to start)'),
  suffix('Suffix (add to end)'),
  infix('Infix (insert inside)'),
  ablaut('Vowel change'),
  template('Root template'),
  reduplication('Reduplication (copy)'),
  suppletive('Whole-word override (irregular)');

  const OpType(this.label);
  final String label;
}

/// Mutable state for a single operation row in the form.
class _OpState {
  OpType type;
  // Shared/specific field controllers
  final TextEditingController affixCtrl = TextEditingController();       // prefix/suffix/infix
  final TextEditingController posCtrl = TextEditingController(text: '1'); // infix position
  final TextEditingController ablautFromCtrl = TextEditingController();
  final TextEditingController ablautToCtrl = TextEditingController();
  final TextEditingController templateCtrl = TextEditingController();
  String redupScope;    // 'full' | 'CV' | 'C'
  String redupPosition; // 'prefix' | 'suffix'
  final TextEditingController suppletiveCtrl = TextEditingController();
  // Ablaut direction and count
  AblautDirection ablautDirection;
  int? ablautCount; // null = all

  _OpState()
      : type = OpType.suffix,
        redupScope = 'CV',
        redupPosition = 'prefix',
        ablautDirection = AblautDirection.fromStart,
        ablautCount = null;

  void dispose() {
    affixCtrl.dispose();
    posCtrl.dispose();
    ablautFromCtrl.dispose();
    ablautToCtrl.dispose();
    templateCtrl.dispose();
    suppletiveCtrl.dispose();
  }

  /// Convert to domain [MorphOperation]. Returns null if fields are incomplete.
  MorphOperation? toOperation() {
    return switch (type) {
      OpType.prefix => affixCtrl.text.trim().isNotEmpty
          ? PrefixOp(affixCtrl.text.trim())
          : null,
      OpType.suffix => affixCtrl.text.trim().isNotEmpty
          ? SuffixOp(affixCtrl.text.trim())
          : null,
      OpType.infix => () {
          final affix = affixCtrl.text.trim();
          final pos = int.tryParse(posCtrl.text.trim()) ?? 1;
          return affix.isNotEmpty ? InfixOp(affix: affix, position: pos) : null;
        }(),
      OpType.ablaut => () {
          final from = ablautFromCtrl.text.trim();
          final to = ablautToCtrl.text.trim();
          return (from.isNotEmpty && to.isNotEmpty)
              ? AblautOp(
                  from: from,
                  to: to,
                  count: ablautCount,
                  direction: ablautDirection,
                )
              : null;
        }(),
      OpType.template => templateCtrl.text.trim().isNotEmpty
          ? TemplateOp(templateCtrl.text.trim())
          : null,
      OpType.reduplication =>
        RedupOp(scope: redupScope, position: redupPosition),
      OpType.suppletive => suppletiveCtrl.text.trim().isNotEmpty
          ? SuppleteOp(suppletiveCtrl.text.trim())
          : null,
    };
  }
}

/// Mutable state for a single condition in a branch.
class _CondState {
  CondPosition position;
  final TextEditingController patternCtrl;

  _CondState({this.position = CondPosition.contains, String pattern = ''})
      : patternCtrl = TextEditingController(text: pattern);

  void dispose() {
    patternCtrl.dispose();
  }
}

/// Mutable state for a single branch in the form.
class _BranchState {
  List<_CondState> conditions;
  final List<_OpState> ops;

  _BranchState({List<_OpState>? ops})
      : conditions = [_CondState()],
        ops = ops ?? [_OpState()];

  void dispose() {
    for (final c in conditions) {
      c.dispose();
    }
    for (final op in ops) {
      op.dispose();
    }
  }

  /// Convert to domain [MorphBranch]. Returns null if all operations are incomplete.
  MorphBranch? toBranch() {
    final operations =
        ops.map((o) => o.toOperation()).whereType<MorphOperation>().toList();
    if (operations.isEmpty) return null;

    final conds = conditions
        .where((c) => c.patternCtrl.text.trim().isNotEmpty)
        .map((c) => PatternCond(c.patternCtrl.text.trim(),
            position: c.position) as MorphCondition)
        .toList();

    return MorphBranch(conditions: conds, operations: operations);
  }
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------

/// Hybrid rule editor dialog for creating and editing morphological rules.
///
/// Opens as a large dialog. Shows structured form fields alongside a live
/// preview panel that updates on every form change.
///
/// Pass [existing] to open in edit mode (pre-populated from the Drift row);
/// otherwise opens in create mode.
class RuleEditorDialog extends ConsumerStatefulWidget {
  const RuleEditorDialog({super.key, this.existing});

  /// Drift data row. When non-null, the dialog opens in edit mode.
  final db.MorphologicalRule? existing;

  @override
  ConsumerState<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<RuleEditorDialog> {
  final _nameCtrl = TextEditingController();
  final List<_BranchState> _branches = [];
  int? _selectedPosId;
  String? _validationError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _loadFromExisting(widget.existing!);
    } else {
      // Default: one branch with one suffix op.
      _branches.add(_BranchState());
    }
  }

  /// Populate form state from a Drift [db.MorphologicalRule] row.
  void _loadFromExisting(db.MorphologicalRule row) {
    _nameCtrl.text = row.name;
    _selectedPosId = row.posId;

    // Parse DSL source into domain model.
    final parsed = parseMorphDsl(row.source, id: row.id, name: row.name);
    if (!parsed.isValid || parsed.rule == null) {
      _branches.add(_BranchState());
      return;
    }

    for (final branch in parsed.rule!.branches) {
      final bs = _BranchState(ops: []);

      // Conditions: one _CondState per PatternCond.
      if (branch.conditions.isEmpty) {
        bs.conditions = [_CondState()]; // default branch
      } else {
        bs.conditions = branch.conditions.map((cond) {
          if (cond case PatternCond(:final pattern, :final position)) {
            return _CondState(position: position, pattern: pattern);
          }
          return _CondState();
        }).toList();
      }

      // Operations
      for (final op in branch.operations) {
        final os = _OpState();
        switch (op) {
          case PrefixOp(:final affix):
            os.type = OpType.prefix;
            os.affixCtrl.text = affix;
          case SuffixOp(:final affix):
            os.type = OpType.suffix;
            os.affixCtrl.text = affix;
          case InfixOp(:final affix, :final position):
            os.type = OpType.infix;
            os.affixCtrl.text = affix;
            os.posCtrl.text = '$position';
          case AblautOp(:final from, :final to, :final count, :final direction):
            os.type = OpType.ablaut;
            os.ablautFromCtrl.text = from;
            os.ablautToCtrl.text = to;
            os.ablautCount = count;
            os.ablautDirection = direction;
          case TemplateOp(:final pattern):
            os.type = OpType.template;
            os.templateCtrl.text = pattern;
          case RedupOp(:final scope, :final position):
            os.type = OpType.reduplication;
            os.redupScope = scope;
            os.redupPosition = position;
          case SuppleteOp(:final form):
            os.type = OpType.suppletive;
            os.suppletiveCtrl.text = form;
          case RemoveSuffixOp():
            // RemoveSuffixOp is an internal DSL operation; skip in UI.
            continue;
        }
        bs.ops.add(os);
      }

      if (bs.ops.isEmpty) bs.ops.add(_OpState());
      _branches.add(bs);
    }

    if (_branches.isEmpty) _branches.add(_BranchState());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final b in _branches) {
      b.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Domain rule builder
  // ---------------------------------------------------------------------------

  /// Build a domain [MorphologicalRule] from current form state.
  /// Returns null if form is incomplete (no valid branches).
  MorphologicalRule? _buildDomainRule({required int id}) {
    final name = _nameCtrl.text.trim();
    final branches =
        _branches.map((b) => b.toBranch()).whereType<MorphBranch>().toList();
    if (branches.isEmpty) return null;
    final tempRule =
        MorphologicalRule(id: id, name: name, branches: branches, source: '');
    final source = serializeMorphRule(tempRule);
    return MorphologicalRule(
        id: id, name: name, branches: branches, source: source);
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Rule name is required.');
      return;
    }

    final branches =
        _branches.map((b) => b.toBranch()).whereType<MorphBranch>().toList();
    if (branches.isEmpty) {
      setState(
          () => _validationError =
              'At least one branch with one operation is required.');
      return;
    }

    final tempRule =
        MorphologicalRule(id: 0, name: name, branches: branches, source: '');
    final source = serializeMorphRule(tempRule);

    final dao = ref.read(morphologyDaoProvider);
    if (dao == null) return;

    setState(() {
      _saving = true;
      _validationError = null;
    });

    try {
      if (widget.existing != null) {
        await dao.updateRule(widget.existing!.copyWith(
          name: name,
          source: source,
          posId: Value(_selectedPosId),
        ));
      } else {
        final ordering = await dao.nextOrdering();
        await dao.insertRule(
          db.MorphologicalRulesCompanion(
            name: Value(name),
            source: Value(source),
            ordering: Value(ordering),
            posId: Value(_selectedPosId),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Compute current domain rule for the preview panel.
    final previewRule = _buildDomainRule(id: widget.existing?.id ?? 0);

    // POS list for selector
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Column(
          children: [
            // --- Title bar ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing != null ? 'Edit Rule' : 'New Rule',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // --- Body ---
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: form
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name field
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Rule name',
                              hintText: 'e.g. Plural, Agentive',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),

                          // POS selector
                          Row(
                            children: [
                              Text(
                                'Part of speech:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<int?>(
                                value: _selectedPosId,
                                underline: const SizedBox.shrink(),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Applies to all'),
                                  ),
                                  ...posList.map(
                                    (pos) => DropdownMenuItem<int?>(
                                      value: pos.id,
                                      child: Text(pos.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedPosId = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Branches
                          ..._buildBranchCards(theme, cs),

                          const SizedBox(height: 8),

                          // Add branch button
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _branches.add(_BranchState());
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add branch'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Vertical divider
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: cs.outlineVariant,
                  ),

                  // Right: preview
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: PreviewPanel(rule: previewRule),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // --- Action bar ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                children: [
                  if (_validationError != null)
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.error),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Branch cards
  // ---------------------------------------------------------------------------

  List<Widget> _buildBranchCards(ThemeData theme, ColorScheme cs) {
    return List.generate(_branches.length, (bi) {
      final branch = _branches[bi];
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch header row
              Row(
                children: [
                  Text(
                    'Branch ${bi + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  if (_branches.length > 1)
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: cs.error),
                      tooltip: 'Remove branch',
                      onPressed: () {
                        setState(() {
                          _branches[bi].dispose();
                          _branches.removeAt(bi);
                        });
                      },
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Condition section
              _buildConditionSection(branch, bi, theme, cs),

              const SizedBox(height: 10),

              // Operations
              ...List.generate(branch.ops.length, (oi) {
                return _buildOpRow(branch, oi, theme, cs);
              }),

              const SizedBox(height: 4),

              // Add operation button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    branch.ops.add(_OpState());
                  });
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add operation'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Condition section (dropdown + pattern)
  // ---------------------------------------------------------------------------

  Widget _buildConditionSection(
      _BranchState branch, int bi, ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions:',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),

        // One row per condition
        ...List.generate(branch.conditions.length, (ci) {
          final cond = branch.conditions[ci];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Position dropdown
                DropdownButton<CondPosition>(
                  value: cond.position,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: CondPosition.startsWith,
                      child: Text('starts with'),
                    ),
                    DropdownMenuItem(
                      value: CondPosition.endsWith,
                      child: Text('ends with'),
                    ),
                    DropdownMenuItem(
                      value: CondPosition.contains,
                      child: Text('contains'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => cond.position = v);
                  },
                ),
                const SizedBox(width: 8),
                // Pattern field
                Expanded(
                  child: IpaTextField(
                    controller: cond.patternCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. [nasal]V, CV, Vk(l)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (branch.conditions.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 14, color: cs.error.withValues(alpha: 0.7)),
                    tooltip: 'Remove condition',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      setState(() {
                        branch.conditions[ci].dispose();
                        branch.conditions.removeAt(ci);
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        }),

        // Add condition button
        TextButton.icon(
          onPressed: () {
            setState(() {
              branch.conditions.add(_CondState());
            });
          },
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add condition (AND)'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.compact,
          ),
        ),

        // Syntax help text
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Pattern: [class]  C  V  literal  (optional)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Operation row
  // ---------------------------------------------------------------------------

  Widget _buildOpRow(
      _BranchState branch, int oi, ThemeData theme, ColorScheme cs) {
    final op = branch.ops[oi];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Type dropdown
          DropdownButton<OpType>(
            value: op.type,
            isDense: true,
            items: OpType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => op.type = v);
            },
          ),

          const SizedBox(width: 8),

          // Type-specific fields
          Expanded(child: _buildOpFields(op, theme, cs)),

          // Remove operation button (only if more than one op in this branch)
          if (branch.ops.length > 1)
            IconButton(
              icon: Icon(Icons.close,
                  size: 14, color: cs.error.withValues(alpha: 0.7)),
              tooltip: 'Remove operation',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () {
                setState(() {
                  branch.ops[oi].dispose();
                  branch.ops.removeAt(oi);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOpFields(_OpState op, ThemeData theme, ColorScheme cs) {
    const fieldDecoration = InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );

    return switch (op.type) {
      OpType.prefix || OpType.suffix => IpaTextField(
          controller: op.affixCtrl,
          decoration:
              fieldDecoration.copyWith(hintText: 'IPA affix, e.g. in, ɯ'),
          onChanged: (_) => setState(() {}),
        ),
      OpType.infix => Row(
          children: [
            Expanded(
              child: IpaTextField(
                controller: op.affixCtrl,
                decoration:
                    fieldDecoration.copyWith(hintText: 'IPA affix'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 60,
              child: TextField(
                controller: op.posCtrl,
                decoration:
                    fieldDecoration.copyWith(hintText: 'after C#'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      OpType.ablaut => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: IpaTextField(
                    controller: op.ablautFromCtrl,
                    decoration: fieldDecoration.copyWith(hintText: 'from (IPA)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14),
                ),
                Expanded(
                  child: IpaTextField(
                    controller: op.ablautToCtrl,
                    decoration: fieldDecoration.copyWith(hintText: 'to (IPA)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                DropdownButton<AblautDirection>(
                  value: op.ablautDirection,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: AblautDirection.fromStart,
                      child: Text('from the beginning'),
                    ),
                    DropdownMenuItem(
                      value: AblautDirection.fromEnd,
                      child: Text('from the end'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => op.ablautDirection = v);
                  },
                ),
                const SizedBox(width: 12),
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
                    setState(() => op.ablautCount = v);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'occurrences',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      OpType.template => TextField(
          controller: op.templateCtrl,
          decoration: fieldDecoration.copyWith(
            hintText: 'e.g. 1a23aa',
            helperText:
                'Digits = consonant slots, other chars literal',
          ),
          onChanged: (_) => setState(() {}),
        ),
      OpType.reduplication => Row(
          children: [
            const Text('Scope:'),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: op.redupScope,
              isDense: true,
              items: ['full', 'CV', 'C']
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => op.redupScope = v);
              },
            ),
            const SizedBox(width: 12),
            const Text('Position:'),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: op.redupPosition,
              isDense: true,
              items: ['prefix', 'suffix']
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => op.redupPosition = v);
              },
            ),
          ],
        ),
      OpType.suppletive => IpaTextField(
          controller: op.suppletiveCtrl,
          decoration: fieldDecoration.copyWith(
              hintText: 'Replaces entire word (e.g. went for go, mice for mouse)'),
          onChanged: (_) => setState(() {}),
        ),
    };
  }
}
