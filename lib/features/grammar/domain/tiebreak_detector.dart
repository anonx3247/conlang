import 'inflectional_rule.dart';

/// A group of inflectional rules whose binding maps are identical. Any
/// paradigm cell that matches one would also match all of the others, so
/// they always tie. The rule editor surfaces these as a live banner so the
/// user can resolve them before relying on the paradigm engine (D-12).
class TiebreakConflict {
  const TiebreakConflict({required this.bindingKey, required this.rules});

  /// Stable string representation of the shared binding map, e.g. `"10:1,11:1"`.
  /// Useful as a React-key-style identifier for the banner UI.
  final String bindingKey;

  /// The rules that share this binding map. Always length >= 2.
  final List<InflectionalRule> rules;
}

/// Finds all groups of 2+ active inflectional rules with identical binding
/// maps. Inactive rules and derivational rules (empty bindings) are
/// excluded — only rules that could actually fire on a paradigm cell are
/// eligible for conflict detection.
///
/// Rules with different POS scopes are still flagged if their dimension
/// bindings are identical: POS filtering happens upstream (the rule editor
/// passes an already-POS-scoped list), and the engine's ambiguity rule
/// (D-12) only looks at dims. A follow-up plan (04-04 rule editor) can
/// layer POS filtering on top of this detector if the live banner needs
/// cross-POS visibility.
List<TiebreakConflict> findDuplicateSpecificityConflicts(
  List<InflectionalRule> rules,
) {
  final byKey = <String, List<InflectionalRule>>{};
  for (final rule in rules) {
    if (!rule.isActive) continue;
    if (rule.bindings.isDerivational) continue;
    final key = _bindingKey(rule.bindings.dims);
    byKey.putIfAbsent(key, () => []).add(rule);
  }
  return byKey.entries
      .where((e) => e.value.length > 1)
      .map((e) => TiebreakConflict(bindingKey: e.key, rules: e.value))
      .toList();
}

String _bindingKey(Map<int, int> dims) {
  final entries = dims.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}
