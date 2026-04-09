import '../../phonology/domain/word_generator.dart';
import 'morphology_dsl.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class MorphResult {
  const MorphResult();
}

class MorphSuccess extends MorphResult {
  const MorphSuccess(this.form);
  final String form;
}

class MorphNoMatch extends MorphResult {
  const MorphNoMatch(this.reason);
  final String reason;
}

// ---------------------------------------------------------------------------
// Engine stub (Task 1 - will be implemented in Task 2)
// ---------------------------------------------------------------------------

class MorphologyEngine {
  const MorphologyEngine();

  /// Applies [rule] to [root] using [inventory] for phoneme class resolution.
  MorphResult applyRule(
    MorphologicalRule rule,
    String root,
    PhonemeInventory inventory,
  ) {
    throw UnimplementedError('MorphologyEngine.applyRule is not yet implemented');
  }
}
