import 'dart:convert';

import 'feature_bindings.dart';

/// A token in an assembled construction output.
///
/// Sealed hierarchy with two subtypes:
/// - [ParticleToken] — a closed-class word or affix slot (gloss_tag value)
/// - [WordSlotToken] — the open-class word slot form after resolution
///
/// D-112 invariant: [WordSlotToken.phonemic] is always the pre-rewrite form
/// for `romanize()`, while [WordSlotToken.ipa] is the post-rewrite phonetic
/// form for `[bracket]` display.
sealed class ConstructionToken {
  const ConstructionToken();
}

/// A particle (closed-class word or gloss-tag slot) in a construction.
///
/// [ipa] is the phonetic surface form (post-rewrite) for bracket display.
/// [romanization] is the romanized form, if available.
class ParticleToken extends ConstructionToken {
  const ParticleToken({required this.ipa, this.romanization});

  final String ipa;
  final String? romanization;

  @override
  String toString() => 'ParticleToken($ipa)';
}

/// The word slot in a construction — the resolved form of the open-class
/// word at the designated slot position.
///
/// [ipa] is the phonetic surface form (post-rewrite). Use for `[bracket]`
/// display. D-112 invariant.
/// [phonemic] is the pre-rewrite morphological output. Use as input to
/// `romanize()`. D-112 invariant.
class WordSlotToken extends ConstructionToken {
  const WordSlotToken({required this.ipa, required this.phonemic});

  /// Phonetic surface form (post-rewrite pipeline). Use for `[bracket]` display.
  final String ipa;

  /// Raw morphological output (pre-rewrite pipeline). Use as input to
  /// `romanize()`.
  final String phonemic;

  @override
  String toString() => 'WordSlotToken($ipa/$phonemic)';
}

// ---------------------------------------------------------------------------
// FormReference
// ---------------------------------------------------------------------------

/// Describes how the word slot in a construction resolves to a form.
///
/// Two subtypes:
/// - [BaseFormReference] — resolve to the uninflected base/root form (D-06a)
/// - [CellFormReference] — resolve to another paradigm cell's output (D-06b)
sealed class FormReference {
  const FormReference();

  /// Parse [json] from the `form_reference_json` DB column.
  ///
  /// - `null`, `'null'`, or malformed JSON → [BaseFormReference] (safe default).
  /// - `{"kind":"cell","featureSet":{"dimId":levelId,...}}` → [CellFormReference].
  ///
  /// T-10.1-01 mitigation: malformed or unexpected JSON returns
  /// [BaseFormReference], never throws.
  factory FormReference.fromJson(String? json) {
    if (json == null || json == 'null' || json.isEmpty) {
      return const BaseFormReference();
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return const BaseFormReference();
      final kind = decoded['kind'];
      if (kind == 'cell') {
        final raw = decoded['featureSet'];
        if (raw is! Map) return const BaseFormReference();
        final featureSet = <int, int>{};
        for (final entry in raw.entries) {
          final dimId = int.tryParse(entry.key.toString());
          final levelId = entry.value;
          if (dimId != null && levelId is int) {
            featureSet[dimId] = levelId;
          }
        }
        return CellFormReference(targetFeatureSet: featureSet);
      }
      return const BaseFormReference();
    } catch (_) {
      // T-10.1-01: defensive — never crash on malformed JSON.
      return const BaseFormReference();
    }
  }

  /// Serialize to JSON string for DB storage.
  String toJson();
}

/// Word slot resolves to the uninflected base/root form (D-06 option a).
class BaseFormReference extends FormReference {
  const BaseFormReference();

  @override
  String toJson() => 'null';

  @override
  String toString() => 'BaseFormReference()';
}

/// Word slot resolves to another paradigm cell identified by
/// [targetFeatureSet] (D-06 option b).
///
/// [targetFeatureSet] maps dimension ids to level ids — the same
/// [FeatureSet] type used by the paradigm engine.
class CellFormReference extends FormReference {
  const CellFormReference({required this.targetFeatureSet});

  /// The feature set identifying the target paradigm cell.
  /// Keys are dimension ids; values are level ids within that dimension.
  final Map<int, int> targetFeatureSet;

  @override
  String toJson() => jsonEncode({
        'kind': 'cell',
        'featureSet': {
          for (final e in targetFeatureSet.entries) e.key.toString(): e.value,
        },
      });

  @override
  String toString() => 'CellFormReference($targetFeatureSet)';
}

// ---------------------------------------------------------------------------
// ConstructionRule
// ---------------------------------------------------------------------------

/// Domain model wrapping a [ConstructionRuleRow] (Drift DB row) with its
/// feature bindings already parsed, suitable for paradigm engine use.
///
/// [bindings] reuses [FeatureBindings] verbatim (D-01): the same
/// specificity-based matching logic from the inflectional rule engine
/// applies to construction rules.
///
/// Only construct via [ConstructionRule.fromDbRow] after loading the row
/// from [ConstructionRuleDao].
class ConstructionRule {
  const ConstructionRule({
    required this.id,
    required this.name,
    required this.isActive,
    required this.ordering,
    required this.constructionId,
    required this.wordSlotId,
    required this.formReference,
    required this.bindings,
  });

  final int id;
  final String name;
  final bool isActive;
  final int ordering;

  /// FK to PhraseConstructions.id — which construction this rule belongs to.
  final int constructionId;

  /// FK to ConstructionSlots.id — which slot is the "word slot" in the
  /// construction template.
  final int wordSlotId;

  /// How the word slot resolves to a form (base or cross-cell reference).
  final FormReference formReference;

  /// Feature bindings — reuses FeatureBindings verbatim (D-01).
  /// Specificity = number of dimension bindings = how specific this rule is.
  final FeatureBindings bindings;

  /// D-01: specificity for "most specific rule wins" — delegates to bindings.
  int get specificity => bindings.specificity;

  /// Construct from a Drift [ConstructionRuleRow] row.
  ///
  /// Parses [formReferenceJson] via [FormReference.fromJson] (T-10.1-01 safe).
  factory ConstructionRule.fromDbRow(dynamic row) {
    return ConstructionRule(
      id: row.id as int,
      name: row.name as String,
      isActive: row.isActive as bool,
      ordering: row.ordering as int,
      constructionId: row.constructionId as int,
      wordSlotId: row.wordSlotId as int,
      formReference: FormReference.fromJson(row.formReferenceJson as String?),
      bindings: row.featureBindings as FeatureBindings,
    );
  }
}
