import 'inflectional_rule.dart';
import 'marker.dart';

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

/// The cell was filled successfully. [form] is the phonetic surface form
/// after applying the rule chain AND the rewrite pipeline. [phonemic] is
/// the raw morphological output BEFORE the rewrite pipeline — this is
/// what `romanize()` should consume. [ruleChain] contains each applied
/// rule in application order (most-specific first, then whatever remains
/// after that rule consumed its dimension bindings).
///
/// D-112 (plan 04-17): consumers MUST use [phonemic] as the input to
/// `romanize()` and [form] as the phonetic `[bracket]` display. Passing
/// [form] through `romanize()` leaks sound-change rewrites into the rom
/// line (e.g. `cazana` instead of correct `casana`).
class ParadigmFilled extends ParadigmCell {
  const ParadigmFilled({
    required this.form,
    required this.ruleChain,
    String? phonemic,
  }) : phonemic = phonemic ?? form;

  /// Phonetic surface form (post-rewrite-pipeline). Use for `[bracket]`
  /// display. When no rewrite rules are configured, equals [phonemic].
  final String form;

  /// Raw morphological output (pre-rewrite-pipeline). Use as input to
  /// `romanize()` for the rom display line. D-112 invariant.
  final String phonemic;

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

/// The cell resolves to an unmarked (zero-morpheme) form — the root itself
/// IS the form (Phase 4 gap D-47 render spec, plan 04-10).
///
/// Returned by [computeParadigmCell] when the D-45 resolution order reaches
/// step 3: the rule chain produced no output, but a [MarkerDecl] declared
/// on the POS matches the target feature set. The [root] field holds the
/// bare (uninflected) root form; the [source] field holds the winning
/// marker for downstream click-to-edit UI.
///
/// Rendered distinctly from:
///   - [ParadigmFilled] — a non-trivial form (rom + IPA two-line layout)
///   - [ParadigmUncovered] — em-dash `—` (no rule AND no marker matched)
///
/// Per D-46, rules beat markers on exact ties: if both a rule and a marker
/// match at the same specificity on the same binding dims, the engine
/// returns [ParadigmFilled] (the rule's output), not [ParadigmUnmarked].
class ParadigmUnmarked extends ParadigmCell {
  const ParadigmUnmarked({required this.root, required this.source});

  /// The bare root form — rendered as the cell text in muted gray.
  final String root;

  /// The marker declaration that matched. Held so the paradigm widget can
  /// open a "Marker" editor when the cell is clicked (plan 04-13 wires the
  /// click flow).
  final MarkerDecl source;
}
