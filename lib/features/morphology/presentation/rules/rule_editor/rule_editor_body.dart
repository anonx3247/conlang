// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/data/grammar_providers.dart';
import '../../../../grammar/domain/feature_bindings.dart';
import '../../../../grammar/domain/inflectional_rule.dart';
import '../../../../grammar/domain/rule_kind.dart';
import '../../../../grammar/domain/tiebreak_detector.dart';
import '../../../../phonology/data/romanization_bijection.dart';
import '../../../../phonology/data/romanization_providers.dart';
import '../../../data/morphology_providers.dart';
import '../../../domain/morphology_dsl.dart';
import '../preview_panel.dart';
import 'branch_editor.dart';
import 'form_loader.dart';
import 'form_state_models.dart';
import 'pos_binding_editor.dart';
import 'save_actions.dart';
import 'standard_form_warning.dart';

// ---------------------------------------------------------------------------
// RuleEditorBody — main rule editor body (D-14)
// Extracted from rule_editor_dialog.dart; contains all form state + logic.
// POS/binding section UI lives in pos_binding_editor.dart.
// StandardFormDerivationWarning lives in standard_form_warning.dart.
// ---------------------------------------------------------------------------

/// The full rule editor form body (without the Dialog chrome).
///
/// Placed inside a [Dialog] shell by [RuleEditorDialog].
class RuleEditorBody extends ConsumerStatefulWidget {
  const RuleEditorBody({
    super.key,
    required this.kind,
    this.existing,
    this.preFilledBindings,
    this.preFilledPosIds,
    this.markerId,
    this.markerBindings,
  });

  final RuleKind kind;
  final db.MorphologicalRule? existing;
  final Map<int, int>? preFilledBindings;
  final Set<int>? preFilledPosIds;
  final int? markerId;
  final FeatureBindings? markerBindings;

  @override
  ConsumerState<RuleEditorBody> createState() => _RuleEditorBodyState();
}

class _RuleEditorBodyState extends ConsumerState<RuleEditorBody> {
  final _nameCtrl = TextEditingController();
  final List<BranchState> _branches = [];
  bool _leaveAsUnmarked = false;
  String? _validationError;
  bool _saving = false;
  String? _saveBlockedReason;
  final Set<int> _inflectionalPosSet = <int>{};
  int? get _selectedPosIdForChips =>
      _inflectionalPosSet.isEmpty ? null : _inflectionalPosSet.first;
  final Map<int, int> _featureBindings = {};
  int? _hydratedPosSetForRuleId;
  int? _inputPosId;
  int? _outputPosId;
  Map<int, int> _outputIntrinsicLevels = {};
  bool _autoApply = false;
  TiebreakConflict? _tiebreakConflict;
  List<db.MorphologicalRule> _cachedInflectionalRows =
      const <db.MorphologicalRule>[];
  bool _romDisplayHydrated = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _loadFromExisting(widget.existing!);
    if (widget.markerId != null) {
      _leaveAsUnmarked = true;
      if (widget.markerBindings != null) {
        _featureBindings.addAll(widget.markerBindings!.dims);
        if (widget.markerBindings!.pos.isNotEmpty) {
          _inflectionalPosSet.addAll(widget.markerBindings!.pos);
        }
      }
    }
    if (widget.existing == null) {
      _branches.add(BranchState());
      if (widget.kind == RuleKind.inflectional &&
          widget.preFilledBindings != null) {
        _featureBindings.addAll(widget.preFilledBindings!);
      }
      if (widget.kind == RuleKind.inflectional &&
          widget.preFilledPosIds != null &&
          widget.preFilledPosIds!.isNotEmpty) {
        _inflectionalPosSet.addAll(widget.preFilledPosIds!);
      }
    }
  }

  void _loadFromExisting(db.MorphologicalRule row) {
    final romEnabled =
        ref.read(romanizationEnabledProvider).asData?.value ?? true;
    final romanize = ref.read(romanizeProvider);
    final result = loadFormFromRow(
      row: row,
      kind: widget.kind,
      romEnabled: romEnabled,
      romanize: romanize,
    );
    _nameCtrl.text = result.name;
    _branches.addAll(result.branches);
    _inflectionalPosSet.addAll(result.inflectionalPosSet);
    _featureBindings.addAll(result.featureBindings);
    _inputPosId = result.inputPosId;
    _outputPosId = result.outputPosId;
    _autoApply = result.autoApply;
    _outputIntrinsicLevels = result.outputIntrinsicLevels;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final b in _branches) b.dispose();
    super.dispose();
  }

  MorphologicalRule? _buildDomainRule({required int id}) {
    final name = _nameCtrl.text.trim();
    final branches =
        _branches.map((b) => b.toBranch()).whereType<MorphBranch>().toList();
    if (branches.isEmpty) return null;
    branches.sort((a, b) {
      final aHasCond = a.conditions.isNotEmpty ? 0 : 1;
      final bHasCond = b.conditions.isNotEmpty ? 0 : 1;
      return aHasCond.compareTo(bHasCond);
    });
    final tempRule =
        MorphologicalRule(id: id, name: name, branches: branches, source: '');
    final source = serializeMorphRule(tempRule);
    return MorphologicalRule(id: id, name: name, branches: branches, source: source);
  }

  void _recomputeTiebreak(List<db.MorphologicalRule> allRows) {
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
    final others = allRows
        .where((r) => r.id != widget.existing?.id)
        .map(InflectionalRule.fromDbRow)
        .toList();
    final selfRule = InflectionalRule(
      id: widget.existing?.id ?? -1,
      name: widget.existing?.name ?? '(this rule)',
      source: _nameCtrl.text,
      isActive: true,
      bindings: selfBindings,
    );
    final conflicts = findDuplicateSpecificityConflicts([selfRule, ...others]);
    _tiebreakConflict = null;
    for (final c in conflicts) {
      if (c.rules.any((r) => r.id == selfRule.id)) {
        _tiebreakConflict = c;
        break;
      }
    }
  }

  void _rebuildOnChange() {
    if (mounted) setState(() {});
  }

  void _hydrateRomDisplay() {
    if (_romDisplayHydrated) return;
    final mappingsAsync = ref.read(romanizationMappingsProvider);
    if (mappingsAsync is! AsyncData) return;
    final romEnabled =
        ref.read(romanizationEnabledProvider).asData?.value ?? true;
    if (!romEnabled) { _romDisplayHydrated = true; return; }
    hydrateRomDisplay(
      branches: _branches,
      romanize: ref.read(romanizeProvider),
    );
    _romDisplayHydrated = true;
  }

  Future<void> _save() async {
    setState(() { _saving = true; _validationError = null; });
    try {
      final fn = _leaveAsUnmarked ? _doSaveMarker() : _doSaveRule();
      final result = await fn;
      if (!mounted) return;
      if (result.validationError != null) {
        setState(() { _validationError = result.validationError; _saving = false; });
        return;
      }
      if (result.saveBlockedReason != null) {
        setState(() { _saveBlockedReason = result.saveBlockedReason; _saving = false; });
        return;
      }
      if (result.done) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<SaveResult> _doSaveRule() => saveRule(
        ref: ref,
        context: context,
        kind: widget.kind,
        name: _nameCtrl.text.trim(),
        branches: _branches,
        inflectionalPosSet: _inflectionalPosSet,
        featureBindings: _featureBindings,
        inputPosId: _inputPosId,
        outputPosId: _outputPosId,
        outputIntrinsicLevels: _outputIntrinsicLevels,
        autoApply: _autoApply,
        existing: widget.existing,
      );

  Future<SaveResult> _doSaveMarker() => saveMarker(
        ref: ref,
        featureBindings: _featureBindings,
        inflectionalPosSet: _inflectionalPosSet,
        name: _nameCtrl.text.trim(),
        markerId: widget.markerId,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    _hydrateRomDisplay();

    // D-72 bijection lock.
    final bijectionViolations =
        ref.watch(bijectionStatusProvider).asData?.value ??
            const <BijectionViolation>[];
    if (bijectionViolations.isNotEmpty) {
      return BijectionLockedView(violations: bijectionViolations);
    }

    final previewRule = _buildDomainRule(id: widget.existing?.id ?? 0);
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? [];

    if (widget.kind == RuleKind.inflectional) {
      final allInflAsync = ref.watch(rulesByKindProvider(RuleKind.inflectional));
      final allRows = allInflAsync.asData?.value ?? const <db.MorphologicalRule>[];
      _cachedInflectionalRows = allRows;
      _recomputeTiebreak(allRows);

      final existingId = widget.existing?.id;
      if (existingId != null && _hydratedPosSetForRuleId != existingId) {
        final async = ref.watch(posSetForRuleProvider(existingId));
        final fromJunction = async.asData?.value;
        if (fromJunction != null) {
          _hydratedPosSetForRuleId = existingId;
          if (fromJunction.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _inflectionalPosSet..clear()..addAll(fromJunction);
                _recomputeTiebreak(_cachedInflectionalRows);
              });
            });
          }
        }
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
      child: Column(
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              children: [
                Text(
                  widget.markerId != null ? 'Edit Marker'
                      : (_leaveAsUnmarked ? 'New Marker'
                          : (widget.existing != null ? 'Edit Rule' : 'New Rule')),
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

          // Body
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Rule name',
                            hintText: 'e.g. Plural, Agentive',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        if (widget.kind == RuleKind.inflectional)
                          CheckboxListTile(
                            value: _leaveAsUnmarked,
                            onChanged: (v) =>
                                setState(() => _leaveAsUnmarked = v ?? false),
                            title: const Text(
                                'Leave as unmarked (no rule, just a ∅ cell)'),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        const SizedBox(height: 4),
                        if (widget.kind == RuleKind.inflectional)
                          InflectionalTopSection(
                            posList: posList,
                            inflectionalPosSet: _inflectionalPosSet,
                            featureBindings: _featureBindings,
                            tiebreakConflict: _tiebreakConflict,
                            cachedInflectionalRows: _cachedInflectionalRows,
                            existingRuleId: widget.existing?.id,
                            onPosToggled: (posId, on) {
                              setState(() {
                                if (on) { _inflectionalPosSet.add(posId); }
                                else { _inflectionalPosSet.remove(posId); }
                                _saveBlockedReason = null;
                                _recomputeTiebreak(_cachedInflectionalRows);
                              });
                            },
                            onBindingChanged: (dimId, levelId) {
                              setState(() {
                                if (levelId != null) {
                                  _featureBindings[dimId] = levelId;
                                } else {
                                  _featureBindings.remove(dimId);
                                }
                                _saveBlockedReason = null;
                                _recomputeTiebreak(_cachedInflectionalRows);
                              });
                            },
                          )
                        else
                          DerivationalTopSection(
                            posList: posList,
                            inputPosId: _inputPosId,
                            outputPosId: _outputPosId,
                            outputIntrinsicLevels: _outputIntrinsicLevels,
                            autoApply: _autoApply,
                            ruleName: _nameCtrl.text,
                            onInputPosChanged: (v) {
                              setState(() {
                                _inputPosId = v;
                                _outputPosId ??= v;
                              });
                            },
                            onOutputPosChanged: (v) {
                              setState(() {
                                _outputPosId = v;
                                _outputIntrinsicLevels = {};
                              });
                            },
                            onOutputIntrinsicLevelChanged: (dimId, levelId) {
                              setState(() => _outputIntrinsicLevels[dimId] = levelId);
                            },
                            onAutoApplyChanged: (v) =>
                                setState(() => _autoApply = v),
                          ),
                        const SizedBox(height: 16),
                        if (!_leaveAsUnmarked)
                          BranchEditor(
                            branches: _branches,
                            onChanged: _rebuildOnChange,
                          ),
                      ],
                    ),
                  ),
                ),

                VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),

                if (!_leaveAsUnmarked)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PreviewPanel(rule: previewRule),
                          if (widget.kind == RuleKind.derivational &&
                              _outputPosId != null && previewRule != null)
                            StandardFormDerivationWarning(
                              outputPosId: _outputPosId!,
                              previewRule: previewRule,
                              outputIntrinsicLevels: _outputIntrinsicLevels,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_validationError != null)
                      Expanded(
                        child: Text(_validationError!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.error)),
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
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ],
                ),
                if (_saveBlockedReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _saveBlockedReason!,
                      key: const ValueKey('saveBlockedReasonText'),
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


