import '../../morphology/domain/morphology_dsl.dart'
    show PatternCond, CondPosition;
import '../../morphology/domain/morphology_engine.dart'
    show patternConditionMatches;
import '../../phonology/domain/word_generator.dart' show PhonemeInventory;
import 'standard_form_branch.dart';

/// D-96 -- 04-17. Matches a lexeme's phonemic form against a list of
/// standard-form branches. Branches are OR-combined. Each branch reuses
/// the existing [PatternCond] evaluation path from the morphology engine
/// -- class refs (V, C, F, [name]) are expanded structurally via the
/// same code path that already works for inflection rules.
class StandardFormMatcher {
  const StandardFormMatcher();

  /// Returns true iff any branch matches the phonemic form.
  /// Empty branch list trivially matches (no constraint).
  bool matches(
    String phonemicForm,
    List<StandardFormBranch> branches,
    PhonemeInventory inventory,
  ) {
    if (branches.isEmpty) return true;
    for (final branch in branches) {
      final cond = PatternCond(
        branch.literal,
        position: _mapKind(branch.kind),
      );
      if (patternConditionMatches(cond, phonemicForm, inventory)) {
        return true;
      }
    }
    return false;
  }

  static CondPosition _mapKind(BranchKind kind) {
    switch (kind) {
      case BranchKind.startsWith:
        return CondPosition.startsWith;
      case BranchKind.endsWith:
        return CondPosition.endsWith;
      case BranchKind.contains:
        return CondPosition.contains;
    }
  }
}
