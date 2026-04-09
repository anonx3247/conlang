// ignore_for_file: unused_field

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
// Parser stub (Task 1 - will be implemented in Task 2)
// ---------------------------------------------------------------------------

/// Parses a morphology DSL string into a [ParsedMorphRule].
ParsedMorphRule parseMorphDsl(String source) {
  return ParsedMorphRule.failure(
    source: source,
    error: 'Not implemented',
  );
}

/// Serializes a [MorphologicalRule] back to its DSL source string.
String serializeMorphRule(MorphologicalRule rule) {
  return '';
}
