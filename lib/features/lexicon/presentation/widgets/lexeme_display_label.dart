import '../../../../db/app_database.dart';

/// D-110 (plan 04-17): pure function that computes the display label for a
/// lexeme in a rom-aware selector (dropdown, chip, etc.).
///
/// Rules:
///   1. When rom is disabled, return the stored IPA.
///   2. When rom is enabled and the lexeme has a stored romanization,
///      return it (preferred — user-authored).
///   3. When rom is enabled but no stored romanization, derive via
///      `romanize(lexeme.ipa)`.
///
/// Callers provide `romEnabled` and `romanize` so this function has no
/// dependency on WidgetRef or Riverpod — it is a pure Dart function
/// suitable for use anywhere.
String lexemeDisplayLabel(
  Lexeme lexeme, {
  required bool romEnabled,
  required String Function(String) romanize,
}) {
  if (!romEnabled) return lexeme.ipa;
  final stored = lexeme.romanization;
  if (stored != null && stored.isNotEmpty) return stored;
  return romanize(lexeme.ipa);
}
