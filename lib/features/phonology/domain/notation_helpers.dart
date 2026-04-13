// Plan 04-15 D-78: Shared pure notation helpers.
//
// This library is the SINGLE source of truth for longest-match rom<->phonemic
// conversion AND for the dot-separator disambiguation algorithm. It is pure
// Dart with ZERO dependencies on Flutter, Riverpod, or Drift so that BOTH
// `romanization_providers.dart` (runtime) AND `app_database.dart` (the v10
// migration) can import and call the same logic without wiring up a
// `WidgetRef` from inside a migration callback.
//
// Public API:
// - [NotationMapping] — a tiny record shape that both the runtime Drift row
//   type and raw `customSelect` QueryRows can be projected to.
// - [phonemicSegmentation] — longest-IPA-first left-to-right segmenter.
// - [dotAwareDeromanize] — rom -> phonemic, treats `.` as a consumed glyph
//   separator. Everything else is longest-latin-first.
// - [smartRomanize] — phonemic -> rom, segments via [phonemicSegmentation]
//   and inserts `.` between adjacent rom tokens whose naive concatenation
//   would re-parse to a different phoneme sequence.
// - [isDotAwareBijection] — predicate used by the D-72 validator.
//
// Invariants:
// - Characters (e.g. class-refs `V`, `C`, `F`) that don't match any mapping
//   are passed through verbatim as single-code-point segments.
// - The `.` character is ONLY meaningful on the rom side. On the phonemic
//   side it is treated as any other non-mapped character (pass-through).
//
// See `.planning/phases/04-grammar-morphology-revised/04-15-CONTEXT.md` §D-78
// for the full decision record.

/// A single row of the romanization mapping in the shape [notation_helpers]
/// needs. Both the runtime `RomanizationMapping` rows and the raw `QueryRow`
/// results read by the v10 migration project cleanly to this record.
typedef NotationMapping = ({String ipaSymbol, String latinMapping});

/// Segment [phonemic] into its constituent phonemes using a longest-IPA-first
/// left-to-right walk over [mappings]. Characters that match no mapping are
/// emitted as single-code-point segments so class-ref tokens and structural
/// characters flow through unchanged.
///
/// Returns an empty list for empty input. The concatenation of the returned
/// list is always exactly [phonemic].
List<String> phonemicSegmentation(
  String phonemic,
  List<NotationMapping> mappings,
) {
  if (phonemic.isEmpty) return const <String>[];

  // Sort by ipa-length descending so digraphs like `tʃ` beat single `t`.
  final sorted = List<NotationMapping>.from(mappings)
    ..sort((a, b) => b.ipaSymbol.length.compareTo(a.ipaSymbol.length));
  // Drop empty-ipa entries — they would match at every index and loop
  // forever.
  final active = sorted.where((m) => m.ipaSymbol.isNotEmpty).toList();

  final result = <String>[];
  var i = 0;
  while (i < phonemic.length) {
    var matched = false;
    for (final m in active) {
      if (phonemic.startsWith(m.ipaSymbol, i)) {
        result.add(m.ipaSymbol);
        i += m.ipaSymbol.length;
        matched = true;
        break;
      }
    }
    if (!matched) {
      // Pass-through: single code unit. Emit as its own segment so round-trip
      // preserves it and class-refs like `V` / `C` / `F` / `[name]` survive.
      result.add(phonemic[i]);
      i++;
    }
  }
  return result;
}

/// Convert [rom] to phonemic IPA. Treats `.` as a consumed glyph separator:
/// it emits no phoneme and RESETS the longest-match scan. Everything else is
/// longest-latin-first left-to-right substitution. Characters that match no
/// mapping are passed through verbatim so class-refs and mixed input survive.
///
/// Examples (under `{a→a, t→t, h→h, θ→th}`):
/// - `dotAwareDeromanize("atha", ...)` → `"aθa"`
/// - `dotAwareDeromanize("at.ha", ...)` → `"atha"` (three separate phonemes)
String dotAwareDeromanize(String rom, List<NotationMapping> mappings) {
  if (rom.isEmpty) return rom;

  // Sort by latin length descending so `ch` beats `c` + `h`.
  final sorted = List<NotationMapping>.from(mappings)
    ..sort((a, b) => b.latinMapping.length.compareTo(a.latinMapping.length));
  // Drop entries with empty latinMapping — they'd loop.
  final active = sorted.where((m) => m.latinMapping.isNotEmpty).toList();

  final buffer = StringBuffer();
  var i = 0;
  while (i < rom.length) {
    // Dot is consumed — no output, scan resets at i+1.
    if (rom[i] == '.') {
      i++;
      continue;
    }
    var matched = false;
    for (final m in active) {
      if (rom.startsWith(m.latinMapping, i)) {
        buffer.write(m.ipaSymbol);
        i += m.latinMapping.length;
        matched = true;
        break;
      }
    }
    if (!matched) {
      buffer.write(rom[i]);
      i++;
    }
  }
  return buffer.toString();
}

/// Convert [phonemic] IPA to rom using longest-IPA-first segmentation and
/// automatic insertion of `.` between adjacent rom tokens whose naive
/// concatenation would re-parse (via [dotAwareDeromanize]) to a DIFFERENT
/// phoneme sequence than the original pair.
///
/// Class-ref tokens (`V`, `C`, `F`, `[name]`) are never in the mapping, so
/// they segment as single-character pass-through entries and never trigger a
/// boundary insertion — `smartRomanize` only considers boundaries between
/// phoneme segments (i.e. segments that are in the mapping domain).
///
/// Examples (under `{a→a, t→t, h→h, θ→th}`):
/// - `smartRomanize("atha", ...)` → `"at.ha"` (disambiguating from `aθa`)
/// - `smartRomanize("aθa", ...)` → `"atha"` (no ambiguity, no dot)
String smartRomanize(String phonemic, List<NotationMapping> mappings) {
  if (phonemic.isEmpty) return phonemic;

  final segments = phonemicSegmentation(phonemic, mappings);
  if (segments.isEmpty) return phonemic;

  // Build a fast ipaSymbol -> latinMapping lookup for rom emission.
  final romBySymbol = <String, String>{};
  for (final m in mappings) {
    // First entry wins on collision (callers should enforce bijection).
    romBySymbol.putIfAbsent(m.ipaSymbol, () => m.latinMapping);
  }

  String romOf(String seg) => romBySymbol[seg] ?? seg;

  final buffer = StringBuffer();
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final romSeg = romOf(seg);
    if (i == 0) {
      buffer.write(romSeg);
      continue;
    }
    final prevSeg = segments[i - 1];
    final prevRom = romOf(prevSeg);

    // Decide whether to insert a `.` between prevRom and romSeg.
    // The boundary is needed if and only if the naive concatenation of the
    // two rom forms, when passed through dotAwareDeromanize, does NOT equal
    // the concatenation of their two phonemic segments.
    //
    // Only consider boundary insertion when BOTH sides are mapped phonemes
    // (segments whose rom form differs from the raw segment AND that are in
    // the mapping domain). Class-ref pass-through segments never trigger a
    // boundary — D-78 class-ref interaction invariant.
    final prevIsMapped = romBySymbol.containsKey(prevSeg);
    final curIsMapped = romBySymbol.containsKey(seg);
    bool needBoundary = false;
    if (prevIsMapped && curIsMapped) {
      final naive = prevRom + romSeg;
      final reparsed = dotAwareDeromanize(naive, mappings);
      final expected = prevSeg + seg;
      needBoundary = reparsed != expected;
    }
    if (needBoundary) {
      buffer.write('.');
    }
    buffer.write(romSeg);
  }
  return buffer.toString();
}

/// Returns true iff the active [mappings] form a dot-aware bijection —
/// i.e. for every adjacent pair of phonemes in the mapping domain,
/// `dotAwareDeromanize(smartRomanize(p + q)) == p + q`. This is the D-78
/// revision of the D-72 non-round-trip check: mapping sets like
/// `{t→t, h→h, θ→th}` are now valid because the dot disambiguator recovers
/// them (`at.ha` vs `atha`).
///
/// Duplicate-target cases (two phonemes mapping to the same rom string, or
/// two rom strings mapping to the same phoneme) are not dot-disambiguatable
/// and return false immediately. They are also reported separately by the
/// D-72 validator as their own violation kinds.
///
/// The exhaustive pairwise test is sufficient because dot-boundary decisions
/// are LOCAL — each boundary decision depends only on its two adjacent
/// segments, so if every adjacent pair round-trips, any concatenation of
/// pairs also round-trips.
bool isDotAwareBijection(List<NotationMapping> mappings) {
  // Drop empty-latin entries — they would loop.
  final active =
      mappings.where((m) => m.latinMapping.isNotEmpty && m.ipaSymbol.isNotEmpty)
          .toList();
  if (active.isEmpty) return true;

  // Fast path: reject duplicate targets. These cannot be dot-disambiguated.
  final ipaSeen = <String>{};
  final romSeen = <String>{};
  for (final m in active) {
    if (!ipaSeen.add(m.ipaSymbol)) return false;
    if (!romSeen.add(m.latinMapping)) return false;
  }

  // Single-phoneme round-trip: every phoneme must smart-romanize and then
  // deromanize back to itself.
  for (final m in active) {
    final rom = smartRomanize(m.ipaSymbol, active);
    final back = dotAwareDeromanize(rom, active);
    if (back != m.ipaSymbol) return false;
  }

  // Adjacent pairs (p, q) — including p == q — must round-trip via
  // smartRomanize / dotAwareDeromanize. O(N^2) in the mapping size.
  for (final p in active) {
    for (final q in active) {
      final input = p.ipaSymbol + q.ipaSymbol;
      final rom = smartRomanize(input, active);
      final back = dotAwareDeromanize(rom, active);
      if (back != input) return false;
    }
  }
  return true;
}
