// lib/features/phonology/domain/default_natural_classes.dart
//
// Hardcoded predefined natural classes that resolve in the DSL regardless
// of the project's phoneme inventory. See Phase 3.2 CONTEXT D-07.
//
// Convention: full names are stored under their lowercased form (matching the
// runtime resolver's existing behavior). Single-letter aliases are stored
// case-sensitively (uppercase) and the resolver checks exact case BEFORE
// lowercasing the lookup key.
//
// Cross-membership is intentional: a segment may appear in Liquid AND Rhotic,
// or in Stop AND Obstruent. The lists are descriptive, not partitioning.
//
// Sonorant is deliberately consonant-only (no vowels) to match common UX
// expectation in conlang tools (A1 in 03.2-RESEARCH.md).

const _stops = ['p', 'b', 't', 'd', 'ʈ', 'ɖ', 'c', 'ɟ', 'k', 'ɡ', 'q', 'ɢ', 'ʔ'];
const _nasals = ['m', 'ɱ', 'n', 'ɳ', 'ɲ', 'ŋ', 'ɴ'];
const _fricatives = [
  'ɸ', 'β', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'ʂ', 'ʐ',
  'ç', 'ʝ', 'x', 'ɣ', 'χ', 'ʁ', 'ħ', 'ʕ', 'h', 'ɦ',
  'ɬ', 'ɮ', // lateral fricatives — added per RESEARCH F-3 / A5
];
const _affricates = ['t͡s', 'd͡z', 't͡ʃ', 'd͡ʒ', 'ʈ͡ʂ', 'ɖ͡ʐ', 't͡ɕ', 'd͡ʑ'];
const _approximants = ['j', 'w', 'ɥ', 'ɰ', 'ʋ', 'ɹ', 'ɻ', 'l', 'ɭ', 'ʎ', 'ʟ'];
const _rhotics = ['r', 'ɾ', 'ɹ', 'ɻ', 'ɽ', 'ʀ', 'ʁ'];
const _liquids = [
  'l', 'ɭ', 'ʎ', 'ʟ', // lateral approximants
  'r', 'ɾ', 'ɹ', 'ɻ', 'ɽ', 'ʀ', 'ʁ', // rhotics
];

const _obstruents = [..._stops, ..._fricatives, ..._affricates];
const _sonorants = [..._nasals, ..._liquids, ..._approximants];

/// Default natural classes keyed by their canonical (lowercased) name.
///
/// Used by `phonotactic_providers.buildInventory` to merge into the runtime
/// `PhonemeInventory` snapshot. User-defined classes with matching keys
/// overlay these defaults (D-06 precedence).
const Map<String, List<String>> defaultNaturalClasses = {
  'stop': _stops,
  'nasal': _nasals,
  'fricative': _fricatives,
  'liquid': _liquids,
  'rhotic': _rhotics,
  'obstruent': _obstruents,
  'sonorant': _sonorants,
  'approximant': _approximants,
  'affricate': _affricates,
};

/// Single-letter aliases. CASE-SENSITIVE — must be looked up BEFORE lowercasing
/// the lookup key in `WordGenerator._resolveClass` and
/// `morphology_engine.resolvePhonemeClass` (Plan 02 wires this — see D-05a /
/// RESEARCH F-2).
const Map<String, List<String>> defaultNaturalClassAliases = {
  'S': _stops,
  'N': _nasals,
  'F': _fricatives,
  'L': _liquids,
  'R': _rhotics,
};
