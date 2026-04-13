import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phonotactic_providers.dart';
import '../../domain/phonotactic_dsl.dart';
import 'sound_rules_shared.dart';

/// Widget for managing forbidden sound sequences and gemination constraints.
///
/// Displays all forbidden sequence patterns with parse status, active toggle,
/// edit and delete controls. Patterns use segment notation
/// (e.g. "[stop][stop]", "CC", "V[fricative]V").
/// Gemination constraints display with human-readable labels and position chips.
class ConstraintEditor extends ConsumerWidget {
  const ConstraintEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allConstraintsAsync = ref.watch(allConstraintsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoundRulesSectionHeader(
          title: 'Forbidden Sequences',
          helpText:
              'Patterns the word generator must avoid. '
              'e.g. "[stop][stop]" or "CC".',
          onAdd: () => _showTypePickerDialog(context, ref),
        ),
        allConstraintsAsync.when(
          data: (constraints) => constraints.isEmpty
              ? const SoundRulesEmptyHint(
                  message:
                      'No forbidden sequences yet. Add one to filter word generation.',
                )
              : Column(
                  children: constraints
                      .map((c) => _ConstraintRow(constraint: c))
                      .toList(),
                ),
          loading: () => const SoundRulesLoadingRow(),
          error: (e, _) => SoundRulesErrorRow(message: e.toString()),
        ),
      ],
    );
  }

  /// Shows a type picker dialog so the user can choose between a forbidden
  /// sequence constraint and a gemination restriction.
  void _showTypePickerDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add constraint'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddForbiddenSequenceDialog(context, ref);
            },
            child: const ListTile(
              leading: Icon(Icons.block_outlined),
              title: Text('Forbidden sequence'),
              subtitle: Text('e.g. no two stops in a row'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddGeminationDialog(context, ref);
            },
            child: const ListTile(
              leading: Icon(Icons.block),
              title: Text('No gemination'),
              subtitle: Text('Prevent identical adjacent consonants'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddForbiddenSequenceDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ConstraintEditDialog(
        initial: null,
        onSave: (pattern, description, position) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.insertConstraint(
            PhonotacticConstraintsCompanion.insert(
              pattern: pattern,
              description: Value(description.isEmpty ? null : description),
              position: Value(position),
            ),
          );
        },
      ),
    );
  }

  void _showAddGeminationDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _GeminationEditDialog(
        initial: null,
        onSave: (dslPattern, serializedPositions, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          // Check for duplicate gemination constraint.
          final existing = await dao.countGeminationConstraints();
          if (existing > 0) {
            // Cannot show snackbar from a detached context in async gap safely,
            // but the dialog is still open so we rely on the dialog to show
            // error feedback. We signal via exception so the dialog catches it.
            throw StateError(
              'A gemination constraint already exists. Edit the existing one.',
            );
          }
          await dao.insertGeminationConstraint(
            dslPattern: dslPattern,
            positions: serializedPositions,
            description: description.isEmpty ? null : description,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Constraint row
// ---------------------------------------------------------------------------

class _ConstraintRow extends ConsumerWidget {
  const _ConstraintRow({required this.constraint});

  final PhonotacticConstraint constraint;

  bool get _isGemination => constraint.type == 'gemination';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isGemination) {
      return _buildGeminationRow(context, ref, theme, cs);
    }
    return _buildSequenceRow(context, ref, theme, cs);
  }

  Widget _buildGeminationRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final positions = deserializeGeminationPositions(constraint.position);
    final positionLabels = positions.map(_positionLabel).toList()..sort();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Gemination icon (solid block)
          Tooltip(
            message: 'Gemination restriction',
            child: Icon(
              Icons.block,
              size: 16,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 8),

          // Human-readable label + position chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No gemination',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (constraint.description != null &&
                    constraint.description!.isNotEmpty)
                  Text(
                    constraint.description!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: positionLabels
                      .map(
                        (label) => Chip(
                          label: Text(
                            label,
                            style: theme.textTheme.labelSmall,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: cs.primaryContainer,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          // Active toggle
          Switch(
            value: constraint.isActive,
            onChanged: (v) {
              ref
                  .read(phonotacticDaoProvider)
                  ?.toggleConstraintActive(constraint.id, active: v);
            },
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit gemination constraint',
            onPressed: () => _showEditGeminationDialog(context, ref),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
            tooltip: 'Delete constraint',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final parsed = parseConstraintRule(constraint.pattern);
    final isValid = parsed.isValid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Parse status icon
          Tooltip(
            message: isValid
                ? 'Forbidden sequence'
                : (parsed.error ?? 'Invalid'),
            child: Icon(
              isValid ? Icons.block_outlined : Icons.error_outline,
              size: 16,
              color: isValid ? cs.error : cs.error,
            ),
          ),
          const SizedBox(width: 8),

          // Pattern text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  constraint.pattern,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: isValid
                        ? cs.onSurface
                        : cs.error.withValues(alpha: 0.8),
                  ),
                ),
                if (!isValid)
                  Text(
                    parsed.error ?? 'Parse error',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
                if (constraint.description != null &&
                    constraint.description!.isNotEmpty)
                  Text(
                    constraint.description!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                if (constraint.position != 'anywhere')
                  Text(
                    constraint.position == 'start'
                        ? 'at word beginning'
                        : 'at word end',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Active toggle
          Switch(
            value: constraint.isActive,
            onChanged: (v) {
              ref
                  .read(phonotacticDaoProvider)
                  ?.toggleConstraintActive(constraint.id, active: v);
            },
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit constraint',
            onPressed: () => _showEditDialog(context, ref),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
            tooltip: 'Delete constraint',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  String _positionLabel(GeminationPosition pos) => switch (pos) {
        GeminationPosition.everywhere => 'Everywhere',
        GeminationPosition.coda => 'Coda',
        GeminationPosition.onset => 'Onset',
        GeminationPosition.initial => 'Word-initial',
        GeminationPosition.final_ => 'Word-final',
      };

  void _showEditGeminationDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _GeminationEditDialog(
        initial: constraint,
        onSave: (dslPattern, serializedPositions, description) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.updateConstraint(
            constraint.copyWith(
              pattern: dslPattern,
              description: Value(description.isEmpty ? null : description),
              position: serializedPositions,
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _ConstraintEditDialog(
        initial: constraint,
        onSave: (pattern, description, position) async {
          final dao = ref.read(phonotacticDaoProvider);
          if (dao == null) return;
          await dao.updateConstraint(
            constraint.copyWith(
              pattern: pattern,
              description: Value(description.isEmpty ? null : description),
              position: position,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final label = _isGemination ? 'No gemination' : '"${constraint.pattern}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete constraint?'),
        content: Text('Remove $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(phonotacticDaoProvider)?.deleteConstraint(constraint.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Gemination add / edit dialog
// ---------------------------------------------------------------------------

class _GeminationEditDialog extends StatefulWidget {
  const _GeminationEditDialog({
    required this.initial,
    required this.onSave,
  });

  final PhonotacticConstraint? initial;
  final Future<void> Function(
    String dslPattern,
    String serializedPositions,
    String description,
  ) onSave;

  @override
  State<_GeminationEditDialog> createState() => _GeminationEditDialogState();
}

class _GeminationEditDialogState extends State<_GeminationEditDialog> {
  late final TextEditingController _descCtrl;
  late Set<GeminationPosition> _positions;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(
      text: widget.initial?.description ?? 'No geminate consonants',
    );

    // Load positions from existing constraint or default to everywhere.
    if (widget.initial != null) {
      _positions = deserializeGeminationPositions(widget.initial!.position);
    } else {
      _positions = {GeminationPosition.everywhere};
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _togglePosition(GeminationPosition pos, bool selected) {
    setState(() {
      if (pos == GeminationPosition.everywhere) {
        // Selecting "Everywhere" deselects all others.
        if (selected) {
          _positions = {GeminationPosition.everywhere};
        } else {
          // If deselecting everywhere, select all specific positions.
          _positions = {
            GeminationPosition.coda,
            GeminationPosition.onset,
            GeminationPosition.initial,
            GeminationPosition.final_,
          };
        }
      } else {
        // Selecting a specific position deselects "Everywhere".
        if (selected) {
          _positions = {..._positions, pos}
            ..remove(GeminationPosition.everywhere);
          if (_positions.isEmpty) {
            _positions = {GeminationPosition.everywhere};
          }
        } else {
          _positions = {..._positions}..remove(pos);
          // If last specific position deselected, auto-select Everywhere.
          if (_positions.isEmpty) {
            _positions = {GeminationPosition.everywhere};
          }
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final constraint = GeminationConstraint(
        positions: _positions,
        source: '!GG',
      );
      final dslSource = constraint.toSource();
      final serializedPositions = serializeGeminationPositions(_positions);
      await widget.onSave(
        dslSource,
        serializedPositions,
        _descCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = widget.initial != null;

    const positionEntries = [
      (GeminationPosition.everywhere, 'Everywhere'),
      (GeminationPosition.coda, 'Coda'),
      (GeminationPosition.onset, 'Onset'),
      (GeminationPosition.initial, 'Word-initial'),
      (GeminationPosition.final_, 'Word-final'),
    ];

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Edit gemination restriction'
            : 'Add gemination restriction',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Position selector header
            Text(
              'Restrict gemination at:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),

            // FilterChip position selector
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: positionEntries.map((entry) {
                final (pos, label) = entry;
                final isSelected = _positions.contains(pos);
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (v) => _togglePosition(pos, v),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Error message (e.g. duplicate constraint)
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.error,
                  ),
                ),
              ),

            // Optional description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'No geminate consonants',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit forbidden sequence dialog
// ---------------------------------------------------------------------------

class _ConstraintEditDialog extends StatefulWidget {
  const _ConstraintEditDialog({
    required this.initial,
    required this.onSave,
  });

  final PhonotacticConstraint? initial;
  final Future<void> Function(String pattern, String description, String position) onSave;

  @override
  State<_ConstraintEditDialog> createState() => _ConstraintEditDialogState();
}

class _ConstraintEditDialogState extends State<_ConstraintEditDialog> {
  late final TextEditingController _patternCtrl;
  late final TextEditingController _descCtrl;
  String _position = 'anywhere';
  ParsedConstraint? _parsed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _patternCtrl = TextEditingController(
      text: widget.initial?.pattern ?? '',
    );
    _descCtrl = TextEditingController(
      text: widget.initial?.description ?? '',
    );
    _position = widget.initial?.position ?? 'anywhere';
    _validate(_patternCtrl.text);
  }

  @override
  void dispose() {
    _patternCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _validate(String text) {
    setState(() {
      _parsed = text.isEmpty ? null : parseConstraintRule(text);
    });
  }

  Future<void> _save() async {
    if (_parsed == null || !_parsed!.isValid) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _patternCtrl.text.trim(),
        _descCtrl.text.trim(),
        _position,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isValid = _parsed?.isValid ?? false;
    final isEmpty = _patternCtrl.text.isEmpty;

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add forbidden sequence' : 'Edit forbidden sequence',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pattern field with live parse validation
            TextField(
              controller: _patternCtrl,
              decoration: InputDecoration(
                labelText: 'Forbidden pattern',
                hintText: '[stop][stop]',
                border: const OutlineInputBorder(),
                suffixIcon: isEmpty
                    ? null
                    : Icon(
                        isValid
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isValid ? Colors.green : cs.error,
                        size: 18,
                      ),
              ),
              onChanged: _validate,
            ),

            // Parse error message
            if (_parsed != null && !_parsed!.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _parsed!.error!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.error),
                ),
              ),

            const SizedBox(height: 12),

            // Position selector
            Row(
              children: [
                Text(
                  'Position:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _position,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'anywhere',
                      child: Text('anywhere in word'),
                    ),
                    DropdownMenuItem(
                      value: 'start',
                      child: Text('word beginning'),
                    ),
                    DropdownMenuItem(
                      value: 'end',
                      child: Text('word end'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _position = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Optional description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. No two stops in a row',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Syntax help text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Symbols:\n'
                '  C = any consonant    V = any vowel\n'
                '  [name] = natural class (e.g. [stop], [nasal])\n\n'
                'Examples:\n'
                '  [stop][stop]    no two stops in a row\n'
                '  CC              no consonant clusters\n'
                '  [nasal][stop]   no nasal+stop sequences',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_saving || !isValid || isEmpty) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
