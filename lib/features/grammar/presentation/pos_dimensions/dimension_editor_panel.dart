import 'dart:math' show max;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/grammar_providers.dart';
import '../../domain/dimension_level.dart';
import '../../domain/level_deletion_report.dart';
import 'dimension_template_picker.dart';
import 'standard_form_pattern_dialog.dart';

/// Right-pane dimension editor for the POS & Dimensions master-detail page.
///
/// Subscribes to `dimensionsForPosProvider(posId)` and renders one Card per
/// dimension with level chips and delete controls, plus the "Add Dimension"
/// CTA that opens the template picker.
class DimensionEditorPanel extends ConsumerWidget {
  const DimensionEditorPanel({super.key, required this.posId});

  final int posId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dimsAsync = ref.watch(dimensionsForPosProvider(posId));
    // Treat loading as empty-list so the page doesn't flash a spinner on
    // the first listen. Matches the project-wide `asData?.value ?? const []`
    // pattern used in the POS list on the left pane.
    final dims = dimsAsync.asData?.value ?? const <Dimension>[];
    if (dimsAsync.hasError) {
      return Center(child: Text('Error: ${dimsAsync.error}'));
    }
    return _buildContent(context, ref, theme, dims);
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<Dimension> dims,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dimensions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _onAddDimension(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Dimension'),
              ),
            ],
          ),
        ),
        if (dims.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 64,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dimensions yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click "Add Dimension" to begin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dims.length,
              itemBuilder: (ctx, i) =>
                  _dimensionCard(ctx, ref, theme, dims[i]),
            ),
          ),
      ],
    );
  }

  Future<void> _onAddDimension(BuildContext ctx, WidgetRef ref) async {
    final template = await showDimensionTemplatePicker(ctx);
    if (template == null) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    final ordering = await dao.nextDimensionOrdering(posId);
    await dao.insertDimension(
      DimensionsCompanion.insert(
        posId: posId,
        name: template.name,
        ordering: Value(ordering),
        levelsJson: encodeLevelsJson(template.levels),
        templateId: Value(template.id),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext ctx,
    WidgetRef ref,
    Dimension dim,
  ) async {
    final newName = await showDialog<String>(
      context: ctx,
      builder: (dlgCtx) => _RenameDimensionDialog(initialName: dim.name),
    );
    if (newName == null || newName.isEmpty) return;
    if (newName == dim.name) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    await dao.updateDimension(dim.copyWith(name: newName));
  }

  /// D-79 plan 04-16: per-level rename. Opens [_LevelEditDialog]
  /// pre-filled with the current level name and abbr; on save,
  /// decodes `levelsJson`, finds the level by id, replaces its name
  /// and abbr via `copyWith` (which preserves id and ordering), and
  /// writes the updated list via `GrammarDao.updateDimensionLevels`.
  ///
  /// The level id is PRESERVED across rename (critical — rules and
  /// lexemes reference level ids in featureBindings and
  /// skippedDimensionsJson; reassigning would silently break them).
  Future<void> _onEditLevel(
    BuildContext ctx,
    WidgetRef ref,
    Dimension dim,
    DimensionLevel level,
  ) async {
    final result = await showDialog<({String name, String abbr})>(
      context: ctx,
      builder: (_) => _LevelEditDialog(
        title: 'Edit level',
        initialName: level.name,
        initialAbbr: level.abbr,
      ),
    );
    if (result == null) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    final updated = decodeLevelsJson(dim.levelsJson)
        .map((x) => x.id == level.id
            ? x.copyWith(name: result.name, abbr: result.abbr)
            : x)
        .toList();
    await dao.updateDimensionLevels(dim.id, updated);
  }

  /// D-80 plan 04-16: add-new-level. Opens [_LevelEditDialog] with
  /// empty fields; on save, appends a new [DimensionLevel] to the
  /// decoded levels list with `id = max(existing ids) + 1` (or 0 if
  /// empty) and `ordering = max(existing ordering) + 1` (or 0 if
  /// empty). No re-ordering UI — new levels append at the end.
  Future<void> _onAddLevel(
    BuildContext ctx,
    WidgetRef ref,
    Dimension dim,
  ) async {
    final result = await showDialog<({String name, String abbr})>(
      context: ctx,
      builder: (_) => const _LevelEditDialog(
        title: 'Add level',
        initialName: '',
        initialAbbr: '',
      ),
    );
    if (result == null) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    final current = decodeLevelsJson(dim.levelsJson);
    final nextId = current.isEmpty
        ? 0
        : (current.map((l) => l.id).reduce(max) + 1);
    final nextOrdering = current.isEmpty
        ? 0
        : (current.map((l) => l.ordering).reduce(max) + 1);
    final updated = [
      ...current,
      DimensionLevel(
        id: nextId,
        name: result.name,
        abbr: result.abbr,
        ordering: nextOrdering,
      ),
    ];
    await dao.updateDimensionLevels(dim.id, updated);
  }

  /// D-85 — 04-17. Confirm + execute the stale intrinsic-level purge.
  Future<void> _onPurgeStale(
    BuildContext ctx,
    WidgetRef ref,
    Dimension dim,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Purge stale intrinsic levels'),
        content: Text(
          'This will remove the intrinsic level entry for '
          "'${dim.name}' from $count lexemes. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('Purge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dao = ref.read(grammarDaoProvider);
    if (dao == null) return;
    await dao.purgeIntrinsicLevelEntries(dim.id);
    ref.invalidate(staleIntrinsicEntryCountProvider(dim.id));
  }

  Widget _dimensionCard(
    BuildContext ctx,
    WidgetRef ref,
    ThemeData theme,
    Dimension dim,
  ) {
    final levels = decodeLevelsJson(dim.levelsJson);
    // D-85 — 04-17. Stale intrinsic entry count drives the purge affordance
    // visibility when the dim is NOT currently intrinsic but still carries
    // residual entries in lexeme rows.
    final staleAsync = ref.watch(staleIntrinsicEntryCountProvider(dim.id));
    final staleCount = staleAsync.asData?.value ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dim.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // G-11: rename affordance — opens a dialog with the current
                // name pre-filled, rejects empty input, and calls
                // GrammarDao.updateDimension on save.
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Rename dimension',
                  onPressed: () => _showRenameDialog(ctx, ref, dim),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete dimension',
                  onPressed: () async {
                    final dao = ref.read(grammarDaoProvider);
                    if (dao == null) return;
                    await dao.deleteDimension(dim.id);
                  },
                ),
              ],
            ),
            // D-82 / D-84 / D-85 — 04-17. Intrinsic toggle row. On
            // false→true the DAO backfills every matching-POS lexeme with
            // the dim's first level id and writes a banner-pending row the
            // Inflections sub-tab consumes. On true→false the flag flips
            // only; lexeme rows are left untouched and the purge
            // affordance surfaces when staleCount > 0.
            Row(
              children: [
                Checkbox(
                  value: dim.intrinsic,
                  onChanged: (v) async {
                    final dao = ref.read(grammarDaoProvider);
                    if (dao == null) return;
                    await dao.setDimensionIntrinsic(dim.id, v ?? false);
                    ref.invalidate(
                        staleIntrinsicEntryCountProvider(dim.id));
                    ref.invalidate(intrinsicBackfillBannerProvider);
                  },
                ),
                Expanded(
                  child: Text(
                    'Intrinsic — words of this POS have a fixed level '
                    '(not inflected)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (!dim.intrinsic && staleCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: TextButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(
                    'Purge stale intrinsic levels for $staleCount words',
                  ),
                  onPressed: () => _onPurgeStale(ctx, ref, dim, staleCount),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final l in levels)
                  InputChip(
                    // BLOCKER-2 slot order: [edit-04-16] [text] [standard-form-04-17-if-intrinsic]
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LEFT slot: D-79 plan 04-16 level rename affordance.
                        InkWell(
                          onTap: () => _onEditLevel(ctx, ref, dim, l),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // CENTER slot: level label text.
                        Text('${l.name} (${l.abbr})'),
                        // RIGHT slot: D-98 plan 04-17 standard-form pattern
                        // affordance, only shown when dim is intrinsic.
                        if (dim.intrinsic) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.text_snippet_outlined, size: 16),
                            tooltip: 'Edit standard form pattern',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              showDialog(
                                context: ctx,
                                builder: (_) => StandardFormPatternDialog(
                                  dimId: dim.id,
                                  dimName: dim.name,
                                  levelId: l.id,
                                  levelName: l.name,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    onDeleted: () async {
                      // D-86 — 04-17 unified level-deletion dependency
                      // check. Before the pre-04-17 direct DAO write, run
                      // checkLevelDeletionDependencies to catch any
                      // references across lexemes / standard-form
                      // patterns / rule featureBindings. Non-blocking →
                      // fall through to the original direct delete.
                      // Blocking → open _ReassignLevelDialog and route
                      // through reassignLevelAndDelete in a single
                      // transaction.
                      final dao = ref.read(grammarDaoProvider);
                      if (dao == null) return;
                      final report = await dao
                          .checkLevelDeletionDependencies(dim.id, l.id);
                      if (!report.isBlocking) {
                        final updated = decodeLevelsJson(dim.levelsJson)
                            .where((x) => x.id != l.id)
                            .toList();
                        await dao.updateDimensionLevels(dim.id, updated);
                        return;
                      }
                      if (!ctx.mounted) return;
                      final otherLevels = decodeLevelsJson(dim.levelsJson)
                          .where((x) => x.id != l.id)
                          .toList();
                      if (otherLevels.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cannot delete the last level — '
                              'add another first.',
                            ),
                          ),
                        );
                        return;
                      }
                      final targetId = await showDialog<int>(
                        context: ctx,
                        builder: (_) => _ReassignLevelDialog(
                          levelName: l.name,
                          report: report,
                          candidates: otherLevels,
                        ),
                      );
                      if (targetId == null) return;
                      await dao.reassignLevelAndDelete(
                          dim.id, l.id, targetId);
                    },
                  ),
                // D-80 plan 04-16: trailing + chip opens _LevelEditDialog
                // with empty fields; on save appends a new DimensionLevel
                // with id = max(existing ids) + 1 and
                // ordering = max(existing ordering) + 1. Always visible
                // (including for dimensions with zero levels) so users
                // can add the first level via this affordance.
                InputChip(
                  label: const Icon(Icons.add, size: 14),
                  tooltip: 'Add level',
                  onPressed: () => _onAddLevel(ctx, ref, dim),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful dialog body for the rename-dimension flow (G-11). Owns its
/// own [TextEditingController] so the controller lifecycle matches the
/// dialog's State lifecycle — avoids "used after dispose" errors from
/// the in-build callback chain that fires when the dialog is popped.
class _RenameDimensionDialog extends StatefulWidget {
  const _RenameDimensionDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDimensionDialog> createState() =>
      _RenameDimensionDialogState();
}

class _RenameDimensionDialogState extends State<_RenameDimensionDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Name cannot be empty');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename dimension'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _onSave(),
        decoration: InputDecoration(
          labelText: 'Dimension name',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Stateful dialog body for the level edit / add-new-level flows
/// (D-79, D-80 plan 04-16). Owns its own [TextEditingController]s so
/// the controller lifecycle matches the dialog's State lifecycle.
///
/// Edits BOTH [DimensionLevel.name] and [DimensionLevel.abbr] in a
/// single form. Used by both the per-level rename affordance (chip
/// edit icon, pre-filled) and the add-new-level trailing + chip
/// (empty fields). Returns a `({String name, String abbr})?` record
/// via `Navigator.pop` — null when cancelled.
///
/// Sibling of [_RenameDimensionDialog] rather than a generalization —
/// isolating the two-field form from the one-field G-11 rename flow
/// avoids risk to the existing dimension-rename widget tests.
class _LevelEditDialog extends StatefulWidget {
  const _LevelEditDialog({
    required this.title,
    required this.initialName,
    required this.initialAbbr,
  });

  final String title; // 'Edit level' or 'Add level'
  final String initialName;
  final String initialAbbr;

  @override
  State<_LevelEditDialog> createState() => _LevelEditDialogState();
}

class _LevelEditDialogState extends State<_LevelEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _abbrCtrl;
  String? _nameError;
  String? _abbrError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _abbrCtrl = TextEditingController(text: widget.initialAbbr);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _nameCtrl.text.trim();
    final abbr = _abbrCtrl.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Name cannot be empty' : null;
      _abbrError = abbr.isEmpty ? 'Abbreviation cannot be empty' : null;
    });
    if (name.isEmpty || abbr.isEmpty) return;
    Navigator.of(context).pop((name: name, abbr: abbr));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Level name',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _abbrCtrl,
            onSubmitted: (_) => _onSave(),
            decoration: InputDecoration(
              labelText: 'Abbreviation',
              errorText: _abbrError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// D-86 — 04-17. Reassign + delete dialog for the level chip onDeleted
/// flow. Mirrors [_RenameDimensionDialog]'s state pattern: the selected
/// target level id is held in State so the "Reassign and delete" button
/// can toggle disabled/enabled based on whether the dropdown has a value.
class _ReassignLevelDialog extends StatefulWidget {
  const _ReassignLevelDialog({
    required this.levelName,
    required this.report,
    required this.candidates,
  });

  final String levelName;
  final LevelDeletionReport report;
  final List<DimensionLevel> candidates;

  @override
  State<_ReassignLevelDialog> createState() => _ReassignLevelDialogState();
}

class _ReassignLevelDialogState extends State<_ReassignLevelDialog> {
  int? _targetId;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AlertDialog(
      title: Text("Reassign and delete '${widget.levelName}'"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.total} references will be updated:'),
          const SizedBox(height: 8),
          if (r.lexemeCount > 0) Text('• ${r.lexemeCount} words'),
          if (r.patternCount > 0)
            Text('• ${r.patternCount} standard-form patterns'),
          if (r.ruleCount > 0)
            Text('• ${r.ruleCount} inflection rule'
                '${r.ruleCount == 1 ? '' : 's'}'),
          const SizedBox(height: 16),
          const Text('Reassign to:'),
          const SizedBox(height: 4),
          DropdownButton<int>(
            value: _targetId,
            isExpanded: true,
            hint: const Text('Select a level'),
            items: [
              for (final l in widget.candidates)
                DropdownMenuItem<int>(
                  value: l.id,
                  child: Text('${l.name} (${l.abbr})'),
                ),
            ],
            onChanged: (v) => setState(() => _targetId = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _targetId == null
              ? null
              : () => Navigator.of(context).pop(_targetId),
          child: const Text('Reassign and delete'),
        ),
      ],
    );
  }
}
