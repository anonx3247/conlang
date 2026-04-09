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

enum AblautDirection { fromStart, fromEnd }

class AblautOp extends MorphOperation {
  const AblautOp({
    required this.from,
    required this.to,
    this.count,
    this.direction = AblautDirection.fromStart,
  });
  final String from;
  final String to;
  /// Number of occurrences to replace. Null = replace all.
  final int? count;
  /// Which direction to count replacements from.
  final AblautDirection direction;
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
/// Used in DSL branches like `{o_} -o +in` to explicitly remove the matched
/// suffix before applying further operations.
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

/// Position for condition matching.
enum CondPosition { startsWith, endsWith, contains }

/// Pattern-based condition using phonological notation.
///
/// Pattern elements:
/// - `[className]` — matches any phoneme in the named natural class
/// - Single uppercase letter: `C` = any consonant, `V` = any vowel
/// - Lowercase letters: literal phoneme match (e.g. `k`, `na`)
/// - `(group)` — optional group (matches zero or one occurrence)
///
/// The [position] field determines where in the word the pattern must match:
/// - `startsWith` — pattern must match at the beginning of the word
/// - `endsWith` — pattern must match at the end of the word
/// - `contains` — pattern can match anywhere in the word
///
/// Examples:
/// - `[nasal]V` with endsWith — ends with nasal + vowel
/// - `CV` with startsWith — starts with consonant + vowel
/// - `[stop][stop]` with contains — has two consecutive stops anywhere
class PatternCond extends MorphCondition {
  const PatternCond(this.pattern, {this.position = CondPosition.contains});
  final String pattern; // Raw pattern string (no anchors)
  final CondPosition position;
}

// ---------------------------------------------------------------------------
// Branch and Rule
// ---------------------------------------------------------------------------

class MorphBranch {
  const MorphBranch({
    required this.conditions,
    required this.operations,
  });
  /// Empty list = default/else branch (always matches).
  /// Non-empty = all conditions must match (AND logic).
  final List<MorphCondition> conditions;
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
//   branch  := cond_spec* op+
//   cond    := '{' pattern '}'       new pattern-based condition
//            | '[' classRef '_]'     old ends-with-class (migration)
//            | '[_' classRef ']'     old starts-with-class (migration)
//            | '"' lit '"_'          old ends-with-literal (migration)
//            | '_"' lit '"'          old starts-with-literal (migration)
//            | '_'                   default (no condition)
//   op      := '+' affix             suffix
//            | affix '+'             prefix
//            | '-"' lit '"'          remove trailing literal (quoted)
//            | '-' lit               remove trailing literal (bare)
//            | '/' from '/' to '/'   ablaut
//            | 'redup:scope:pos'     reduplication
//            | 'infix:affix:pos'     infix
//            | '=' '"' form '"'      suppletive
// ---------------------------------------------------------------------------

// Parser builders (lazy initialization via grammar definition)

/// Parses a single condition token. Returns a [PatternCond] or null for
/// the bare `_` default marker.
Parser<MorphCondition?> _buildSingleConditionParser() {
  // New format: ^"pattern" = startsWith, "pattern"$ = endsWith, ~"pattern" = contains
  final startsWithNew = (string('^"') &
          pattern(r'^"').plus().flatten() &
          char('"'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.startsWith) as MorphCondition?);

  final endsWithNew = (char('"') &
          pattern(r'^"').plus().flatten() &
          string(r'"$'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.endsWith) as MorphCondition?);

  final containsNew = (string('~"') &
          pattern(r'^"').plus().flatten() &
          char('"'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.contains) as MorphCondition?);

  // Migration: {pattern} -> PatternCond with position inferred from _ anchors
  final legacyPattern = (char('{') &
          pattern(r'^}').plus().flatten() &
          char('}'))
      .map((values) {
    final raw = values[1] as String;
    return _migratePatternAnchors(raw) as MorphCondition?;
  });

  // Migration: [C_] ends-with-class
  final endsWithClass = (char('[') &
          pattern('a-zA-Z0-9:-').plus().flatten() &
          string('_]'))
      .map((values) => PatternCond('[${values[1]}]',
          position: CondPosition.endsWith) as MorphCondition?);

  // Migration: [_C] starts-with-class
  final startsWithClass = (string('[_') &
          pattern('a-zA-Z0-9_:-').plus().flatten() &
          char(']'))
      .map((values) => PatternCond('[${values[1]}]',
          position: CondPosition.startsWith) as MorphCondition?);

  // Migration: "lit"_ ends-with-literal
  final endsWithLitUnderscore = (char('"') &
          pattern('^"').plus().flatten() &
          string('"_'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.endsWith) as MorphCondition?);

  // Migration: _"lit" starts-with-literal
  final startsWithLit = (string('_"') &
          pattern('^"').plus().flatten() &
          char('"'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.startsWith) as MorphCondition?);

  // Migration: "lit" ends-with-literal bare (no trailing _)
  final endsWithLitBare = (char('"') &
          pattern('^"').plus().flatten() &
          char('"'))
      .map((values) => PatternCond(values[1] as String,
          position: CondPosition.endsWith) as MorphCondition?);

  // _ alone = default branch (null condition)
  final defaultCond = char('_').map((_) => null);

  // New formats first, then legacy, then migration forms, then default.
  return (startsWithNew |
          containsNew |
          legacyPattern |
          endsWithClass |
          startsWithClass |
          endsWithLitUnderscore |
          startsWithLit |
          defaultCond |
          endsWithNew |
          endsWithLitBare)
      .cast<MorphCondition?>();
}

/// Migrates old anchor-based pattern strings (with `_`) to [PatternCond]
/// with explicit [CondPosition].
PatternCond _migratePatternAnchors(String raw) {
  final hasStart = raw.startsWith('_');
  final hasEnd = raw.endsWith('_');
  var clean = raw;
  if (hasStart) clean = clean.substring(1);
  if (hasEnd) clean = clean.substring(0, clean.length - 1);

  if (hasStart && hasEnd) {
    // Both anchors = treat as contains (whole word match is rare)
    return PatternCond(clean, position: CondPosition.contains);
  } else if (hasStart) {
    return PatternCond(clean, position: CondPosition.startsWith);
  } else if (hasEnd) {
    return PatternCond(clean, position: CondPosition.endsWith);
  } else {
    return PatternCond(clean, position: CondPosition.contains);
  }
}

/// Parses zero or more condition tokens followed by a space.
/// Returns a list of [MorphCondition] (empty = default branch).
Parser<List<MorphCondition>> _buildConditionsParser() {
  final singleCond = _buildSingleConditionParser();
  final space = char(' ');

  // Multiple adjacent {pattern} tokens = AND conditions.
  // Each condition is followed by a space when more conditions follow or
  // when operations follow. We parse: (cond space)+ then peek for ops.
  //
  // Strategy: parse one or more (cond space) groups as the condition prefix.
  // The last space before ops is consumed here.
  //
  // For default `_` form: just `_ ` = one null condition (empty list).
  final condWithSpace = (singleCond & space).map((v) => v[0] as MorphCondition?);

  return condWithSpace.plus().map((list) {
    // Filter out nulls (default `_`) — they contribute nothing to the list.
    // If we parsed `_ `, the list has one null → conditions = [] (default).
    final filtered = list.cast<MorphCondition?>()
        .whereType<MorphCondition>()
        .toList();
    return filtered;
  });
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
  final removeSuffixBare = (char('-') & pattern('^ |').plus().flatten())
      .map((values) => RemoveSuffixOp(values[1] as String) as MorphOperation);

  // /from/to/ or /from/to/flags -> AblautOp
  // flags: s=fromStart, e=fromEnd; followed by digit=count or A=all
  // Empty flags or missing = all from start (backward compatible)
  final ablaut = (char('/') &
          pattern('^/').plus().flatten() &
          char('/') &
          pattern('^/').star().flatten() &
          char('/') &
          pattern('^ |').star().flatten())
      .map((values) {
    final from = values[1] as String;
    final to = values[3] as String;
    final flags = values[5] as String;
    AblautDirection direction = AblautDirection.fromStart;
    int? count; // null = all
    if (flags.isNotEmpty) {
      if (flags.startsWith('e')) {
        direction = AblautDirection.fromEnd;
      }
      final countStr = flags.substring(1);
      if (countStr.isNotEmpty && countStr != 'A') {
        count = int.tryParse(countStr);
      }
    }
    return AblautOp(from: from, to: to, count: count, direction: direction)
        as MorphOperation;
  });

  // redup:scope:position -> RedupOp
  final redup = (string('redup:') &
          pattern('^:').plus().flatten() &
          char(':') &
          pattern('^ |').plus().flatten())
      .map((values) =>
          RedupOp(scope: values[1] as String, position: values[3] as String)
              as MorphOperation);

  // infix:affix:position -> InfixOp
  final infix = (string('infix:') &
          pattern('^ |:').plus().flatten() &
          char(':') &
          pattern('0-9').plus().flatten())
      .map((values) =>
          InfixOp(affix: values[1] as String, position: int.parse(values[3] as String))
              as MorphOperation);

  // ="form" -> SuppleteOp
  final supplete = (string('="') & pattern('^"').plus().flatten() & char('"'))
      .map((values) => SuppleteOp(values[1] as String) as MorphOperation);

  // Template: pattern starting with a digit 1-9, followed by letters/digits
  final templateFirst = pattern('1-9');
  final templateRest = pattern('0-9a-zA-Z').star().flatten();
  final template = (templateFirst.flatten() & templateRest)
      .map((values) => TemplateOp((values[0] as String) + (values[1] as String)) as MorphOperation);

  return (ablaut | redup | infix | supplete | removeSuffixQuoted | removeSuffixBare | suffix | template | prefix)
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
  final conditions = _buildConditionsParser();
  final ops = _buildOpsParser();

  // Branch with condition(s): conditions ops
  // Note: _buildConditionsParser already consumes the trailing space before ops.
  final branchWithCond = (conditions & ops).map((values) {
    return MorphBranch(
      conditions: (values[0] as List).cast<MorphCondition>(),
      operations: (values[1] as List).cast<MorphOperation>(),
    );
  });

  // Branch without condition: just ops (pure default)
  final branchNoCondOps = ops.map((opsList) {
    return MorphBranch(conditions: const [], operations: opsList);
  });

  return (branchWithCond | branchNoCondOps).cast<MorphBranch>();
}

/// Parses a morphology DSL string into a [ParsedMorphRule].
///
/// Grammar: branches separated by ' | ' (space-pipe-space).
/// Each branch: optional condition spec(s) + space + operation sequence.
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

  if (branch.conditions.isEmpty) {
    // Default branch: just ops (no condition prefix)
    return opStr;
  }

  final condStr = branch.conditions.map(_serializeCondition).join('');
  return '$condStr $opStr';
}

String _serializeCondition(MorphCondition cond) {
  return switch (cond) {
    PatternCond(:final pattern, :final position) => switch (position) {
        CondPosition.startsWith => '^"$pattern"',
        CondPosition.endsWith => '"$pattern"\$',
        CondPosition.contains => '~"$pattern"',
      },
  };
}

String _serializeOp(MorphOperation op) {
  return switch (op) {
    SuffixOp(:final affix) => '+$affix',
    PrefixOp(:final affix) => '$affix+',
    InfixOp(:final affix, :final position) => 'infix:$affix:$position',
    AblautOp(:final from, :final to, :final count, :final direction) => () {
        final dirChar = direction == AblautDirection.fromEnd ? 'e' : 's';
        final countStr = count == null ? 'A' : '$count';
        final flags = '$dirChar$countStr';
        // Omit flags if default (all from start) for backward compat
        if (direction == AblautDirection.fromStart && count == null) {
          return '/$from/$to/';
        }
        return '/$from/$to/$flags';
      }(),
    TemplateOp(:final pattern) => pattern,
    RedupOp(:final scope, :final position) => 'redup:$scope:$position',
    SuppleteOp(:final form) => '="$form"',
    RemoveSuffixOp(:final suffix) => '-"$suffix"',
  };
}
