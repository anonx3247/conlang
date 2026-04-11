import '../../../db/app_database.dart';

/// Resolves a [Lexeme]'s free-text `partOfSpeech` field to a concrete
/// [PartsOfSpeechData] row from [posList].
///
/// Research recommendation A7: instead of migrating Lexemes to use a posId
/// FK column, we keep the Phase 3 free-text column and resolve by
/// name/abbreviation match. This keeps the Phase 3 migration free of
/// data-mutation risk while still letting Phase 4 code look up the
/// structured POS metadata for a lexeme.
///
/// Matching rules:
///   1. The input is lowercased and trimmed.
///   2. First pass: exact (lowercased) match against `PartsOfSpeechData.name`.
///   3. Second pass: exact (lowercased) match against
///      `PartsOfSpeechData.abbreviation`.
///   4. Returns null if neither pass matches.
///
/// Name match takes precedence over abbreviation match — if two POS entries
/// could both match (e.g. one with name 'V' and another with abbr 'V'), the
/// name match wins. This matters when the user has intentionally named a
/// POS with a short token.
PartsOfSpeechData? posForLexeme(
  Lexeme lexeme,
  List<PartsOfSpeechData> posList,
) {
  final raw = lexeme.partOfSpeech;
  if (raw == null || raw.isEmpty || posList.isEmpty) return null;

  final needle = raw.toLowerCase().trim();
  if (needle.isEmpty) return null;

  for (final pos in posList) {
    if (pos.name.toLowerCase() == needle) return pos;
  }
  for (final pos in posList) {
    if (pos.abbreviation.toLowerCase() == needle) return pos;
  }
  return null;
}
