/// Parity check: pre-unification state
///
/// Pre-existing level-deletion check in dimension_editor_panel.dart prior to
/// the 04-17 Task 3 unification — captured here so the unified helper in
/// GrammarDao.checkLevelDeletionDependencies can be audited for behavioral
/// parity against the older implementation.
///
/// `grep -n "featureBindings\|ruleUsage\|_checkLevelInUse\|_levelInUseBy" lib/features/grammar/presentation/pos_dimensions/dimension_editor_panel.dart`
///
/// Pre-unification result (Task 3 baseline): NO MATCHES. The pre-existing
/// onDeleted callback at lines 289-296 called GrammarDao.updateDimensionLevels
/// directly without checking any references — rule featureBindings references
/// to the deleted level were silently stranded, and no dialog surfaced. The
/// unified helper is therefore STRICTLY SAFER than the pre-existing check: it
/// blocks deletion when any dependency exists (rules, lexemes, patterns) and
/// forces a reassign. This file lives next to the helper so the invariant is
/// discoverable during audits.
///
/// D-86 — 04-17. Structured report of cross-table references to a
/// `(dimensionId, levelId)` pair. Produced by
/// [GrammarDao.checkLevelDeletionDependencies] and consumed by the reassign
/// dialog in `dimension_editor_panel.dart`.
class LevelDeletionReport {
  const LevelDeletionReport({
    required this.lexemeCount,
    required this.patternCount,
    required this.ruleCount,
    required this.ruleNames,
    required this.lexemeIds,
  });

  /// Number of [Lexemes] rows whose [IntrinsicLevelsCodec.decode]d map has
  /// `dimId -> levelId`.
  final int lexemeCount;

  /// Number of [StandardFormPatterns] rows with matching (dim, level) PK.
  final int patternCount;

  /// Number of [MorphologicalRules] rows whose [FeatureBindings.dims]
  /// contains `dimId -> levelId`.
  final int ruleCount;

  /// Human-readable rule names for display in the reassign dialog. Same
  /// length as [ruleCount] (may be truncated for very large lists, but
  /// not in the current implementation).
  final List<String> ruleNames;

  /// Lexeme ids affected. Same length as [lexemeCount].
  final List<int> lexemeIds;

  /// True when any dependency exists — deletion should trigger the
  /// reassign dialog instead of proceeding directly.
  bool get isBlocking => lexemeCount > 0 || patternCount > 0 || ruleCount > 0;

  /// Total number of cross-table references. Used for summary copy in
  /// the reassign dialog: `"N references will be updated"`.
  int get total => lexemeCount + patternCount + ruleCount;
}
