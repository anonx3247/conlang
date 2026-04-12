/// D-96 — 04-17. A single branch of a standard-form pattern.
///
/// Branches are OR-combined at the pattern level: any branch matching the
/// lexeme's phonemic form satisfies the pattern (see [StandardFormMatcher]).
enum BranchKind { startsWith, endsWith, contains }

/// A single position-anchored phonemic match clause.
///
/// The literal is a phonemic string and may contain class-ref tokens
/// (`V`, `C`, `F`, `[name]`) that expand via the existing
/// [PatternCond] evaluation path in `morphology_dsl.dart` — i.e. the
/// matcher does NOT re-implement class-ref expansion (see D-96).
class StandardFormBranch {
  const StandardFormBranch({required this.kind, required this.literal});

  /// The match anchor kind.
  final BranchKind kind;

  /// Phonemic literal (possibly containing class-ref tokens).
  final String literal;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'literal': literal,
      };

  static StandardFormBranch fromJson(Map<String, dynamic> json) =>
      StandardFormBranch(
        kind: BranchKind.values.firstWhere((k) => k.name == json['kind']),
        literal: json['literal'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StandardFormBranch &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          literal == other.literal;

  @override
  int get hashCode => Object.hash(kind, literal);

  @override
  String toString() => 'StandardFormBranch(${kind.name}, "$literal")';
}
