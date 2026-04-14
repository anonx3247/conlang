// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/data/construction_providers.dart';
import '../../../../grammar/data/construction_rule_providers.dart';
import '../../../../grammar/data/grammar_providers.dart';
import '../../../../grammar/domain/construction_rule.dart';
import '../../../../grammar/domain/dimension_level.dart' show decodeLevelsJson;
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
    this.existingConstructionRule,
    this.preFilledBindings,
    this.preFilledPosIds,
    this.markerId,
    this.markerBindings,
  });

  final RuleKind kind;
  final db.MorphologicalRule? existing;

  /// When non-null and kind == RuleKind.construction, opens in edit mode for
  /// the given construction rule.
  final ConstructionRule? existingConstructionRule;
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

  // ---------------------------------------------------------------------------
  // Construction rule form state (only used when kind == RuleKind.construction)
  // ---------------------------------------------------------------------------
  int? _selectedConstructionId;
  int? _selectedWordSlotId;
  FormReference _formReference = const BaseFormReference();
  ConstructionRule? _editingConstructionRule;
  // For the cell cross-reference picker: a JSON-encoded featureSet string
  String? _selectedCellRefJson;
  // Tracks whether "Reference another cell" radio is selected (separate from
  // _formReference which only becomes CellFormReference once a cell is chosen)
  bool _cellRefModeActive = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _loadFromExisting(widget.existing!);
    if (widget.existingConstructionRule != null) {
      _editingConstructionRule = widget.existingConstructionRule;
      _selectedConstructionId =
          widget.existingConstructionRule!.constructionId;
      _selectedWordSlotId = widget.existingConstructionRule!.wordSlotId;
      _formReference = widget.existingConstructionRule!.formReference;
      _nameCtrl.text = widget.existingConstructionRule!.name;
      // Restore the JSON string for the cell reference picker if applicable.
      final fr = widget.existingConstructionRule!.formReference;
      if (fr is CellFormReference) {
        _selectedCellRefJson = fr.toJson();
        _cellRefModeActive = true;
      }
      // Hydrate POS bindings from the existing rule.
      _inflectionalPosSet.addAll(
          widget.existingConstructionRule!.bindings.pos);
      _featureBindings.addAll(
          widget.existingConstructionRule!.bindings.dims);
    }
    if (widget.markerId != null) {
      _leaveAsUnmarked = true;
      if (widget.markerBindings != null) {
        _featureBindings.addAll(widget.markerBindings!.dims);
        if (widget.markerBindings!.pos.isNotEmpty) {
          _inflectionalPosSet.addAll(widget.markerBindings!.pos);
        }
      }
    }
    if (widget.existing == null &&
        widget.existingConstructionRule == null) {
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
      if (widget.kind == RuleKind.construction &&
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
    for (final b in _branches) {
      b.dispose();
    }
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
    if (widget.kind == RuleKind.construction) {
      await _saveConstructionRule();
      return;
    }
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

  Future<void> _saveConstructionRule() async {
    setState(() { _saving = true; _validationError = null; });
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        setState(() {
          _validationError = 'Rule name is required.';
          _saving = false;
        });
        return;
      }
      if (_selectedConstructionId == null) {
        setState(() {
          _validationError = 'Select a construction.';
          _saving = false;
        });
        return;
      }
      if (_selectedWordSlotId == null) {
        setState(() {
          _validationError = 'Select a word slot.';
          _saving = false;
        });
        return;
      }

      final dao = ref.read(constructionRuleDaoProvider);
      if (dao == null) {
        setState(() { _saving = false; });
        return;
      }

      final companion = db.ConstructionRulesCompanion(
        name: Value(name),
        isActive: const Value(true),
        ordering: const Value(0),
        constructionId: Value(_selectedConstructionId!),
        wordSlotId: Value(_selectedWordSlotId!),
        formReferenceJson: Value(_formReference.toJson()),
        featureBindings: Value(FeatureBindings(
          pos: _inflectionalPosSet.toList(),
          dims: Map<int, int>.from(_featureBindings),
        )),
      );

      if (_editingConstructionRule != null) {
        // Update existing rule.
        final existingRow = db.ConstructionRuleRow(
          id: _editingConstructionRule!.id,
          name: name,
          isActive: true,
          ordering: _editingConstructionRule!.ordering,
          constructionId: _selectedConstructionId!,
          wordSlotId: _selectedWordSlotId!,
          formReferenceJson: _formReference.toJson(),
          featureBindings: FeatureBindings(
            pos: _inflectionalPosSet.toList(),
            dims: Map<int, int>.from(_featureBindings),
          ),
        );
        await dao.updateRule(existingRow);
        await dao.setPosLinks(
            _editingConstructionRule!.id, Set<int>.from(_inflectionalPosSet));
      } else {
        // Insert new rule.
        final newId = await dao.insertRule(companion);
        await dao.setPosLinks(newId, Set<int>.from(_inflectionalPosSet));
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Failed to save rule. Check your database connection.';
          _saving = false;
        });
      }
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

    // Construction rules have their own dedicated layout.
    if (widget.kind == RuleKind.construction) {
      // Must still call ref.watch unconditionally before the early return
      // (Riverpod hook ordering constraint — watch calls must be stable).
      return _buildConstructionForm(context, theme, cs);
    }

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

  // ---------------------------------------------------------------------------
  // Construction rule form
  // ---------------------------------------------------------------------------

  Widget _buildConstructionForm(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    final posAsync = ref.watch(posListProvider);
    final posList = posAsync.asData?.value ?? const [];

    final constructionsAsync = ref.watch(constructionListProvider);
    final constructions =
        constructionsAsync.asData?.value ?? const [];

    // Watch slots for selected construction.
    final slotsAsync = _selectedConstructionId != null
        ? ref.watch(constructionSlotsProvider(_selectedConstructionId!))
        : null;
    final slots = slotsAsync?.asData?.value ?? const [];

    // Default word slot to first 'pos' type slot when construction changes.
    if (_selectedWordSlotId == null && slots.isNotEmpty) {
      final firstPosSlot =
          slots.where((s) => s.slotType == 'pos').firstOrNull;
      if (firstPosSlot != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedWordSlotId = firstPosSlot.id);
        });
      }
    }

    // Build cell cross-reference options from all dimensions for selected POS.
    final cellRefOptions = <({String json, String label})>[];
    if (_selectedPosIdForChips != null) {
      final dimsAsync =
          ref.watch(dimensionsForPosProvider(_selectedPosIdForChips!));
      final dims = dimsAsync.asData?.value ?? const [];
      for (final dim in dims) {
        final levels = decodeLevelsJson(dim.levelsJson);
        for (final lvl in levels) {
          final featureSet = {dim.id: lvl.id};
          final ref2 = CellFormReference(targetFeatureSet: featureSet);
          cellRefOptions.add((
            json: ref2.toJson(),
            label: '${dim.name}: ${lvl.name}',
          ));
        }
      }
    }

    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    final isEditing = _editingConstructionRule != null;

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
                  isEditing ? 'Edit Construction Rule' : 'New Construction Rule',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                // Delete button — only shown when editing
                if (isEditing)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    tooltip: 'Delete rule',
                    onPressed: () async {
                      final dao = ref.read(constructionRuleDaoProvider);
                      if (dao != null && _editingConstructionRule != null) {
                        final navigator = Navigator.of(context);
                        await dao.deleteRule(_editingConstructionRule!.id);
                        if (mounted) navigator.pop();
                      }
                    },
                  ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rule name
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rule name',
                      hintText: 'e.g. Future analytic, Progressive construction',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // POS + feature binding chips (identical to inflectional mode)
                  InflectionalTopSection(
                    posList: posList,
                    inflectionalPosSet: _inflectionalPosSet,
                    featureBindings: _featureBindings,
                    tiebreakConflict: null,
                    cachedInflectionalRows: const [],
                    existingRuleId: null,
                    onPosToggled: (posId, on) {
                      setState(() {
                        if (on) {
                          _inflectionalPosSet.add(posId);
                        } else {
                          _inflectionalPosSet.remove(posId);
                        }
                        // Reset cell ref options when POS changes.
                        _selectedCellRefJson = null;
                        if (_formReference is CellFormReference) {
                          _formReference = const BaseFormReference();
                        }
                      });
                    },
                    onBindingChanged: (dimId, levelId) {
                      setState(() {
                        if (levelId != null) {
                          _featureBindings[dimId] = levelId;
                        } else {
                          _featureBindings.remove(dimId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Construction picker
                  Text('Construction', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  constructions.isEmpty
                      ? DropdownButtonFormField<int>(
                          decoration: fieldDecoration,
                          isExpanded: true,
                          hint: const Text(
                            'No constructions defined. Add one in Grammar \u2192 Constructions.',
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: const [],
                          onChanged: null,
                        )
                      : DropdownButtonFormField<int>(
                          initialValue: _selectedConstructionId,
                          decoration: fieldDecoration,
                          isExpanded: true,
                          hint: const Text('Select construction'),
                          items: [
                            for (final c in constructions)
                              DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedConstructionId = v;
                              // Reset slot when construction changes.
                              _selectedWordSlotId = null;
                            });
                          },
                        ),
                  const SizedBox(height: 12),

                  // Word slot picker
                  Text('Word slot', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedWordSlotId,
                    decoration: fieldDecoration,
                    isExpanded: true,
                    hint: _selectedConstructionId == null
                        ? const Text('Select a construction first')
                        : const Text('Select word slot'),
                    items: _selectedConstructionId == null
                        ? const []
                        : [
                            for (final slot in slots)
                              DropdownMenuItem<int>(
                                value: slot.id,
                                child: Text(
                                  '${slot.slotType}: ${slot.slotValue}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                    onChanged: _selectedConstructionId == null
                        ? null
                        : (v) => setState(() => _selectedWordSlotId = v),
                  ),
                  const SizedBox(height: 16),

                  // Form reference picker — RadioGroup (Flutter 3.33+)
                  Text('Resolve word slot as', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  RadioGroup<bool>(
                    groupValue: _cellRefModeActive,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _cellRefModeActive = v;
                        if (!v) {
                          _formReference = const BaseFormReference();
                          _selectedCellRefJson = null;
                        }
                      });
                    },
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          title: Text('Base (uninflected) form'),
                          value: false,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        RadioListTile<bool>(
                          title: Text('Reference another cell'),
                          value: true,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ],
                    ),
                  ),

                  // Cell cross-reference picker — shown when "Reference another cell" is active
                  if (_cellRefModeActive) ...[
                    const SizedBox(height: 8),
                    Text('Target cell', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    cellRefOptions.isEmpty
                        ? Text(
                            'No dimensions defined for the selected POS.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedCellRefJson,
                            decoration: fieldDecoration,
                            isExpanded: true,
                            hint: const Text('Select target cell'),
                            items: [
                              for (final opt in cellRefOptions)
                                DropdownMenuItem<String>(
                                  value: opt.json,
                                  child: Text(
                                    opt.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (json) {
                              if (json == null) return;
                              setState(() {
                                _selectedCellRefJson = json;
                                _formReference = FormReference.fromJson(json);
                              });
                            },
                          ),
                  ],
                ],
              ),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Rule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
