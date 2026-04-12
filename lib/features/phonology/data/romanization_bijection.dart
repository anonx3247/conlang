// Plan 04-15 D-72: Romanization bijection validator data types.
//
// The RomanizationDao's `validateRomanizationBijection()` method returns a
// list of these violations. Zero violations == the mapping set is a valid
// dot-aware bijection (D-78) and rule DSL round-trip is safe.

/// The kind of bijection rule that a [BijectionViolation] reports.
enum BijectionViolationKind {
  /// Two mapping rows share the same `ipaSymbol`. Cannot be disambiguated
  /// by a dot boundary — the conflict is at the phoneme level.
  duplicatePhonemeTarget,

  /// Two mapping rows share the same `latinMapping`. Cannot be
  /// disambiguated by a dot boundary — two phonemes collapsing to the
  /// same rom glyph would have no way to tell them apart when reading.
  duplicateRomTarget,

  /// The active set as a whole does not round-trip through the dot-aware
  /// helpers (D-78): there exists at least one phoneme sequence whose
  /// `dotAwareDeromanize(smartRomanize(x)) != x`. Unlike the row-level
  /// duplicate cases, this is a property of the SET and does not name a
  /// single offending row — the `detail` string names the offending
  /// phoneme pair instead.
  nonRoundTrip,
}

/// A single violation of the romanization-mapping bijection contract.
///
/// - [kind] — which rule was violated.
/// - [rowId] — the id of the mapping row that triggered it, when the
///   violation has a natural row home. For [BijectionViolationKind.nonRoundTrip]
///   the violation is a property of the active set as a whole, so [rowId] is
///   null and the offending phoneme pair is described in [detail] instead.
/// - [detail] — human-readable message suitable for inline error display.
class BijectionViolation {
  final BijectionViolationKind kind;
  final int? rowId;
  final String detail;

  const BijectionViolation({
    required this.kind,
    required this.detail,
    this.rowId,
  });

  @override
  String toString() => 'BijectionViolation(${kind.name}, rowId=$rowId, $detail)';
}
