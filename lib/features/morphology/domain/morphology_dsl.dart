import 'package:petitparser/petitparser.dart';

// ---------------------------------------------------------------------------
// Operations (atomic morphological transforms)
// ---------------------------------------------------------------------------

sealed class MorphOperation {
  const MorphOperation();
}

class PrefixOp extends MorphOperation {
  const PrefixOp(this.affix);
  final String affix;
}

class SuffixOp extends MorphOperation {
  const SuffixOp(this.affix);
  final String affix;
}

class InfixOp extends MorphOperation {
  const InfixOp({required this.affix, required this.position});
  final String affix;
  final int position; // after Nth consonant (1-based)
}

class AblautOp extends MorphOperation {
  const AblautOp({required this.from, required this.to});
  final String from;
  final String to;
}

class TemplateOp extends MorphOperation {
  const TemplateOp(this.pattern);
  // Digits 1-9 = consonant slots; other chars are literal
  final String pattern;
}

class RedupOp extends MorphOperation {
  const RedupOp({required this.scope, required this.position});
  // scope: "full" | "CV" | "C"
  // position: "prefix" | "suffix"
  final String scope;
  final String position;
}

class SuppleteOp extends MorphOperation {
  const SuppleteOp(this.form);
  final String form;
}

/// Strips a literal suffix from the working form.
///
/// Used in DSL branches like `"o" -o +in` to explicitly remove the matched
/// suffix before applying further operations. The engine also strips the
/// [EndsWithLiteralCond] suffix automatically; this op makes the strip
/// explicit and supports round-trip serialization.
class RemoveSuffixOp extends MorphOperation {
  const RemoveSuffixOp(this.suffix);
  final String suffix;
}

// ---------------------------------------------------------------------------
// Conditions
// ---------------------------------------------------------------------------

sealed class MorphCondition {
  const MorphCondition();
}

class EndsWithLiteralCond extends MorphCondition {
  const EndsWithLiteralCond(this.suffix);
  final String suffix;
}

class StartsWithLiteralCond extends MorphCondition {
  const StartsWithLiteralCond(this.prefix);
  final String prefix;
}

class EndsWithClassCond extends MorphCondition {
  const EndsWithClassCond(this.classRef);
  final String classRef;
}

class StartsWithClassCond extends MorphCondition {
  const StartsWithClassCond(this.classRef);
  final String classRef;
}

// ---------------------------------------------------------------------------
// Branch and Rule
// ---------------------------------------------------------------------------

class MorphBranch {
  const MorphBranch({
    required this.condition,
    required this.operations,
  });
  final MorphCondition? condition; // null = default/else branch
  final List<MorphOperation> operations;
}

class MorphologicalRule {
  const MorphologicalRule({
    required this.id,
    required this.name,
    required this.branches,
    required this.source,
  });
  final int id;
  final String name;
  final List<MorphBranch> branches;
  final String source;
}

// ---------------------------------------------------------------------------
// Parse result
// ---------------------------------------------------------------------------

class ParsedMorphRule {
  const ParsedMorphRule.success({required this.source, required this.rule})
      : error = null;

  const ParsedMorphRule.failure({required this.source, required this.error})
      : rule = null;

  final String source;
  final MorphologicalRule? rule;
  final String? error;

  bool get isValid => error == null;
}

// ---------------------------------------------------------------------------
// DSL Grammar
//
// Grammar (pipe-separated branches; first match wins):
//   rule    := branch ( ' | ' branch )*
//   branch  := cond_spec? op+
//   cond    := '[' classRef '_]'   ends-with-class
//            | '[_' classRef ']'   starts-with-class
//            | '"' lit '"_'        ends-with-literal (trailing underscore)
//            | '_"' lit '"'        starts-with-literal (leading underscore)
//            | '_'                 default (no condition)
//   op      := '+' affix           suffix
//            | affix '+'           prefix  (affix: one or more non-space/non-plus)
//            | '-"' lit '"'        remove trailing literal
//            | '/' from '/' to '/' ablaut
//            | '1' ... (template pattern with digits)
//            | 'redup:scope:pos'   reduplication
//            | '=' '"' form '"'    suppletive
// ---------------------------------------------------------------------------

// Parser builders (lazy initialization via grammar definition)
Parser<MorphCondition?> _buildConditionParser() {
  // [C_] ends-with-class: classRef (no underscore in name) followed by '_]'
  // classRef: letters/digits/hyphens/colons only (no underscore — underscore is sentinel)
  final endsWithClass = (char('[') &
          pattern('a-zA-Z0-9:-').plus().flatten() &
          string('_]'))
      .map((values) => EndsWithClassCond(values[1] as String) as MorphCondition?);

  // [_C] starts-with-class: '_' then classRef inside brackets
  final startsWithClass = (string('[_') &
          pattern('a-zA-Z0-9_:-').plus().flatten() &
          char(']'))
      .map((values) => StartsWithClassCond(values[1] as String) as MorphCondition?);

  // "lit"_ ends-with-literal (quoted literal followed by _)
  final endsWithLitUnderscore = (char('"') &
          pattern('^"').plus().flatten() &
          string('"_'))
      .map((values) => EndsWithLiteralCond(values[1] as String) as MorphCondition?);

  // "lit" ends-with-literal (quoted literal, no trailing underscore)
  // Must be tried after "lit"_ so the underscore form takes priority.
  final endsWithLitBare = (char('"') &
          pattern('^"').plus().flatten() &
          char('"'))
      .map((values) => EndsWithLiteralCond(values[1] as String) as MorphCondition?);

  // _"lit" starts-with-literal
  final startsWithLit = (string('_"') &
          pattern('^"').plus().flatten() &
          char('"'))
      .map((values) => StartsWithLiteralCond(values[1] as String) as MorphCondition?);

  // _ alone = default branch (null condition)
  final defaultCond = char('_').map((_) => null);

  return (endsWithClass |
          startsWithClass |
          endsWithLitUnderscore |
          startsWithLit |
          defaultCond |
          endsWithLitBare)
      .cast<MorphCondition?>();
}

Parser<MorphOperation> _buildOperationParser() {
  // +affix -> SuffixOp
  final suffix = (char('+') & pattern('^ |').plus().flatten())
      .map((values) => SuffixOp(values[1] as String) as MorphOperation);

  // affix+ -> PrefixOp (affix = non-space, non-pipe, non-plus sequence, followed by +)
  final prefix = (pattern('^ |+').plus().flatten() & char('+'))
      .map((values) => PrefixOp(values[0] as String) as MorphOperation);

  // -"lit" -> RemoveSuffixOp (quoted form)
  final removeSuffixQuoted = (string('-"') & pattern('^"').plus().flatten() & char('"'))
      .map((values) => RemoveSuffixOp(values[1] as String) as MorphOperation);

  // -lit -> RemoveSuffixOp (bare form, no quotes; stops at space or pipe)
  // e.g. '-o' in '"o" -o +in' means strip trailing 'o'.
  final removeSuffixBare = (char('-') & pattern('^ |').plus().flatten())
      .map((values) => RemoveSuffixOp(values[1] as String) as MorphOperation);

  // /from/to/ -> AblautOp
  final ablaut = (char('/') &
          pattern('^/').plus().flatten() &
          char('/') &
          pattern('^/').plus().flatten() &
          char('/'))
      .map((values) =>
          AblautOp(from: values[1] as String, to: values[3] as String) as MorphOperation);

  // redup:scope:position -> RedupOp
  final redup = (string('redup:') &
          pattern('^:').plus().flatten() &
          char(':') &
          pattern('^ |').plus().flatten())
      .map((values) =>
          RedupOp(scope: values[1] as String, position: values[3] as String)
              as MorphOperation);

  // ="form" -> SuppleteOp
  final supplete = (string('="') & pattern('^"').plus().flatten() & char('"'))
      .map((values) => SuppleteOp(values[1] as String) as MorphOperation);

  // Template: pattern starting with a digit 1-9, followed by letters/digits
  // e.g. '1a23aa', '1a2b3'
  // Must start with a digit to distinguish from prefix (which ends with +)
  final templateFirst = pattern('1-9');
  final templateRest = pattern('0-9a-zA-Z').star().flatten();
  final template = (templateFirst.flatten() & templateRest)
      .map((values) => TemplateOp((values[0] as String) + (values[1] as String)) as MorphOperation);

  // Order matters: try longer/more-specific patterns first.
  // removeSuffixQuoted before removeSuffixBare (quoted is more specific).
  return (ablaut | redup | supplete | removeSuffixQuoted | removeSuffixBare | suffix | template | prefix)
      .cast<MorphOperation>();
}

Parser<List<MorphOperation>> _buildOpsParser() {
  final op = _buildOperationParser();
  final space = char(' ');
  // Operations separated by spaces
  return (op & (space & op).map((v) => v[1] as MorphOperation).star()).map((values) {
    final first = values[0] as MorphOperation;
    final rest = values[1] as List;
    return [first, ...rest.cast<MorphOperation>()];
  });
}

Parser<MorphBranch> _buildBranchParser() {
  final cond = _buildConditionParser();
  final ops = _buildOpsParser();
  final space = char(' ');

  // Branch with condition: cond space ops
  final branchWithCond = (cond & space & ops).map((values) {
    return MorphBranch(
      condition: values[0] as MorphCondition?,
      operations: (values[2] as List).cast<MorphOperation>(),
    );
  });

  // Branch without condition: just ops
  final branchNoCondOps = ops.map((opsList) {
    return MorphBranch(condition: null, operations: opsList);
  });

  return (branchWithCond | branchNoCondOps).cast<MorphBranch>();
}

/// Parses a morphology DSL string into a [ParsedMorphRule].
///
/// Grammar: branches separated by ' | ' (space-pipe-space).
/// Each branch: optional condition spec + space + operation sequence.
ParsedMorphRule parseMorphDsl(String source, {int id = 0, String name = ''}) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return ParsedMorphRule.failure(source: source, error: 'Rule source is empty');
  }

  // Split into branches on ' | '
  final branchStrings = trimmed.split(' | ');
  final branches = <MorphBranch>[];

  final branchParser = _buildBranchParser().end();

  for (final branchSrc in branchStrings) {
    final result = branchParser.parse(branchSrc.trim());
    switch (result) {
      case Success():
        branches.add(result.value);
      case Failure():
        return ParsedMorphRule.failure(
          source: source,
          error:
              'Parse error in branch "${branchSrc.trim()}": ${result.message} at position ${result.position}',
        );
    }
  }

  if (branches.isEmpty) {
    return ParsedMorphRule.failure(source: source, error: 'No branches parsed');
  }

  return ParsedMorphRule.success(
    source: source,
    rule: MorphologicalRule(
      id: id,
      name: name,
      branches: branches,
      source: source,
    ),
  );
}

// ---------------------------------------------------------------------------
// Serializer
// ---------------------------------------------------------------------------

/// Reconstructs the DSL source string from a [MorphologicalRule].
/// Round-trips correctly with [parseMorphDsl].
String serializeMorphRule(MorphologicalRule rule) {
  final branchParts = rule.branches.map(_serializeBranch).toList();
  return branchParts.join(' | ');
}

String _serializeBranch(MorphBranch branch) {
  final opParts = branch.operations.map(_serializeOp).toList();
  final opStr = opParts.join(' ');

  if (branch.condition == null) {
    // Default branch: just ops (no condition prefix)
    return opStr;
  }

  final condStr = _serializeCondition(branch.condition!);
  return '$condStr $opStr';
}

String _serializeCondition(MorphCondition cond) {
  return switch (cond) {
    EndsWithClassCond(:final classRef) => '[${classRef}_]',
    StartsWithClassCond(:final classRef) => '[_$classRef]',
    EndsWithLiteralCond(:final suffix) => '"$suffix"_',
    StartsWithLiteralCond(:final prefix) => '_"$prefix"',
  };
}

String _serializeOp(MorphOperation op) {
  return switch (op) {
    SuffixOp(:final affix) => '+$affix',
    PrefixOp(:final affix) => '$affix+',
    InfixOp(:final affix, :final position) => 'infix:$affix:$position',
    AblautOp(:final from, :final to) => '/$from/$to/',
    TemplateOp(:final pattern) => pattern,
    RedupOp(:final scope, :final position) => 'redup:$scope:$position',
    SuppleteOp(:final form) => '="$form"',
    RemoveSuffixOp(:final suffix) => '-"$suffix"',
  };
}
