import 'gloss_match.dart';

/// A single token from a phrase with its resolved gloss match.
class PhraseToken {
  const PhraseToken({
    required this.text,
    required this.match,
    required this.hasViolation,
  });

  /// The original text as typed by the user.
  final String text;

  /// The resolved gloss match (exact, inflected, derived, or unknown).
  final GlossMatch match;

  /// Whether this token violates phonotactic rules.
  final bool hasViolation;

  /// True if the token was not found in the lexicon.
  bool get isUnknown => match is UnknownToken;
}

/// Whitespace-splits [input] into tokens and resolves each against
/// [glossIndex]. Checks phonotactic validity via [validateWord].
///
/// The lookup priority is: exact match > inflected > derived > unknown
/// (priority is baked into the index at build time — the first match wins).
///
/// Returns an empty list for empty/whitespace-only input.
List<PhraseToken> tokenizePhrase({
  required String input,
  required Map<String, GlossMatch> glossIndex,
  required bool Function({required String word}) validateWord,
}) {
  if (input.trim().isEmpty) return const [];

  final words = input.split(RegExp(r'\s+'));
  return words.map((word) {
    final match = glossIndex[word] ?? UnknownToken(text: word);
    // Phonotactic check uses the IPA form from the match.
    // For unknown tokens, use the raw text as-is (it may or may not be IPA).
    final isValid = validateWord(word: match.ipa);
    return PhraseToken(
      text: word,
      match: match,
      // hasViolation is only set for known tokens — unknown tokens get amber
      // highlight instead, not red underline (per CONTEXT.md error highlighting).
      hasViolation: !isValid && match is! UnknownToken,
    );
  }).toList();
}
