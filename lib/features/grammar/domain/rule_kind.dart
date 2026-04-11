/// Classifies a morphological rule as either inflectional (paradigm-filling,
/// bound to dimension levels) or derivational (word-forming, changes meaning
/// or POS). Introduced in Phase 4 (schema v8). See CONTEXT.md D-17.
enum RuleKind {
  inflectional,
  derivational;

  static RuleKind fromDbString(String raw) {
    switch (raw) {
      case 'inflectional':
        return RuleKind.inflectional;
      case 'derivational':
      default:
        return RuleKind.derivational;
    }
  }

  String get dbString => switch (this) {
        RuleKind.inflectional => 'inflectional',
        RuleKind.derivational => 'derivational',
      };
}
