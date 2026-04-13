// ignore_for_file: public_member_api_docs
import '../../../../../db/app_database.dart' as db;
import '../../../../grammar/domain/rule_kind.dart';
import '../../../domain/morphology_dsl.dart';
import 'form_state_models.dart';

// ---------------------------------------------------------------------------
// Form loader — extracted from rule_editor_body.dart to stay under 500 lines.
// Parses a DB MorphologicalRule row into mutable form-state collections.
// ---------------------------------------------------------------------------

/// Result of loading a [db.MorphologicalRule] row into form state.
class FormLoadResult {
  final String name;
  final List<BranchState> branches;
  final Set<int> inflectionalPosSet;
  final Map<int, int> featureBindings;
  final Set<int> selectedPosIds;
  final int? inputPosId;
  final int? outputPosId;
  final bool autoApply;
  final Map<int, int> outputIntrinsicLevels;

  const FormLoadResult({
    required this.name,
    required this.branches,
    required this.inflectionalPosSet,
    required this.featureBindings,
    required this.selectedPosIds,
    required this.inputPosId,
    required this.outputPosId,
    required this.autoApply,
    required this.outputIntrinsicLevels,
  });
}

/// Parses [row] into mutable form state.
///
/// [romanize] may be the identity function if the mapping stream hasn't
/// resolved yet — [rawValues] in the returned [BranchState]s allow the
/// hydration pass to re-apply once it resolves.
///
/// D-73 (plan 04-15): literal-phoneme fields are wrapped through [romanize]
/// on the load path when [romEnabled] is true.
FormLoadResult loadFormFromRow({
  required db.MorphologicalRule row,
  required RuleKind kind,
  required bool romEnabled,
  required String Function(String) romanize,
}) {
  String display(String stored) => romEnabled ? romanize(stored) : stored;

  final inflectionalPosSet = <int>{};
  final featureBindings = <int, int>{};
  var selectedPosIds = <int>{};
  int? inputPosId;
  int? outputPosId;
  var autoApply = false;
  var outputIntrinsicLevels = <int, int>{};

  final bindings = row.featureBindings;
  if (kind == RuleKind.inflectional) {
    featureBindings.addAll(bindings.dims);
    if (bindings.pos.isNotEmpty) {
      inflectionalPosSet.addAll(bindings.pos);
    } else if (row.inputPosId != null) {
      inflectionalPosSet.add(row.inputPosId!);
    }
    if (inflectionalPosSet.isNotEmpty) {
      selectedPosIds = Set<int>.from(inflectionalPosSet);
    }
  } else {
    inputPosId =
        row.inputPosId ?? (bindings.pos.isNotEmpty ? bindings.pos.first : null);
    outputPosId = row.outputPosId ?? inputPosId;
    autoApply = row.autoApply;
    if (bindings.outputIntrinsic.isNotEmpty) {
      outputIntrinsicLevels = Map<int, int>.from(bindings.outputIntrinsic);
    }
  }

  if (selectedPosIds.isEmpty) {
    if (row.posIds.isNotEmpty) {
      selectedPosIds = row.posIds
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toSet();
    } else if (row.posId != null) {
      selectedPosIds = {row.posId!};
    }
  }

  final branches = <BranchState>[];
  final parsed = parseMorphDsl(row.source, id: row.id, name: row.name);
  if (!parsed.isValid || parsed.rule == null) {
    branches.add(BranchState());
    return FormLoadResult(
      name: row.name,
      branches: branches,
      inflectionalPosSet: inflectionalPosSet,
      featureBindings: featureBindings,
      selectedPosIds: selectedPosIds,
      inputPosId: inputPosId,
      outputPosId: outputPosId,
      autoApply: autoApply,
      outputIntrinsicLevels: outputIntrinsicLevels,
    );
  }

  for (final branch in parsed.rule!.branches) {
    final bs = BranchState(ops: []);
    if (branch.conditions.isEmpty) {
      bs.conditions = [CondState()];
    } else {
      bs.conditions = branch.conditions.map((cond) {
        if (cond case PatternCond(:final pattern, :final position)) {
          return CondState(position: position, pattern: pattern);
        }
        return CondState();
      }).toList();
    }
    for (final op in branch.operations) {
      final os = _opStateFromDomain(op, display);
      if (os != null) bs.ops.add(os);
    }
    if (bs.ops.isEmpty) bs.ops.add(OpState());
    branches.add(bs);
  }

  if (branches.isEmpty) branches.add(BranchState());

  return FormLoadResult(
    name: row.name,
    branches: branches,
    inflectionalPosSet: inflectionalPosSet,
    featureBindings: featureBindings,
    selectedPosIds: selectedPosIds,
    inputPosId: inputPosId,
    outputPosId: outputPosId,
    autoApply: autoApply,
    outputIntrinsicLevels: outputIntrinsicLevels,
  );
}

/// Converts a domain [MorphOperation] to an [OpState], applying [display]
/// to literal-phoneme fields. Returns null for [RemoveSuffixOp] (UI skips it).
OpState? _opStateFromDomain(
    MorphOperation op, String Function(String) display) {
  final os = OpState();
  switch (op) {
    case PrefixOp(:final affix):
      os.type = OpType.prefix;
      os.rawAffix = affix;
      os.affixCtrl.text = display(affix);
    case SuffixOp(:final affix):
      os.type = OpType.suffix;
      os.rawAffix = affix;
      os.affixCtrl.text = display(affix);
    case InfixOp(:final affix, :final position):
      os.type = OpType.infix;
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
      os.templateCtrl.text = pattern;
    case RedupOp(:final scope, :final position):
      os.type = OpType.reduplication;
      os.redupScope = scope;
      os.redupPosition = position;
    case SuppleteOp(:final form):
      os.type = OpType.suppletive;
      os.rawSuppletive = form;
      os.suppletiveCtrl.text = display(form);
    case RemoveSuffixOp():
      return null; // UI skips RemoveSuffixOp
  }
  return os;
}

/// Applies the rom hydration pass to all [BranchState] ops.
///
/// Called once from build() once the romanizationMappingsProvider stream
/// resolves. Guards against re-running via [hydrated] flag.
void hydrateRomDisplay({
  required List<BranchState> branches,
  required String Function(String) romanize,
}) {
  for (final branch in branches) {
    for (final op in branch.ops) {
      if (op.rawAffix != null) op.affixCtrl.text = romanize(op.rawAffix!);
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
}
