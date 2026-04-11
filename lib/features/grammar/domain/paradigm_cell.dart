import 'inflectional_rule.dart';

/// Result of computing a single paradigm cell via the feature-consumption
/// algorithm (Phase 4 CONTEXT.md D-10).
///
/// This is a sealed hierarchy so callers must handle every case — there is
/// no fall-back default. Callers typically switch on the concrete subtype
/// to render either the surface form ([ParadigmFilled]), a "no rule"
/// placeholder ([ParadigmUncovered]), or a conflict banner
/// ([ParadigmAmbiguous]).
sealed class ParadigmCell {
  const ParadigmCell();
}

/// The cell was filled successfully. [form] is the final surface form after
/// applying the rule chain in order. [ruleChain] contains each applied rule
/// in application order (most-specific first, then whatever remains after
/// that rule consumed its dimension bindings).
class ParadigmFilled extends ParadigmCell {
  const ParadigmFilled({required this.form, required this.ruleChain});

  final String form;
  final List<InflectionalRule> ruleChain;
}

/// No rule (or combination of rules) covers the target feature set.
///
/// [failureReason] is a human-readable string useful for tooltips and the
/// rule-editor conflict banner (e.g. "No inflectional rule binds
/// {number=PL}" or "Rule '-is' matched but its DSL condition failed on
/// 'kat'").
class ParadigmUncovered extends ParadigmCell {
  const ParadigmUncovered([this.failureReason]);

  final String? failureReason;
}

/// Two or more rules have the same (maximum) specificity AND identical
/// binding sets, so both match the remaining feature set. The user must
/// resolve the conflict manually (D-12 — explicit error, no silent tie
/// breaking).
class ParadigmAmbiguous extends ParadigmCell {
  const ParadigmAmbiguous(this.tiedRules);

  final List<InflectionalRule> tiedRules;
}
