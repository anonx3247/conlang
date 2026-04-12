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
// D-100/D-101 — marker mode: MarkerDecl for pre-loading bindings on edit.
import '../../../grammar/domain/marker.dart';
import '../../../phonology/data/phonotactic_providers.dart';
import '../../../phonology/data/romanization_bijection.dart';
import '../../../phonology/data/romanization_providers.dart';
import '../../../phonology/domain/word_generator.dart';
import '../../../phonology/presentation/shared/ipa_keyboard/ipa_text_field.dart';
import '../../../../shared/widgets/violation_text.dart';
import '../../application/derivation_promotion_service.dart';
import '../../data/morphology_providers.dart';
import '../../domain/morphology_dsl.dart';
import '../../domain/phoneme_literal_scanner.dart';
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

  // D-73 (plan 04-15): RAW phonemic values stashed at load time. Used by
  // the build-time rom hydration pass to re-populate the controllers once
  // the romanizationMappingsProvider stream has resolved.
  String? rawAffix;
  String? rawAblautFrom;
  String? rawAblautTo;
  String? rawSuppletive;

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
  ///
  /// D-73 (plan 04-15): when [literalTransform] is non-null, it is applied to
  /// every SINGLE-TOKEN literal-phoneme field (affix, ablaut from/to,
  /// suppletive) before the MorphOperation is constructed. Used by [_save] to
  /// route field values through `deromanize` when rom mode is active so the
  /// stored MorphologicalRules.source is always phonemic.
  ///
  /// WARN-1 / D-73 partial: template literal runs are NOT transformed — the
  /// template pattern uses structural digit/char semantics and in the 04-15
  /// deferred scope we store the template as-typed. See must_haves.truths.
  MorphOperation? toOperation({String Function(String)? literalTransform}) {
    String t(String s) =>
        literalTransform == null ? s : literalTransform(s);
    return switch (type) {
      OpType.prefix => affixCtrl.text.trim().isNotEmpty
          ? PrefixOp(t(affixCtrl.text.trim()))
          : null,
      OpType.suffix => affixCtrl.text.trim().isNotEmpty
          ? SuffixOp(t(affixCtrl.text.trim()))
          : null,
      OpType.infix => () {
          final affix = affixCtrl.text.trim();
          final pos = int.tryParse(posCtrl.text.trim()) ?? 1;
          return affix.isNotEmpty
              ? InfixOp(affix: t(affix), position: pos)
              : null;
        }(),
      OpType.ablaut => () {
          final from = ablautFromCtrl.text.trim();
          final to = ablautToCtrl.text.trim();
          return (from.isNotEmpty && to.isNotEmpty)
              ? AblautOp(
                  from: t(from),
                  to: t(to),
                  count: ablautCount,
                  direction: ablautDirection,
                )
              : null;
        }(),
      OpType.template => templateCtrl.text.trim().isNotEmpty
          // D-73 partial deferred: template literal runs NOT transformed.
          ? TemplateOp(templateCtrl.text.trim())
          : null,
      OpType.reduplication =>
        RedupOp(scope: redupScope, position: redupPosition),
      OpType.suppletive => suppletiveCtrl.text.trim().isNotEmpty
          ? SuppleteOp(t(suppletiveCtrl.text.trim()))
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
  ///
  /// D-73 (plan 04-15): see [toOperation] — [literalTransform] is forwarded
  /// to every op's literal-token fields. Condition patterns are NOT
  /// transformed (WARN-1 deferred).
  MorphBranch? toBranch({String Function(String)? literalTransform}) {
    final operations = ops
        .map((o) => o.toOperation(literalTransform: literalTransform))
        .whereType<MorphOperation>()
        .toList();
    if (operations.isEmpty) return null;

    final conds = conditions
        .where((c) => c.patternCtrl.text.trim().isNotEmpty)
        .map((c) => PatternCond(
              // WARN-1 / D-73 partial: condition patterns are NOT
              // transformed in 04-15 — structural literal-run wrapping is
              // deferred to a follow-up plan.
              c.patternCtrl.text.trim(),
              position: c.position,
            ) as MorphCondition)
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
///
/// D-100/D-101 (plan 04-18-05): when [markerId] is non-null, the dialog
/// opens in marker mode — the "Leave as unmarked" checkbox is pre-checked,
/// the operations section and preview panel are hidden, and saving writes to
/// [MarkerDao] instead of [MorphologyDao].
class RuleEditorDialog extends ConsumerStatefulWidget {
  const RuleEditorDialog({
    super.key,
    required this.kind,
    this.existing,
    this.preFilledBindings,
    this.markerId,
    this.markerBindings,
  });

  /// Whether this dialog edits an inflectional or derivational rule.
  /// Required — callers must explicitly choose the kind (D-40 / plan 04-05).
  final RuleKind kind;

  /// Drift data row. When non-null, the dialog opens in edit mode.
  final db.MorphologicalRule? existing;

  /// D-51: When provided and [existing] is null and [kind] is inflectional,
  /// pre-fills the dimension chip picker with these (dimId -> levelId)
  /// bindings. Used when the user clicks an empty paradigm cell in the
  /// Grammar > Inflections sub-tab (D-52 ruleEditor click mode) so the
  /// new-rule dialog opens with the clicked cell's features already bound.
  /// Ignored for derivational kind and when editing an existing rule.
  final Map<int, int>? preFilledBindings;

  /// D-100 (plan 04-18-05): when non-null, the dialog opens in marker edit
  /// mode with [_leaveAsUnmarked] pre-checked and [markerBindings] loaded
  /// into the feature-binding picker.
  final int? markerId;

  /// D-100 (plan 04-18-05): pre-loaded bindings when editing an existing
  /// marker. Only meaningful when [markerId] is non-null.
  final FeatureBindings? markerBindings;

  @override
  ConsumerState<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<RuleEditorDialog> {
  final _nameCtrl = TextEditingController();
  final List<_BranchState> _branches = [];

  /// D-100 (plan 04-18-05): when true the dialog is in marker mode —
  /// the operations section and preview panel are hidden; saving writes to
  /// [MarkerDao] instead of [MorphologyDao]. Toggled by the
  /// "Leave as unmarked" checkbox (inflectional mode only).
  bool _leaveAsUnmarked = false;

  /// Legacy selected POS IDs (derivational-era multi-POS filter). Kept so the
  /// DSL preview path and the legacy `posIds` text column keep working while
  /// we migrate to kind-aware bindings. In inflectional mode this mirrors
  /// [_inflectionalPosSet] on every change; in derivational mode it's the
  /// single-element set of [_inputPosId].
  Set<int> _selectedPosIds = {};
  String? _validationError;
  bool _saving = false;

  /// D-90 (plan 04-17 Task 6) — save-time validator reason for rules that
  /// bind only to intrinsic dimensions. Cleared whenever the user modifies
  /// a binding (POS chip or dim chip). Rendered as an inline red Text below
  /// the action bar when non-null; also surfaced as a SnackBar the instant
  /// the user taps Save on a blocked rule.
  String? _saveBlockedReason;

  // ---- Plan 04-05 kind-aware state -----------------------------------------

  /// Inflectional mode — the full POS set this rule applies to (plan 04-11
  /// D-55). Multiple POS can be selected; dimension chip rows render the
  /// intersection of dims across the selected set. An empty set is a
  /// validation error on save.
  final Set<int> _inflectionalPosSet = <int>{};

  /// The first POS id in [_inflectionalPosSet], used as the "chip host" for
  /// single-POS rendering and as the convenience cache in
  /// [MorphologicalRules.inputPosId] on save. Null when no POS is selected.
  int? get _selectedPosIdForChips =>
      _inflectionalPosSet.isEmpty ? null : _inflectionalPosSet.first;

  /// Inflectional mode — selected level per dimension.
  /// Key = dimensionId, value = levelId.
  final Map<int, int> _featureBindings = {};

  /// When non-null, an async hydration from `posSetForRuleProvider` has
  /// populated [_inflectionalPosSet] for this rule id — guards against
  /// re-hydrating on every build.
  int? _hydratedPosSetForRuleId;

  /// Derivational mode — source POS.
  int? _inputPosId;

  /// Derivational mode — target POS (defaults to [_inputPosId] on change).
  int? _outputPosId;

  /// Derivational mode — D-59 auto_apply flag. When true, every matching-POS
  /// word is auto-promoted into a Lexeme row with a templated gloss on save.
  /// Ignored in inflectional mode (the column defaults to false there).
  bool _autoApply = false;

  /// Latest tiebreak computation result for inflectional mode. Null when
  /// there's no conflict.
  TiebreakConflict? _tiebreakConflict;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _loadFromExisting(widget.existing!);
    }
    // D-100: if opened for an existing marker, enter marker mode and
    // pre-load its bindings into the feature-binding picker.
    if (widget.markerId != null) {
      _leaveAsUnmarked = true;
      if (widget.markerBindings != null) {
        _featureBindings.addAll(widget.markerBindings!.dims);
        if (widget.markerBindings!.pos.isNotEmpty) {
          _inflectionalPosSet.addAll(widget.markerBindings!.pos);
          _selectedPosIds = Set<int>.from(_inflectionalPosSet);
        }
      }
    }
    if (widget.existing == null) {
      // Default: one branch with one suffix op.
      _branches.add(_BranchState());
      // D-51: seed feature bindings from caller-provided pre-fill
      // (inflectional only — derivational rules have no dim bindings).
      if (widget.kind == RuleKind.inflectional &&
          widget.preFilledBindings != null) {
        _featureBindings.addAll(widget.preFilledBindings!);
      }
    }
    // Tiebreak is recomputed inside build() from the live Riverpod stream,
    // so initState doesn't need to schedule a post-frame callback.
  }

  /// D-73 (plan 04-15): set to true once the romanize hydration pass has
  /// run successfully in build() — guards against re-running on every
  /// rebuild and lets `initState` stash the raw phonemic values while the
  /// mappings stream is still loading its first event.
  bool _romDisplayHydrated = false;

  /// Populate form state from a Drift [db.MorphologicalRule] row.
  ///
  /// D-73 (plan 04-15): literal-phoneme fields (affix, ablautFrom, ablautTo,
  /// removeSuffix, suppletive) are passed through `romanizeProvider` on the
  /// load path when rom is enabled so the user sees their rom input instead
  /// of the stored phonemic form. Class-ref tokens (V, C, F, [name]) and
  /// condition/template literal runs are NOT wrapped — see must_haves.truths
  /// D-73 partial-string scope and the WARN-1 deferral.
  ///
  /// Two-phase hydration: initState stashes RAW phonemic values in every
  /// controller (the mappings stream hasn't emitted yet, so romanize is
  /// identity). Then [_hydrateRomDisplay] runs in build() once the stream
  /// resolves and re-populates the wrapped controllers with the rom form.
  //
  // WARN-1 / D-73 partial: template + condition literal runs are NOT wrapped
  // in 04-15 — see must_haves.truths, follow-up plan needed.
  void _loadFromExisting(db.MorphologicalRule row) {
    _nameCtrl.text = row.name;

    // D-73 (plan 04-15): wrap literal-phoneme fields with romanize() on load.
    // We read the synchronous snapshot of romanizationEnabledProvider +
    // romanizeProvider here; if the mappings stream hasn't resolved yet,
    // `romanize` falls back to identity and [_hydrateRomDisplay] will
    // re-run in build() with the real mapping set.
    final romEnabled =
        ref.read(romanizationEnabledProvider).asData?.value ?? true;
    final romanize = ref.read(romanizeProvider);
    String display(String stored) => romEnabled ? romanize(stored) : stored;

    // Seed kind-specific state from the row's featureBindings before we set
    // up the legacy _selectedPosIds fallback.
    final bindings = row.featureBindings;
    if (widget.kind == RuleKind.inflectional) {
      _featureBindings.addAll(bindings.dims);
      // v9 plan 04-11: the junction table is authoritative for POS set.
      // Seed with the legacy v8 shape (featureBindings.pos OR inputPosId) so
      // the form has something to render immediately, then let the async
      // `posSetForRuleProvider` hydration path overwrite once the stream
      // resolves in build().
      if (bindings.pos.isNotEmpty) {
        _inflectionalPosSet.addAll(bindings.pos);
      } else if (row.inputPosId != null) {
        _inflectionalPosSet.add(row.inputPosId!);
      }
      if (_inflectionalPosSet.isNotEmpty) {
        _selectedPosIds = Set<int>.from(_inflectionalPosSet);
      }
    } else {
      _inputPosId =
          row.inputPosId ?? (bindings.pos.isNotEmpty ? bindings.pos.first : null);
      _outputPosId = row.outputPosId ?? _inputPosId;
      // D-59 (plan 04-14): hydrate the auto_apply flag on edit so the
      // checkbox reflects the persisted value when the dialog reopens.
      _autoApply = row.autoApply;
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
            // D-73: single-token literal — wrap through romanize on load.
            // Stash raw phonemic so the build-time hydration pass can
            // re-apply romanize once the mappings stream has resolved.
            os.rawAffix = affix;
            os.affixCtrl.text = display(affix);
          case SuffixOp(:final affix):
            os.type = OpType.suffix;
            os.rawAffix = affix;
            os.affixCtrl.text = display(affix);
          case InfixOp(:final affix, :final position):
            os.type = OpType.infix;
            // D-73 partial: infix affix literal is still wrapped (it's a
            // single-token literal field like prefix/suffix). Only the
            // TEMPLATE field is deferred.
            os.rawAffix = affix;
            os.affixCtrl.text = display(affix);
            os.posCtrl.text = '$position';
          case AblautOp(:final from, :final to, :final count, :final direction):
            os.type = OpType.ablaut;
            os.rawAblautFrom = from;
            os.rawAblautTo = to;
            os.ablautFromCtrl.text = display(from);
            os.ablautToCtrl.text = display(to);
            os.ablautCount = count;
            os.ablautDirection = direction;
          case TemplateOp(:final pattern):
            os.type = OpType.template;
            // WARN-1 / D-73 partial: template literal runs are NOT wrapped
            // in 04-15. Stored as-typed under rom mode; follow-up plan.
            os.templateCtrl.text = pattern;
          case RedupOp(:final scope, :final position):
            os.type = OpType.reduplication;
            os.redupScope = scope;
            os.redupPosition = position;
          case SuppleteOp(:final form):
            os.type = OpType.suppletive;
            // Suppletive whole-word override — a single literal phoneme
            // string, wrap on load.
            os.rawSuppletive = form;
            os.suppletiveCtrl.text = display(form);
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

  // WARN-8 / D-81 plan 04-16: every wrapped literal field
  // re-triggers the PhonemeViolationRow's scanner read by forcing a
  // State rebuild on text change. Factored into one callback so we
  // do not duplicate the lambda across 7 fields.
  void _rebuildOnLiteralInput(String _) {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    // D-101 (plan 04-18-05): marker mode save path — writes to MarkerDao,
    // skips MorphologyDao entirely. Gated by _leaveAsUnmarked flag.
    if (_leaveAsUnmarked) {
      await _saveMarker();
      return;
    }

    // D-81 plan 04-16: scanner violations are soft warnings only —
    // never block save. There is no `if (violations.isNotEmpty)
    // return;` branch anywhere in this save path. The user may
    // intentionally prototype a rule for a phoneme they're about to
    // add to the inventory; warnings are informational.
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Rule name is required.');
      return;
    }

    // Plan 04-11 D-55: inflectional rules must attach to at least one POS.
    // An inflectional rule with no POS set would be unreachable via the
    // junction-driven watchInflectionalRulesForPos query.
    if (widget.kind == RuleKind.inflectional && _inflectionalPosSet.isEmpty) {
      setState(() {
        _validationError =
            'At least one POS must be selected for inflectional rules.';
      });
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

    // D-73 (plan 04-15): save-path rom -> phonemic conversion. When rom
    // mode is active, literal-phoneme fields (affix, ablaut from/to,
    // suppletive) are passed through `deromanizeProvider` BEFORE the
    // MorphOperation is constructed so the serialized source written to
    // MorphologicalRules.source is always phonemic IPA.
    //
    // WARN-1 / D-73 partial: template + condition literal runs are NOT
    // wrapped in 04-15 — see must_haves.truths, follow-up plan needed.
    final romEnabled =
        ref.read(romanizationEnabledProvider).asData?.value ?? true;
    final deromanize = ref.read(deromanizeProvider);
    final String Function(String)? literalTransform =
        romEnabled ? deromanize : null;

    final branches = _branches
        .map((b) => b.toBranch(literalTransform: literalTransform))
        .whereType<MorphBranch>()
        .toList();
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
      // Plan 04-11 D-55: featureBindings.pos carries the full multi-POS set
      // for inflectional rules as a convenience cache. The inflectional_rule_pos
      // junction is authoritative — both reads AND writes go through it
      // below via replaceForRule.
      boundPos = _inflectionalPosSet.toList()..sort();
      boundDims = Map<int, int>.from(_featureBindings);
    } else {
      boundPos = _inputPosId == null ? const <int>[] : <int>[_inputPosId!];
      boundDims = const <int, int>{};
    }
    final featureBindings =
        FeatureBindings(pos: boundPos, dims: boundDims);

    // ---- D-90 / plan 04-17 Task 6 — block sole-intrinsic-binding rules ----
    //
    // [WARN-3 revision] Iterate EVERY POS in bindings.pos, not just the
    // first. A rule like [Noun, Adjective] where `gender` is intrinsic
    // on Noun but non-intrinsic on Adjective must NOT be blocked if ANY
    // POS has a non-intrinsic axis available. Using only the first POS
    // (pre-revision behavior) would produce a list-order-dependent
    // verdict, which is unsafe. The correct semantics: for each posId in
    // bindings.pos, compute the nonIntrinsicAxes projection under that
    // POS's dimension intrinsic-flag map; the rule is blocked iff EVERY
    // POS yields an empty nonIntrinsicAxes set (no POS under which the
    // rule would produce paradigm variation).
    //
    // Empty-bindings rules (bindings.dims.isEmpty) are intentionally NOT
    // blocked here — the derivational/unbound inflectional path upstream
    // already handled that.
    final bindings = featureBindings; // grep-locked alias: `bindings.pos`
    if (widget.kind == RuleKind.inflectional &&
        bindings.dims.isNotEmpty &&
        bindings.pos.isNotEmpty) {
      var anyPosHasNonIntrinsicAxis = false;
      for (final posId in bindings.pos) {
        final dims =
            await ref.read(dimensionsForPosProvider(posId).future);
        // intrinsicFlags maps only dim ids that EXIST on this POS to
        // their intrinsic boolean. Dim ids absent from the POS are
        // intentionally not present in the map — a binding on a dim
        // that this POS does not define cannot produce variation for
        // this POS regardless of intrinsicness, so it is NOT counted
        // as a non-intrinsic axis here.
        final intrinsicFlags = {for (final d in dims) d.id: d.intrinsic};
        final nonIntrinsicAxes = bindings.dims.keys
            .where((id) =>
                intrinsicFlags.containsKey(id) && intrinsicFlags[id] == false)
            .toList();
        if (nonIntrinsicAxes.isNotEmpty) {
          anyPosHasNonIntrinsicAxis = true;
          break;
        }
      }
      if (!anyPosHasNonIntrinsicAxis) {
        // Exact locked error copy from D-90 — grep-verified in Task 12.
        // Single-line string so `grep 'Rule has no non-intrinsic axes'`
        // AND `grep 'intrinsic-only behavior belongs in standard-form patterns'`
        // both succeed against this source file.
        // ignore: lines_longer_than_80_chars
        const errorCopy = 'Rule has no non-intrinsic axes — it would produce no paradigm variation. Intrinsic-only behavior belongs in standard-form patterns at word creation, not inflection rules.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(errorCopy),
              duration: Duration(seconds: 6),
            ),
          );
          setState(() {
            _saving = false;
            _saveBlockedReason = errorCopy;
          });
        }
        return; // Do NOT proceed with insertRule / updateRule.
      }
    }

    // Legacy CSV stays in lockstep with the new bindings so the posIds column
    // continues to mirror reality until it's physically dropped (A9).
    final posIdsStr =
        boundPos.isEmpty ? '' : boundPos.map((p) => '$p').join(',');

    // Plan 04-11 D-55: for inflectional rules, populate input_pos_id with the
    // FIRST selected POS as a convenience cache so any v8 caller that still
    // reads the legacy column gets a sensible value. The junction table is
    // authoritative for lookups (Task 2).
    final firstInflPosId = widget.kind == RuleKind.inflectional &&
            _inflectionalPosSet.isNotEmpty
        ? _inflectionalPosSet.first
        : null;

    final companionInputPos = widget.kind == RuleKind.derivational
        ? Value<int?>(_inputPosId)
        : Value<int?>(firstInflPosId);
    final companionOutputPos = widget.kind == RuleKind.derivational
        ? Value<int?>(_outputPosId)
        : const Value<int?>.absent();

    final junctionDao = ref.read(inflectionalRulePOSDaoProvider);

    try {
      int ruleIdForJunction;
      if (widget.existing != null) {
        ruleIdForJunction = widget.existing!.id;
        await dao.updateRule(widget.existing!.copyWith(
          name: name,
          source: source,
          posIds: posIdsStr,
          kind: widget.kind.dbString,
          featureBindings: featureBindings,
          inputPosId: widget.kind == RuleKind.derivational
              ? Value<int?>(_inputPosId)
              : Value<int?>(firstInflPosId),
          outputPosId: widget.kind == RuleKind.derivational
              ? Value<int?>(_outputPosId)
              : const Value<int?>(null),
          // D-59 (plan 04-14): persist the derivational auto_apply flag.
          // Inflectional rules always write false (the column is unused
          // for that kind).
          autoApply:
              widget.kind == RuleKind.derivational ? _autoApply : false,
        ));
      } else {
        final ordering = await dao.nextOrdering();
        ruleIdForJunction = await dao.insertRuleWithKind(
          db.MorphologicalRulesCompanion(
            name: Value(name),
            source: Value(source),
            ordering: Value(ordering),
            posIds: Value(posIdsStr),
            featureBindings: Value(featureBindings),
            inputPosId: companionInputPos,
            outputPosId: companionOutputPos,
            // D-59 (plan 04-14): new derivational rules carry the flag; the
            // column defaults to false so the inflectional branch is fine
            // with `absent`, but we write an explicit false for clarity.
            autoApply: Value(
              widget.kind == RuleKind.derivational ? _autoApply : false,
            ),
          ),
          widget.kind,
        );
      }

      // Plan 04-11 D-55: write the POS set to the junction for inflectional
      // rules. This is the authoritative source of "which POS does this rule
      // apply to" in v9+.
      if (widget.kind == RuleKind.inflectional && junctionDao != null) {
        await junctionDao.replaceForRule(
          ruleId: ruleIdForJunction,
          posIds: Set<int>.from(_inflectionalPosSet),
        );
      }

      // D-59 (plan 04-14): when the user turned auto_apply ON for a
      // derivational rule, immediately reconcile so every matching-POS
      // word is promoted NOW instead of waiting for the next app start.
      // The service is idempotent — re-running on an already-reconciled
      // rule is a no-op.
      if (widget.kind == RuleKind.derivational && _autoApply) {
        await ref.read(derivationPromotionServiceProvider).reconcile();
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // D-101 — marker mode save (plan 04-18-05)
  // ---------------------------------------------------------------------------

  /// Saves the dialog as a [MarkerDecl] via [MarkerDao].
  ///
  /// Validation: at least one binding must be selected and at least one POS
  /// must be chosen. The POS is read from [_inflectionalPosSet] (markers are
  /// per-POS, so only the first selected POS is used if multiple are picked).
  Future<void> _saveMarker() async {
    // Validate: at least one binding required.
    if (_featureBindings.isEmpty) {
      setState(() => _validationError =
          'Select at least one dimension + level to mark as unmarked.');
      return;
    }
    // Validate: a POS must be selected.
    if (_inflectionalPosSet.isEmpty) {
      setState(() => _validationError =
          'Select at least one POS to attach this marker to.');
      return;
    }

    final dao = ref.read(markerDaoProvider);
    if (dao == null) return;

    setState(() {
      _saving = true;
      _validationError = null;
    });

    try {
      final bindings = FeatureBindings(
        pos: [_inflectionalPosSet.first],
        dims: Map<int, int>.from(_featureBindings),
      );
      final posId = _inflectionalPosSet.first;

      if (widget.markerId != null) {
        // Edit existing marker.
        await dao.updateMarker(widget.markerId!, bindings);
      } else {
        // Create new marker.
        await dao.insertMarker(posId: posId, bindings: bindings);
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
                      // D-90 — clear any prior blocked-save hint the moment
                      // the user edits a binding, so the inline red text
                      // disappears the same frame.
                      _saveBlockedReason = null;
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

  /// Inflectional mode top: multi-POS FilterChip picker (plan 04-11 D-55)
  /// + chip rows per intersected dimension + validation hint + live
  /// tiebreak banner.
  ///
  /// The "Target POS" column was replaced with a FilterChip row: tapping a
  /// chip adds/removes that POS from [_inflectionalPosSet]. Dimension chip
  /// rows render the INTERSECTION (by name) of dimensions across every
  /// selected POS so the user can only bind to dims that exist in all.
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

    // Multi-POS picker (plan 04-11 D-55). Replaces the single "Target POS"
    // dropdown. An empty set is a save-time validation error.
    widgets.add(
      Wrap(
        key: const ValueKey('inflectionalPosPickerWrap'),
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final pos in posList)
            FilterChip(
              label: Text('${pos.name} (${pos.abbreviation})'),
              tooltip: pos.name,
              selected: _inflectionalPosSet.contains(pos.id),
              onSelected: (on) {
                setState(() {
                  if (on) {
                    _inflectionalPosSet.add(pos.id);
                  } else {
                    _inflectionalPosSet.remove(pos.id);
                    // Drop any dim bindings whose dim id is no longer in the
                    // intersection (best-effort — the build-time intersection
                    // filter will surface the mismatch too).
                  }
                  // D-90 — clear any prior blocked-save hint the moment
                  // the user edits the POS set.
                  _saveBlockedReason = null;
                  _selectedPosIds = Set<int>.from(_inflectionalPosSet);
                  _recomputeTiebreak(_cachedInflectionalRows);
                });
              },
            ),
        ],
      ),
    );
    if (_inflectionalPosSet.isEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text(
        'Select at least one POS above.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
      ));
    }
    widgets.add(const SizedBox(height: 12));

    // Dimension chip rows — only rendered when at least one POS is selected.
    // For a single-POS selection we show that POS's dimensions directly.
    // For multi-POS selection we show the intersection (by dimension name).
    if (_inflectionalPosSet.isNotEmpty) {
      widgets.add(Consumer(builder: (ctx, ref, _) {
        // Watch every selected POS's dimension stream.
        final perPosDims = <List<db.Dimension>>[];
        for (final posId in _inflectionalPosSet) {
          final async = ref.watch(dimensionsForPosProvider(posId));
          perPosDims.add(async.asData?.value ?? const <db.Dimension>[]);
        }
        // Intersect by dimension NAME — dimensions are per-POS rows (D-02)
        // that share names across POS but not ids. Render the FIRST POS's
        // dimension row for any name that appears in every other POS's set.
        final List<db.Dimension> dims;
        if (perPosDims.any((l) => l.isEmpty)) {
          dims = const <db.Dimension>[];
        } else if (perPosDims.length == 1) {
          dims = perPosDims.first;
        } else {
          final names = perPosDims.first.map((d) => d.name).toSet();
          for (final list in perPosDims.skip(1)) {
            names.retainAll(list.map((d) => d.name));
          }
          dims = perPosDims.first.where((d) => names.contains(d.name)).toList();
        }
        if (dims.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _inflectionalPosSet.length > 1
                  ? 'These POS share no common dimensions — rule cannot '
                      'bind any features.'
                  : 'This POS has no dimensions yet. Add dimensions in '
                      'Grammar → POS & Dimensions to enable inflectional '
                      'binding.',
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
      // D-59 / G-18 (plan 04-14): auto_apply checkbox + templated-gloss
      // preview. Derivational-only — the column defaults to false for
      // inflectional rules and the checkbox isn't rendered there.
      const SizedBox(height: 12),
      CheckboxListTile(
        value: _autoApply,
        onChanged: (v) => setState(() => _autoApply = v ?? false),
        title: const Text('Auto-apply to all matching words'),
        subtitle: const Text(
          'Every matching-POS word gets a new derived lexeme automatically '
          'with a templated gloss',
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
      if (_autoApply)
        Padding(
          padding: const EdgeInsets.only(left: 48, top: 2),
          child: Text(
            // D-59 exact template: "{parent meaning} ({rule.name})" — the
            // kama/Actor example from 04-CONTEXT-GAPS renders as
            // "to run (Actor)". Falls back to "rule name" placeholder when
            // the name field is empty.
            'Template: "parent meaning '
            '(${_nameCtrl.text.isEmpty ? 'rule name' : _nameCtrl.text})"',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// D-73 rom display hydration pass (plan 04-15).
  ///
  /// `_loadFromExisting` runs in `initState`, which is BEFORE the Drift
  /// stream query backing `romanizationMappingsProvider` has emitted its
  /// first value — so the synchronous `ref.read(romanizeProvider)` call
  /// there returns the identity fallback and the controllers end up
  /// holding raw phonemic text. This method re-applies romanize to each
  /// stashed raw value once the mappings stream has resolved. Runs at
  /// most once per dialog lifetime (guarded by [_romDisplayHydrated]).
  void _hydrateRomDisplay() {
    if (_romDisplayHydrated) return;
    // Only hydrate once the mappings stream has resolved. If it's still
    // loading, leave the raw text in place — build() will call us again
    // on the next frame once data arrives.
    final mappingsAsync = ref.read(romanizationMappingsProvider);
    if (mappingsAsync is! AsyncData) return;
    final romEnabled =
        ref.read(romanizationEnabledProvider).asData?.value ?? true;
    if (!romEnabled) {
      // rom disabled — nothing to wrap. Mark hydrated so we don't re-run.
      _romDisplayHydrated = true;
      return;
    }
    final romanize = ref.read(romanizeProvider);
    for (final branch in _branches) {
      for (final op in branch.ops) {
        if (op.rawAffix != null) {
          op.affixCtrl.text = romanize(op.rawAffix!);
        }
        if (op.rawAblautFrom != null) {
          op.ablautFromCtrl.text = romanize(op.rawAblautFrom!);
        }
        if (op.rawAblautTo != null) {
          op.ablautToCtrl.text = romanize(op.rawAblautTo!);
        }
        if (op.rawSuppletive != null) {
          op.suppletiveCtrl.text = romanize(op.rawSuppletive!);
        }
      }
    }
    _romDisplayHydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // D-73 hydration: once the mappings stream has resolved, re-apply
    // romanize to the stashed raw phonemic values in each op state so
    // the user sees their rom input. Watched (not read) so that if the
    // mappings change while the editor is open, we... actually no —
    // changing mappings mid-edit would clobber user input, so we guard
    // via _romDisplayHydrated.
    _hydrateRomDisplay();

    // D-72 (plan 04-15): check romanization bijection status. When the
    // active mapping set has any violations, the rule editor is locked —
    // the body is replaced with a read-only message pointing the user to
    // the romanization settings, and the save button is hidden.
    final bijectionViolations =
        ref.watch(bijectionStatusProvider).asData?.value ??
            const <BijectionViolation>[];
    final bijectionLocked = bijectionViolations.isNotEmpty;
    if (bijectionLocked) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rule editor is locked until romanization conflicts '
                        'are resolved — see Phonology → Romanization.',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final v in bijectionViolations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${v.detail}',
                        style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

      // Plan 04-11 D-55: hydrate the POS set from the junction table when
      // editing an existing rule. Done once per rule id — subsequent taps on
      // the FilterChip row remain the user's authoritative intent and must
      // not be overwritten by the stream on every rebuild.
      final existingId = widget.existing?.id;
      if (existingId != null && _hydratedPosSetForRuleId != existingId) {
        final async = ref.watch(posSetForRuleProvider(existingId));
        final fromJunction = async.asData?.value;
        if (fromJunction != null) {
          _hydratedPosSetForRuleId = existingId;
          if (fromJunction.isNotEmpty) {
            // Overwrite the legacy seed from _loadFromExisting with the
            // authoritative junction set.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _inflectionalPosSet
                  ..clear()
                  ..addAll(fromJunction);
                _selectedPosIds = Set<int>.from(_inflectionalPosSet);
                _recomputeTiebreak(_cachedInflectionalRows);
              });
            });
          }
        }
      }
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
                    widget.markerId != null
                        ? 'Edit Marker'
                        : (_leaveAsUnmarked
                            ? 'New Marker'
                            : (widget.existing != null
                                ? 'Edit Rule'
                                : 'New Rule')),
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
                          const SizedBox(height: 8),

                          // D-100 (plan 04-18-05): "Leave as unmarked"
                          // checkbox — inflectional mode only. Toggles
                          // between rule mode and marker mode. In marker
                          // mode the operations section and preview panel
                          // are hidden; only the bindings picker remains.
                          if (widget.kind == RuleKind.inflectional)
                            CheckboxListTile(
                              value: _leaveAsUnmarked,
                              onChanged: (v) =>
                                  setState(() => _leaveAsUnmarked = v ?? false),
                              title: const Text(
                                  'Leave as unmarked (no rule, just a ∅ cell)'),
                              dense: true,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          const SizedBox(height: 4),

                          // Kind-aware top section (plan 04-05).
                          if (widget.kind == RuleKind.inflectional)
                            ..._buildInflectionalTop(theme, cs, posList)
                          else
                            ..._buildDerivationalTop(theme, cs, posList),
                          const SizedBox(height: 16),

                          // D-100: hide ops + add-branch button in marker mode.
                          if (!_leaveAsUnmarked) ...[
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

                  // D-100: hide preview panel in marker mode.
                  if (!_leaveAsUnmarked)
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
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                  // D-90 / plan 04-17 Task 6 — inline red reason shown below
                  // the Save button when the user tapped Save on a rule that
                  // only binds intrinsic dims. Cleared on any binding edit.
                  if (_saveBlockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _saveBlockedReason!,
                        key: const ValueKey('saveBlockedReasonText'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.error),
                      ),
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
                // Pattern field + inline phoneme-violation warning
                // (D-81 plan 04-16 / G-69, 'cond' scope skips V/C/F
                // and bracketed class-refs).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: cond.patternCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. [nasal]V, CV, Vk(l)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                        ),
                        onChanged: _rebuildOnLiteralInput,
                      ),
                      _PhonemeViolationRow(
                          text: cond.patternCtrl.text, scope: 'cond'),
                    ],
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

    // D-73 + D-78 (plan 04-15): compute the rom-aware helper text once
    // per rebuild. When rom is enabled, every literal-phoneme field shows
    // the auto-convert blurb AND the `.` escape-hatch discoverability
    // hint. When rom is disabled, fields show a simple "phonemic IPA"
    // note so users know what notation the field expects.
    final romEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? true;
    final String literalHelperText = romEnabled
        ? 'rom (auto-converted to phonemic on save) — '
            'use . to force a glyph boundary (e.g. at.ha vs atha)'
        : 'phonemic IPA';

    return switch (op.type) {
      OpType.prefix || OpType.suffix => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IpaTextField(
              controller: op.affixCtrl,
              decoration: fieldDecoration.copyWith(
                hintText: 'IPA affix, e.g. in, ɯ',
                helperText: literalHelperText,
                helperMaxLines: 2,
              ),
              onChanged: _rebuildOnLiteralInput,
            ),
            _PhonemeViolationRow(
                text: op.affixCtrl.text, scope: 'op'),
          ],
        ),
      OpType.infix => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: IpaTextField(
                    controller: op.affixCtrl,
                    decoration: fieldDecoration.copyWith(
                      hintText: 'IPA affix',
                      helperText: literalHelperText,
                      helperMaxLines: 2,
                    ),
                    onChanged: _rebuildOnLiteralInput,
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
            _PhonemeViolationRow(
                text: op.affixCtrl.text, scope: 'op'),
          ],
        ),
      OpType.ablaut => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: op.ablautFromCtrl,
                        decoration: fieldDecoration.copyWith(
                          hintText: 'from',
                          helperText: literalHelperText,
                          helperMaxLines: 2,
                        ),
                        onChanged: _rebuildOnLiteralInput,
                      ),
                      _PhonemeViolationRow(
                          text: op.ablautFromCtrl.text, scope: 'op'),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IpaTextField(
                        controller: op.ablautToCtrl,
                        decoration: fieldDecoration.copyWith(
                          hintText: 'to',
                          helperText: literalHelperText,
                          helperMaxLines: 2,
                        ),
                        onChanged: _rebuildOnLiteralInput,
                      ),
                      _PhonemeViolationRow(
                          text: op.ablautToCtrl.text, scope: 'op'),
                    ],
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
      OpType.template => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: op.templateCtrl,
              decoration: fieldDecoration.copyWith(
                hintText: 'e.g. 1a23aa',
                helperText:
                    'Digits = consonant slots, other chars literal',
              ),
              onChanged: _rebuildOnLiteralInput,
            ),
            _PhonemeViolationRow(
                text: op.templateCtrl.text, scope: 'template'),
          ],
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
      OpType.suppletive => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IpaTextField(
              controller: op.suppletiveCtrl,
              decoration: fieldDecoration.copyWith(
                  hintText:
                      'Replaces entire word (e.g. went for go, mice for mouse)'),
              onChanged: _rebuildOnLiteralInput,
            ),
            _PhonemeViolationRow(
                text: op.suppletiveCtrl.text, scope: 'op'),
          ],
        ),
    };
  }
}

/// D-81 plan 04-16 / G-69 — renders a compact inline phoneme-violation
/// warning beneath a literal rule-editor TextField. Returns
/// [SizedBox.shrink] when the scanner reports no violations for [text].
/// Watches [phonemeInventoryProvider] for reactivity — adding the
/// missing phoneme to the inventory clears the warning automatically.
///
/// This widget is intentionally SOFT-WARNING-ONLY: it never blocks
/// save, never triggers state changes, never exposes a callback. It is
/// a pure read-side indicator.
class _PhonemeViolationRow extends ConsumerWidget {
  const _PhonemeViolationRow({
    required this.text,
    required this.scope,
  });

  /// The literal text from the associated TextField's controller.
  final String text;

  /// One of:
  ///   - 'op'       — wrap in a synthetic SuffixOp (generic literal field)
  ///   - 'template' — wrap in a synthetic TemplateOp (digit-slot skipping)
  ///   - 'cond'     — wrap in a synthetic PatternCond (class-ref skipping)
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) return const SizedBox.shrink();
    final inventory = ref.watch(phonemeInventoryProvider);

    // D-81 04-16 user feedback fix (2026-04-11): when romanization is
    // enabled, the rule editor displays the rom form of stored phonemic
    // literals (e.g. the user's mapping `ø → o` renders a stored `ø` as
    // `o` in the field). The scanner must receive the DEROMANIZED
    // phonemic form so the inventory check compares phonemes against
    // phonemes, not rom glyphs against phonemes. Without this, typing a
    // valid rom like `o` (which maps to phonemic `ø` in the inventory)
    // incorrectly emits "Contains unknown phoneme: 'o'".
    //
    // We scan the deromanized form and, if violations exist, show the
    // warning on the DEROMANIZED text (not the rom text) so the user
    // sees the exact phoneme-level offender. This is a small cosmetic
    // divergence from the field display but keeps the warning accurate.
    final romEnabled =
        ref.watch(romanizationEnabledProvider).asData?.value ?? true;
    final deromanize = ref.watch(deromanizeProvider);
    final scanText = romEnabled ? deromanize(text) : text;

    // Build a minimal synthetic rule with a single branch + single
    // op/cond containing [scanText], run the scanner, and render a
    // ViolationText if any violations are reported.
    final synthetic = switch (scope) {
      'cond' => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: [PatternCond(scanText)],
              operations: const [SuffixOp('')],
            ),
          ],
        ),
      'template' => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: const [],
              operations: [TemplateOp(scanText)],
            ),
          ],
        ),
      _ => MorphologicalRule(
          id: 0,
          name: '',
          source: '',
          branches: [
            MorphBranch(
              conditions: const [],
              operations: [SuffixOp(scanText)],
            ),
          ],
        ),
    };
    final parsed = ParsedMorphRule.success(source: '', rule: synthetic);
    final violations =
        const PhonemeLiteralScanner().scan(parsed, inventory);
    if (violations.isEmpty) return const SizedBox.shrink();

    // Map PhonemeViolation -> Violation for ViolationText. The locked
    // tooltip copy from CONTEXT.md D-81 is embedded here — exact
    // string enforced by widget tests. Soft warnings only: save is
    // never blocked on these violations.
    final mapped = violations
        .map((v) => Violation(
              position: v.literalOffset,
              length: v.length,
              ruleDescription:
                  "'${v.char}' is not in the phoneme inventory (did you mean to define it first?)",
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ViolationText(
        text: scanText,
        violations: mapped,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
