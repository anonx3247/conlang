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
  suppletive('Replacement form');

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

  _OpState()
      : type = OpType.suffix,
        redupScope = 'CV',
        redupPosition = 'prefix';

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
              ? AblautOp(from: from, to: to)
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

/// Mutable state for a single branch in the form.
///
/// Conditions are stored as a list of [TextEditingController]s — one per
/// pattern. Empty list of non-empty controllers = default branch.
class _BranchState {
  /// One controller per condition pattern. At least one is always present.
  List<TextEditingController> condPatternCtrls;
  final List<_OpState> ops;

  _BranchState({List<_OpState>? ops})
      : condPatternCtrls = [TextEditingController()],
        ops = ops ?? [_OpState()];

  void dispose() {
    for (final ctrl in condPatternCtrls) {
      ctrl.dispose();
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

    final conditions = condPatternCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => PatternCond(s) as MorphCondition)
        .toList();

    return MorphBranch(conditions: conditions, operations: operations);
  }
}

// ---------------------------------------------------------------------------
// Dialog widget
// ---------------------------------------------------------------------------

/// Hybrid rule editor dialog for creating and editing morphological rules.
///
/// Opens as a large dialog. Shows structured form fields alongside a live DSL
/// expression display that updates on every form change.
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
  String _dslPreview = '';
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
    _updateDsl();
  }

  /// Populate form state from a Drift [db.MorphologicalRule] row.
  ///
  /// Parses the [source] DSL string to reconstruct branch/operation structure.
  void _loadFromExisting(db.MorphologicalRule row) {
    _nameCtrl.text = row.name;

    // Parse DSL source into domain model.
    final parsed = parseMorphDsl(row.source, id: row.id, name: row.name);
    if (!parsed.isValid || parsed.rule == null) {
      // Source is unparseable — show a default empty branch; user can edit.
      _branches.add(_BranchState());
      return;
    }

    for (final branch in parsed.rule!.branches) {
      final bs = _BranchState(ops: []);

      // Conditions: one controller per PatternCond.
      if (branch.conditions.isEmpty) {
        bs.condPatternCtrls = [TextEditingController()]; // default branch
      } else {
        bs.condPatternCtrls = branch.conditions.map((cond) {
          final ctrl = TextEditingController();
          if (cond case PatternCond(:final pattern)) {
            ctrl.text = pattern;
          }
          return ctrl;
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
          case AblautOp(:final from, :final to):
            os.type = OpType.ablaut;
            os.ablautFromCtrl.text = from;
            os.ablautToCtrl.text = to;
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
  // DSL computation
  // ---------------------------------------------------------------------------

  void _updateDsl() {
    final rule = _buildDomainRule(id: 0);
    if (rule != null) {
      setState(() {
        _dslPreview = serializeMorphRule(rule);
        _validationError = null;
      });
    } else {
      setState(() {
        _dslPreview = '(incomplete)';
      });
    }
  }

  /// Build a domain [MorphologicalRule] from current form state.
  /// Returns null if form is incomplete (no valid branches).
  MorphologicalRule? _buildDomainRule({required int id}) {
    final name = _nameCtrl.text.trim();
    final branches =
        _branches.map((b) => b.toBranch()).whereType<MorphBranch>().toList();
    if (branches.isEmpty) return null;
    // First build without source to get the serialized form, then embed it.
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
        await dao.updateRule(widget.existing!.copyWith(name: name, source: source));
      } else {
        await dao.insertRule(
          db.MorphologicalRulesCompanion(
            name: Value(name),
            source: Value(source),
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
                            onChanged: (_) => _updateDsl(),
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
                              _updateDsl();
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add branch'),
                          ),

                          const SizedBox(height: 20),

                          // DSL expression display
                          _buildDslDisplay(theme, cs),
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
                        _updateDsl();
                      },
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Condition section (pattern-based)
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
                  _updateDsl();
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
  // Condition section (pattern-based)
  // ---------------------------------------------------------------------------

  Widget _buildConditionSection(
      _BranchState branch, int bi, ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions (phonological patterns):',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),

        // One row per condition controller
        ...List.generate(branch.condPatternCtrls.length, (ci) {
          final ctrl = branch.condPatternCtrls[ci];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: IpaTextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. [nasal]V_, _CV, Vk(l)_, _ (default)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    onChanged: (_) => _updateDsl(),
                  ),
                ),
                if (branch.condPatternCtrls.length > 1) ...[
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
                        branch.condPatternCtrls[ci].dispose();
                        branch.condPatternCtrls.removeAt(ci);
                      });
                      _updateDsl();
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
              branch.condPatternCtrls.add(TextEditingController());
            });
            _updateDsl();
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
            'Syntax: [class]  C  V  literal  (optional)  _=anchor',
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
              _updateDsl();
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
                _updateDsl();
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
          onChanged: (_) => _updateDsl(),
        ),
      OpType.infix => Row(
          children: [
            Expanded(
              child: IpaTextField(
                controller: op.affixCtrl,
                decoration:
                    fieldDecoration.copyWith(hintText: 'IPA affix'),
                onChanged: (_) => _updateDsl(),
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
                onChanged: (_) => _updateDsl(),
              ),
            ),
          ],
        ),
      OpType.ablaut => Row(
          children: [
            Expanded(
              child: IpaTextField(
                controller: op.ablautFromCtrl,
                decoration: fieldDecoration.copyWith(hintText: 'from (IPA)'),
                onChanged: (_) => _updateDsl(),
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
                onChanged: (_) => _updateDsl(),
              ),
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
          onChanged: (_) => _updateDsl(),
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
                _updateDsl();
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
                _updateDsl();
              },
            ),
          ],
        ),
      OpType.suppletive => IpaTextField(
          controller: op.suppletiveCtrl,
          decoration: fieldDecoration.copyWith(
              hintText: 'Replacement form (e.g. went, mice)'),
          onChanged: (_) => _updateDsl(),
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // DSL display
  // ---------------------------------------------------------------------------

  Widget _buildDslDisplay(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DSL Expression',
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            _dslPreview.isEmpty ? '(incomplete)' : _dslPreview,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
              color: _dslPreview.isEmpty
                  ? cs.onSurface.withValues(alpha: 0.35)
                  : cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
