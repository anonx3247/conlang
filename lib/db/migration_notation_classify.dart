// Plan 04-15 D-74: DSL-parse-aware classify helper for the v9→v10 migration.
//
// This library is the single source of truth for the notation migration
// classify logic. It parses rule sources via parseMorphDsl, walks the op
// tree, rewrites ONLY single-token phonological literals (ablaut FROM/TO,
// affixes, remove-suffix literals), leaves structural tokens untouched
// (ablaut flags, template directives, class refs, condition patterns,
// remove-suffix is NOT a structural token — it IS a literal), and
// serializes back via serializeMorphRule.
//
// Why this file exists — lesson from a dropped first attempt:
//
// A naive string-level approach ran dotAwareDeromanize on the raw serialized
// DSL source. That approach silently corrupted ablaut flag segments: a flag
// like `e1` (fromEnd, count=1) contains ASCII letter `e`, which under a
// mapping `e → ε` got rewritten to `ε1`, and the ablaut flag parser's
// `flags.startsWith('e')` check then returned false for the non-ASCII `ε`,
// silently flipping direction from fromEnd to fromStart. Template directives,
// remove-suffix bare forms, and condition wrappers were similarly vulnerable.
//
// The fix is DSL-parse-aware classify: go through parseMorphDsl, rebuild the
// op tree with rewritten literal fields only, serialize back. Structural
// tokens flow through the parser's grammar rules and are never touched by
// dotAwareDeromanize/smartRomanize.
//
// Public API:
// - [ClassifyOutcome] — classification result + new source if rewritten.
// - [classifyAndRewriteRuleSource] — entry point for app_database.dart.
// - [classifySingleLiteral] — exposed for unit tests.
//
// See `.planning/phases/04-grammar-morphology-revised/04-15-PLAN.md` Task 3
// and `04-15-CONTEXT.md` §D-74 + §D-78 for the decision record.

import '../features/morphology/domain/morphology_dsl.dart';
import '../features/phonology/domain/notation_helpers.dart';

/// Why a rule source was (or was not) rewritten during the v9→v10 classify
/// pass. The migration_log JSON persisted to project_settings uses these
/// exact string values.
class ClassifyOutcome {
  final bool rewrote;
  final String? newSource;
  final String reason;

  const ClassifyOutcome._({
    required this.rewrote,
    required this.reason,
    this.newSource,
  });

  factory ClassifyOutcome.rewritten(String newSource) =>
      ClassifyOutcome._(rewrote: true, reason: 'rewritten', newSource: newSource);

  factory ClassifyOutcome.leftAloneEmpty() =>
      const ClassifyOutcome._(rewrote: false, reason: 'left_alone_empty');

  factory ClassifyOutcome.leftAloneUnparseable() =>
      const ClassifyOutcome._(rewrote: false, reason: 'left_alone_unparseable');

  factory ClassifyOutcome.leftAlonePhonemic() =>
      const ClassifyOutcome._(rewrote: false, reason: 'left_alone_phonemic');
}

/// Apply the D-74 round-trip classify to a single literal token (an affix
/// string, an ablaut FROM/TO value, or a remove-suffix literal). Returns the
/// phonemic form if the token is rom input that round-trips via
/// `dotAwareDeromanize` → `smartRomanize`, otherwise the token unchanged.
///
/// Class-ref tokens pass through unchanged:
/// - A single uppercase ASCII letter (V, C, F, N, …).
/// - A bracket-wrapped natural class name (`[nasal]`, `[stop]`, …).
/// - Empty strings.
String classifySingleLiteral(
  String literal,
  List<NotationMapping> mappings,
) {
  if (literal.isEmpty) return literal;

  // Class-ref passthrough: single uppercase ASCII letter.
  if (literal.length == 1) {
    final code = literal.codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) return literal; // 'A'-'Z'
  }

  // Class-ref passthrough: bracket-wrapped name.
  if (literal.startsWith('[') && literal.endsWith(']')) return literal;

  final phonemic = dotAwareDeromanize(literal, mappings);
  final roundTrip = smartRomanize(phonemic, mappings);
  if (roundTrip == literal && phonemic != literal) {
    return phonemic; // Rom input — rewrite.
  }
  return literal; // Already phonemic, or non-round-trip.
}

/// DSL-parse-aware classify for a rule [source] string. Returns a
/// [ClassifyOutcome] describing whether the source was rewritten and what
/// the new value is.
///
/// Algorithm (see Task 3 Subtask 3a in 04-15-PLAN.md for full details):
///
/// 1. Empty source → `left_alone_empty`.
/// 2. `parseMorphDsl` fails → `left_alone_unparseable` (never mutate
///    something we can't parse).
/// 3. Walk every branch's op list and rewrite ONLY single-token phonological
///    literal fields via `classifySingleLiteral`:
///    - AblautOp: .from, .to
///    - SuffixOp: .affix
///    - PrefixOp: .affix
///    - RemoveSuffixOp: .suffix
///    InfixOp, TemplateOp, RedupOp, SuppleteOp are left untouched (WARN-1
///    partial-scope deferral).
/// 4. Conditions are NOT rewritten (WARN-1 condition deferral).
/// 5. Track whether ANY literal was actually changed by
///    `classifySingleLiteral`. If no literal changed → `left_alone_phonemic`
///    and leave the original source string untouched. This is critical:
///    parse→serialize is not a byte-preserving round-trip (the serializer
///    normalizes `-s` to `-"s"`, among others), so comparing serialized ==
///    source would falsely report rewrites for normalization-only changes.
/// 6. If a literal changed → serialize the rebuilt rule via
///    `serializeMorphRule` and return `rewritten` with that new source.
ClassifyOutcome classifyAndRewriteRuleSource(
  String source,
  List<NotationMapping> mappings,
) {
  if (source.isEmpty) return ClassifyOutcome.leftAloneEmpty();

  final parsed = parseMorphDsl(source);
  if (!parsed.isValid || parsed.rule == null) {
    return ClassifyOutcome.leftAloneUnparseable();
  }

  final rule = parsed.rule!;
  var anyLiteralChanged = false;
  final newBranches = <MorphBranch>[];
  for (final branch in rule.branches) {
    final newOps = <MorphOperation>[];
    for (final op in branch.operations) {
      final rewritten = _rewriteOp(op, mappings);
      if (!identical(rewritten, op)) {
        anyLiteralChanged = true;
      }
      newOps.add(rewritten);
    }
    // Conditions are left untouched — WARN-1 deferral scope.
    newBranches.add(MorphBranch(
      conditions: branch.conditions,
      operations: newOps,
    ));
  }

  if (!anyLiteralChanged) {
    // Parse→serialize can normalize the source (e.g. `-s` → `-"s"`). We
    // must NOT report this as a rewrite — only true phonological literal
    // rewrites count. Return the original source untouched.
    return ClassifyOutcome.leftAlonePhonemic();
  }

  final newRule = MorphologicalRule(
    id: rule.id,
    name: rule.name,
    branches: newBranches,
    source: source,
  );

  final serialized = serializeMorphRule(newRule);
  return ClassifyOutcome.rewritten(serialized);
}

/// Rewrite a single [MorphOperation] by applying [classifySingleLiteral] to
/// each phonological literal field. Returns the ORIGINAL [op] instance
/// (via `identical`) when no literal actually changed, so the caller can
/// detect normalization-only passes and skip them.
MorphOperation _rewriteOp(
  MorphOperation op,
  List<NotationMapping> mappings,
) {
  return switch (op) {
    SuffixOp(:final affix) => () {
        final newAffix = classifySingleLiteral(affix, mappings);
        return newAffix == affix ? op : SuffixOp(newAffix);
      }(),
    PrefixOp(:final affix) => () {
        final newAffix = classifySingleLiteral(affix, mappings);
        return newAffix == affix ? op : PrefixOp(newAffix);
      }(),
    AblautOp(:final from, :final to, :final count, :final direction) => () {
        final newFrom = classifySingleLiteral(from, mappings);
        final newTo = classifySingleLiteral(to, mappings);
        if (newFrom == from && newTo == to) return op;
        return AblautOp(
          from: newFrom,
          to: newTo,
          count: count,
          direction: direction,
        );
      }(),
    RemoveSuffixOp(:final suffix) => () {
        final newSuffix = classifySingleLiteral(suffix, mappings);
        return newSuffix == suffix ? op : RemoveSuffixOp(newSuffix);
      }(),
    // Structural ops — WARN-1 deferral scope, left untouched.
    InfixOp() => op,
    TemplateOp() => op,
    RedupOp() => op,
    SuppleteOp() => op,
  };
}
