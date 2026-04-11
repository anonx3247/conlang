import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart' as db;
import '../../../grammar/data/grammar_providers.dart';
import '../../../grammar/domain/dimension_level.dart';
import '../../../grammar/domain/feature_bindings.dart';
import '../../../grammar/domain/inflectional_rule.dart';
import '../../../grammar/domain/rule_kind.dart';
import '../../../grammar/domain/tiebreak_detector.dart';
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
  ablaut('Replace'),
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
///
/// Plan 04-05: dialog is kind-aware. In inflectional mode it renders a
/// "Target POS" dropdown + a row of FilterChips per grammatical dimension
/// (feature-binding picker, D-42) plus a live tiebreak banner (D-12). In
/// derivational mode it renders Input/Output POS dropdowns (D-38) and hides
/// the chip rows.
class RuleEditorDialog extends ConsumerStatefulWidget {
  const RuleEditorDialog({
    super.key,
    required this.kind,
    this.existing,
  });

  /// Whether this dialog edits an inflectional or derivational rule.
  /// Required — callers must explicitly choose the kind (D-40 / plan 04-05).
  final RuleKind kind;

  /// Drift data row. When non-null, the dialog opens in edit mode.
  final db.MorphologicalRule? existing;

  @override
  ConsumerState<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<RuleEditorDialog> {
  final _nameCtrl = TextEditingController();
  final List<_BranchState> _branches = [];
  /// Legacy selected POS IDs (derivational-era multi-POS filter). Kept so the
  /// DSL preview path keeps working while we migrate to kind-aware bindings.
  /// In inflectional mode this is the single selected "Target POS" (as a set
  /// of one), in derivational mode this is empty and [_inputPosId] /
  /// [_outputPosId] are used instead.
  Set<int> _selectedPosIds = {};
  String? _validationError;
  bool _saving = false;

  // ---- Plan 04-05 kind-aware state -----------------------------------------

  /// Inflectional mode — the single Target POS whose dimensions are offered
  /// as chip rows. Null means no POS selected yet.
  int? _selectedPosIdForChips;

  /// Inflectional mode — selected level per dimension.
  /// Key = dimensionId, value = levelId.
  final Map<int, int> _featureBindings = {};

  /// Derivational mode — source POS.
  int? _inputPosId;

  /// Derivational mode — target POS (defaults to [_inputPosId] on change).
  int? _outputPosId;

  /// Latest tiebreak computation result for inflectional mode. Null when
  /// there's no conflict.
  TiebreakConflict? _tiebreakConflict;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _loadFromExisting(widget.existing!);
    } else {
      // Default: one branch with one suffix op.
      _branches.add(_BranchState());
    }
    // Tiebreak is recomputed inside build() from the live Riverpod stream,
    // so initState doesn't need to schedule a post-frame callback.
  }

  /// Populate form state from a Drift [db.MorphologicalRule] row.
  void _loadFromExisting(db.MorphologicalRule row) {
    _nameCtrl.text = row.name;

    // Seed kind-specific state from the row's featureBindings before we set
    // up the legacy _selectedPosIds fallback.
    final bindings = row.featureBindings;
    if (widget.kind == RuleKind.inflectional) {
      _featureBindings.addAll(bindings.dims);
      if (bindings.pos.isNotEmpty) {
        _selectedPosIdForChips = bindings.pos.first;
        _selectedPosIds = {bindings.pos.first};
      }
    } else {
      _inputPosId =
          row.inputPosId ?? (bindings.pos.isNotEmpty ? bindings.pos.first : null);
      _outputPosId = row.outputPosId ?? _inputPosId;
    }

    // Load multi-POS selection from posIds text column (legacy fallback —
    // only used when the v8 bindings didn't provide a POS hint).
    if (_selectedPosIds.isEmpty) {
      if (row.posIds.isNotEmpty) {
        _selectedPosIds = row.posIds
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toSet();
      } else if (row.posId != null) {
        // Backward compat: migrate single posId
        _selectedPosIds = {row.posId!};
      }
    }

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
  ///
  /// Automatically sorts branches: conditional branches first, then default
  /// (empty conditions) branches last — more specific rules take priority.
  MorphologicalRule? _buildDomainRule({required int id}) {
    final name = _nameCtrl.text.trim();
    final branches =
        _branches.map((b) => b.toBranch()).whereType<MorphBranch>().toList();
    if (branches.isEmpty) return null;

    // Sort: branches with conditions before branches without (default/else).
    branches.sort((a, b) {
      final aHasCond = a.conditions.isNotEmpty ? 0 : 1;
      final bHasCond = b.conditions.isNotEmpty ? 0 : 1;
      return aHasCond.compareTo(bHasCond);
    });

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

    // Inflectional rules MUST bind at least one dimension — D-13 + plan 04-05
    // must-have. An empty-bindings inflectional rule would be effectively
    // unbound and would fire on every cell.
    if (widget.kind == RuleKind.inflectional && _featureBindings.isEmpty) {
      setState(() {
        _validationError =
            'Inflectional rules must bind at least one feature. '
            'Select at least one level chip above.';
      });
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

    // Build the kind-aware FeatureBindings payload.
    final List<int> boundPos;
    final Map<int, int> boundDims;
    if (widget.kind == RuleKind.inflectional) {
      boundPos = _selectedPosIdForChips == null
          ? const <int>[]
          : <int>[_selectedPosIdForChips!];
      boundDims = Map<int, int>.from(_featureBindings);
    } else {
      boundPos = _inputPosId == null ? const <int>[] : <int>[_inputPosId!];
      boundDims = const <int, int>{};
    }
    final featureBindings =
        FeatureBindings(pos: boundPos, dims: boundDims);

    // Legacy CSV stays in lockstep with the new bindings so the posIds column
    // continues to mirror reality until it's physically dropped (A9).
    final posIdsStr =
        boundPos.isEmpty ? '' : boundPos.map((p) => '$p').join(',');

    final companionInputPos = widget.kind == RuleKind.derivational
        ? Value<int?>(_inputPosId)
        : const Value<int?>.absent();
    final companionOutputPos = widget.kind == RuleKind.derivational
        ? Value<int?>(_outputPosId)
        : const Value<int?>.absent();

    try {
      if (widget.existing != null) {
        await dao.updateRule(widget.existing!.copyWith(
          name: name,
          source: source,
          posIds: posIdsStr,
          kind: widget.kind.dbString,
          featureBindings: featureBindings,
          inputPosId: widget.kind == RuleKind.derivational
              ? Value<int?>(_inputPosId)
              : const Value<int?>(null),
          outputPosId: widget.kind == RuleKind.derivational
              ? Value<int?>(_outputPosId)
              : const Value<int?>(null),
        ));
      } else {
        final ordering = await dao.nextOrdering();
        await dao.insertRuleWithKind(
          db.MorphologicalRulesCompanion(
            name: Value(name),
            source: Value(source),
            ordering: Value(ordering),
            posIds: Value(posIdsStr),
            featureBindings: Value(featureBindings),
            inputPosId: companionInputPos,
            outputPosId: companionOutputPos,
          ),
          widget.kind,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Tiebreak detection (inflectional mode, D-12)
  // ---------------------------------------------------------------------------

  /// Recomputes [_tiebreakConflict] against [allInflectionalRows], which the
  /// build method obtains by `ref.watch(rulesByKindProvider(inflectional))`.
  /// Passing the list in keeps `_recomputeTiebreak` callable from setState()
  /// handlers without needing `ref.read` inside state setters.
  void _recomputeTiebreak(List<db.MorphologicalRule> allInflectionalRows) {
    if (widget.kind != RuleKind.inflectional || _featureBindings.isEmpty) {
      _tiebreakConflict = null;
      return;
    }
    final selfBindings = FeatureBindings(
      pos: _selectedPosIdForChips == null
          ? const <int>[]
          : <int>[_selectedPosIdForChips!],
      dims: Map<int, int>.from(_featureBindings),
    );
    // Exclude the current rule (edit mode) so the editor never self-conflicts.
    final others = allInflectionalRows
        .where((r) => r.id != widget.existing?.id)
        .map(InflectionalRule.fromDbRow)
        .toList();
    // Synthetic view-model for the in-progress rule — the detector takes a
    // plain list, so we pass [selfRule, ...others] and look for any conflict
    // group that includes our synthetic id.
    final selfRule = InflectionalRule(
      id: widget.existing?.id ?? -1,
      name: widget.existing?.name ?? '(this rule)',
      source: _nameCtrl.text,
      isActive: true,
      bindings: selfBindings,
    );
    final conflicts =
        findDuplicateSpecificityConflicts([selfRule, ...others]);
    _tiebreakConflict = null;
    for (final c in conflicts) {
      if (c.rules.any((r) => r.id == selfRule.id)) {
        _tiebreakConflict = c;
        break;
      }
    }
  }

  /// The inflectional rules currently visible to the tiebreak detector,
  /// cached from the latest `ref.watch` in [build]. Used by setState handlers
  /// (chip toggles, POS change) to recompute without re-reading Riverpod.
  List<db.MorphologicalRule> _cachedInflectionalRows =
      const <db.MorphologicalRule>[];

  // ---------------------------------------------------------------------------
  // Dimension chip row builder (inflectional mode)
  // ---------------------------------------------------------------------------

  Widget _buildDimensionChipRow(db.Dimension dim, ThemeData theme) {
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
                final selected = _featureBindings[dim.id] == l.id;
                return FilterChip(
                  label: Text(l.abbr),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _featureBindings[dim.id] = l.id;
                      } else {
                        _featureBindings.remove(dim.id);
                      }
                      _recomputeTiebreak(_cachedInflectionalRows);
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tiebreak banner builder (inflectional mode, D-12 / UI-SPEC)
  // ---------------------------------------------------------------------------

  Widget _buildTiebreakBanner(
      TiebreakConflict conflict, ThemeData theme, ColorScheme cs) {
    final otherNames = conflict.rules
        .where((r) => r.id != (widget.existing?.id ?? -1) && r.id != -1)
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
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kind-aware top sections (plan 04-05)
  // ---------------------------------------------------------------------------

  /// Inflectional mode top: Target POS dropdown + chip rows per dimension +
  /// validation hint + live tiebreak banner.
  List<Widget> _buildInflectionalTop(
    ThemeData theme,
    ColorScheme cs,
    List<db.PartsOfSpeechData> posList,
  ) {
    final widgets = <Widget>[];
    widgets.add(Text(
      'Applies to',
      style: theme.textTheme.titleMedium,
    ));
    widgets.add(const SizedBox(height: 8));
    widgets.add(
      DropdownButtonFormField<int>(
        initialValue: _selectedPosIdForChips,
        decoration: const InputDecoration(
          labelText: 'Target POS',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        isExpanded: true,
        items: [
          for (final pos in posList)
            DropdownMenuItem<int>(
              value: pos.id,
              child: Text(
                '${pos.name} (${pos.abbreviation})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _selectedPosIdForChips = v;
            _selectedPosIds = {v};
            _featureBindings.clear();
            _recomputeTiebreak(_cachedInflectionalRows);
          });
        },
      ),
    );
    widgets.add(const SizedBox(height: 12));
    if (_selectedPosIdForChips != null) {
      widgets.add(Consumer(builder: (ctx, ref, _) {
        final dimsAsync =
            ref.watch(dimensionsForPosProvider(_selectedPosIdForChips!));
        final dims = dimsAsync.asData?.value ?? const <db.Dimension>[];
        if (dims.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'This POS has no dimensions yet. Add dimensions in '
              'Grammar → POS & Dimensions to enable inflectional binding.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final dim in dims) _buildDimensionChipRow(dim, theme)],
        );
      }));
    }
    if (_featureBindings.isEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text(
        'Inflectional rules must bind at least one feature. '
        'Select at least one level chip above.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
      ));
    }
    if (_tiebreakConflict != null) {
      widgets.add(_buildTiebreakBanner(_tiebreakConflict!, theme, cs));
    }
    return widgets;
  }

  /// Derivational mode top: Input POS + arrow + Output POS dropdowns (D-38).
  List<Widget> _buildDerivationalTop(
    ThemeData theme,
    ColorScheme cs,
    List<db.PartsOfSpeechData> posList,
  ) {
    return [
      // Stacked, not side-by-side, so the labels always fit inside the
      // cramped left column of the editor dialog (pre-existing maxWidth:820
      // constraint). Plan 04-05 Task 1 accepted this layout tweak after the
      // row variant overflowed the column by 9.5px in widget tests.
      Text('Input POS', style: theme.textTheme.bodySmall),
      const SizedBox(height: 4),
      DropdownButtonFormField<int>(
        initialValue: _inputPosId,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        isExpanded: true,
        items: [
          for (final pos in posList)
            DropdownMenuItem<int>(
              value: pos.id,
              child: Text(
                '${pos.name} (${pos.abbreviation})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          setState(() {
            _inputPosId = v;
            // Default output to input on change (D-38).
            _outputPosId ??= v;
            if (v != null) {
              _selectedPosIds = {v};
            }
          });
        },
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
        initialValue: _outputPosId,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        isExpanded: true,
        items: [
          for (final pos in posList)
            DropdownMenuItem<int>(
              value: pos.id,
              child: Text(
                '${pos.name} (${pos.abbreviation})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          setState(() => _outputPosId = v);
        },
      ),
    ];
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

    // Plan 04-05: keep the tiebreak detector in sync with the live
    // inflectional rules stream. Watching here ensures the provider stays
    // subscribed and the banner updates when rules are added/edited in
    // another tab while the editor is open.
    if (widget.kind == RuleKind.inflectional) {
      final allInflectionalAsync =
          ref.watch(rulesByKindProvider(RuleKind.inflectional));
      final allRows = allInflectionalAsync.asData?.value ??
          const <db.MorphologicalRule>[];
      _cachedInflectionalRows = allRows;
      // Recompute synchronously inside build — the result is only read after
      // build in the banner render path below, so mutating _tiebreakConflict
      // here is safe (no concurrent setState).
      _recomputeTiebreak(allRows);
    }

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

                          // Kind-aware top section (plan 04-05).
                          if (widget.kind == RuleKind.inflectional)
                            ..._buildInflectionalTop(theme, cs, posList)
                          else
                            ..._buildDerivationalTop(theme, cs, posList),
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
                setState(() => op.type = v);
              },
            ),
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
                    decoration: fieldDecoration.copyWith(hintText: 'from'),
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
                    decoration: fieldDecoration.copyWith(hintText: 'to'),
                    onChanged: (_) => setState(() {}),
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
                    setState(() => op.ablautCount = v);
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
                    setState(() => op.ablautDirection = v);
                  },
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
