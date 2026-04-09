import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../phonology/data/phonotactic_providers.dart';
import '../../phonology/domain/word_generator.dart';

/// Provides a function to validate any word against the current project's
/// phonotactic constraints.
///
/// Usage:
/// ```dart
/// final validate = ref.watch(phonotacticValidatorProvider);
/// final result = validate(word: 'some IPA');
/// if (!result.isValid) {
///   // show ViolationText widget
/// }
/// ```
///
/// The returned function is stable as long as constraints and inventory
/// don't change. It can be used in the lexicon detail panel, morphology
/// preview, and any text field to check violation status (PHON-05).
final phonotacticValidatorProvider =
    Provider<ValidationResult Function({required String word})>((ref) {
  final constraints = ref.watch(parsedConstraintsProvider).asData?.value ?? [];
  final inventory = ref.watch(phonemeInventoryProvider);
  final generator = WordGenerator();

  return ({required String word}) => generator.validateWord(
        word: word,
        constraints: constraints,
        inventory: inventory,
      );
});
