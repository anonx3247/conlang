/// Classifies a morphological rule as inflectional (paradigm-filling, bound
/// to dimension levels), derivational (word-forming, changes meaning or POS),
/// or construction (UI routing value — routes to the separate
/// ConstructionRules table; construction rules do not live in
/// MorphologicalRules). Introduced in Phase 4 (schema v8), extended in
/// Phase 10.1. See CONTEXT.md D-17.
///
/// NOTE: [RuleKind.construction] is a UI routing value only. Construction
/// rules live in the separate `construction_rules` table, not in
/// `morphological_rules`.
enum RuleKind {
  inflectional,
  derivational,
  construction;

  static RuleKind fromDbString(String raw) {
    switch (raw) {
      case 'inflectional':
        return RuleKind.inflectional;
      case 'construction':
        return RuleKind.construction;
      case 'derivational':
      default:
        return RuleKind.derivational;
    }
  }

  String get dbString => switch (this) {
        RuleKind.inflectional => 'inflectional',
        RuleKind.derivational => 'derivational',
        RuleKind.construction => 'construction',
      };
}
