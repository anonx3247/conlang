import '../../grammar/domain/inflectional_rule.dart';
import '../../../db/app_database.dart';

/// Result of resolving a single token against the project's lexicon.
///
/// The [glossLabel] getter produces the Leipzig-format label for the
/// gloss tier of the interlinear display.
sealed class GlossMatch {
  const GlossMatch();

  /// Human-readable gloss label for the interlinear tier.
  String get glossLabel;

  /// The IPA (phonemic) form for this match. Used for phonotactic
  /// validation and IPA transcription.
  String get ipa;
}

/// Token matched an exact root/base lexeme form.
class ExactLexemeMatch extends GlossMatch {
  const ExactLexemeMatch({required this.lexeme});
  final Lexeme lexeme;

  @override
  String get glossLabel {
    // Closed-class particles use their glossTag (e.g. NEG, DEF, PROG).
    if (lexeme.isClosedClass &&
        lexeme.glossTag != null &&
        lexeme.glossTag!.isNotEmpty) {
      return lexeme.glossTag!;
    }
    // Open-class words use their meaning (e.g. "stone", "eat").
    return lexeme.meaning ?? lexeme.ipa;
  }

  @override
  String get ipa => lexeme.ipa;
}

/// Token matched a known inflected paradigm form.
class InflectedFormMatch extends GlossMatch {
  const InflectedFormMatch({
    required this.lexeme,
    required this.ruleChain,
    required this.levelAbbrs,
  });
  final Lexeme lexeme;
  final List<InflectionalRule> ruleChain;

  /// Leipzig abbreviations for the inflectional feature set,
  /// e.g. ['PST', '3', 'SG']. Built from DimensionLevel.abbr values.
  final List<String> levelAbbrs;

  @override
  String get glossLabel {
    final base = lexeme.meaning ?? lexeme.ipa;
    if (levelAbbrs.isEmpty) return base;
    return '$base.${levelAbbrs.join('.')}';
  }

  @override
  String get ipa => lexeme.ipa; // root IPA — inflected form IPA handled separately
}

/// Token matched a derived form computed by the morphology engine.
class DerivedFormMatch extends GlossMatch {
  const DerivedFormMatch({
    required this.rootLexeme,
    required this.ruleName,
    required this.derivedIpa,
  });
  final Lexeme rootLexeme;
  final String ruleName;
  final String derivedIpa;

  @override
  String get glossLabel {
    final base = rootLexeme.meaning ?? rootLexeme.ipa;
    return '$base.$ruleName';
  }

  @override
  String get ipa => derivedIpa;
}

/// Token did not match any known form.
class UnknownToken extends GlossMatch {
  const UnknownToken({required this.text});
  final String text;

  @override
  String get glossLabel => '?';

  @override
  String get ipa => text;
}
