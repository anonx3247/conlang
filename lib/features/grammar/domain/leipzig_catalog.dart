/// Leipzig glossing abbreviation catalog for Phase 10 gloss tag autocomplete.
///
/// Each [LexicalGlossEntry] stores the abbreviation, its full meaning, and a
/// semantic category. The flat [leipzigGlossAbbreviations] list is used by the
/// `Autocomplete<String>` widget in [ParticleDialog].
library;

/// A single entry from the Leipzig glossing catalog.
class LexicalGlossEntry {
  const LexicalGlossEntry({
    required this.abbreviation,
    required this.meaning,
    required this.category,
  });

  /// The uppercase abbreviation used in interlinear glosses, e.g. "NEG".
  final String abbreviation;

  /// Human-readable meaning of the abbreviation, e.g. "Negation".
  final String meaning;

  /// Semantic category grouping, e.g. "Polarity", "Tense", "Voice/Valence".
  final String category;
}

/// ~45 common Leipzig glossing abbreviations used for gloss tag autocomplete.
///
/// Covers determination, polarity, aspect, tense, modality/TAM,
/// voice/valence, information structure, pragmatics, coordination,
/// adposition, case functions, subordination, evidentiality, and other.
const List<LexicalGlossEntry> leipzigGlossCatalog = [
  // Determination
  LexicalGlossEntry(
    abbreviation: 'DEF',
    meaning: 'Definite',
    category: 'Determination',
  ),
  LexicalGlossEntry(
    abbreviation: 'INDF',
    meaning: 'Indefinite',
    category: 'Determination',
  ),
  LexicalGlossEntry(
    abbreviation: 'DET',
    meaning: 'Determiner',
    category: 'Determination',
  ),
  LexicalGlossEntry(
    abbreviation: 'QUANT',
    meaning: 'Quantifier',
    category: 'Determination',
  ),

  // Polarity
  LexicalGlossEntry(
    abbreviation: 'NEG',
    meaning: 'Negation',
    category: 'Polarity',
  ),

  // Aspect
  LexicalGlossEntry(
    abbreviation: 'PROG',
    meaning: 'Progressive',
    category: 'Aspect',
  ),
  LexicalGlossEntry(
    abbreviation: 'PERF',
    meaning: 'Perfective',
    category: 'Aspect',
  ),
  LexicalGlossEntry(
    abbreviation: 'IPFV',
    meaning: 'Imperfective',
    category: 'Aspect',
  ),
  LexicalGlossEntry(
    abbreviation: 'PRFV',
    meaning: 'Perfect',
    category: 'Aspect',
  ),

  // Tense
  LexicalGlossEntry(
    abbreviation: 'PST',
    meaning: 'Past',
    category: 'Tense',
  ),
  LexicalGlossEntry(
    abbreviation: 'PRS',
    meaning: 'Present',
    category: 'Tense',
  ),
  LexicalGlossEntry(
    abbreviation: 'FUT',
    meaning: 'Future',
    category: 'Tense',
  ),

  // Modality/TAM
  LexicalGlossEntry(
    abbreviation: 'AUX',
    meaning: 'Auxiliary',
    category: 'Modality/TAM',
  ),
  LexicalGlossEntry(
    abbreviation: 'MOD',
    meaning: 'Modal',
    category: 'Modality/TAM',
  ),
  LexicalGlossEntry(
    abbreviation: 'CERT',
    meaning: 'Certitude',
    category: 'Modality/TAM',
  ),

  // Voice/Valence
  LexicalGlossEntry(
    abbreviation: 'CAUS',
    meaning: 'Causative',
    category: 'Voice/Valence',
  ),
  LexicalGlossEntry(
    abbreviation: 'PASS',
    meaning: 'Passive',
    category: 'Voice/Valence',
  ),
  LexicalGlossEntry(
    abbreviation: 'REFL',
    meaning: 'Reflexive',
    category: 'Voice/Valence',
  ),
  LexicalGlossEntry(
    abbreviation: 'RECIP',
    meaning: 'Reciprocal',
    category: 'Voice/Valence',
  ),
  LexicalGlossEntry(
    abbreviation: 'COP',
    meaning: 'Copula',
    category: 'Voice/Valence',
  ),
  LexicalGlossEntry(
    abbreviation: 'EXIST',
    meaning: 'Existential',
    category: 'Voice/Valence',
  ),

  // Information structure
  LexicalGlossEntry(
    abbreviation: 'TOP',
    meaning: 'Topic',
    category: 'Information',
  ),
  LexicalGlossEntry(
    abbreviation: 'FOC',
    meaning: 'Focus',
    category: 'Information',
  ),
  LexicalGlossEntry(
    abbreviation: 'EMPH',
    meaning: 'Emphatic',
    category: 'Information',
  ),

  // Pragmatics
  LexicalGlossEntry(
    abbreviation: 'Q',
    meaning: 'Question',
    category: 'Pragmatics',
  ),
  LexicalGlossEntry(
    abbreviation: 'INTJ',
    meaning: 'Interjection',
    category: 'Pragmatics',
  ),
  LexicalGlossEntry(
    abbreviation: 'PTCL',
    meaning: 'Particle',
    category: 'Pragmatics',
  ),

  // Coordination
  LexicalGlossEntry(
    abbreviation: 'CONJ',
    meaning: 'Conjunction',
    category: 'Coordination',
  ),
  LexicalGlossEntry(
    abbreviation: 'DISJ',
    meaning: 'Disjunction',
    category: 'Coordination',
  ),

  // Adposition
  LexicalGlossEntry(
    abbreviation: 'PREP',
    meaning: 'Preposition',
    category: 'Adposition',
  ),
  LexicalGlossEntry(
    abbreviation: 'POST',
    meaning: 'Postposition',
    category: 'Adposition',
  ),

  // Case function
  LexicalGlossEntry(
    abbreviation: 'GEN',
    meaning: 'Genitive',
    category: 'Case function',
  ),
  LexicalGlossEntry(
    abbreviation: 'ACC',
    meaning: 'Accusative',
    category: 'Case function',
  ),
  LexicalGlossEntry(
    abbreviation: 'DAT',
    meaning: 'Dative',
    category: 'Case function',
  ),
  LexicalGlossEntry(
    abbreviation: 'LOC',
    meaning: 'Locative',
    category: 'Case function',
  ),

  // Subordination
  LexicalGlossEntry(
    abbreviation: 'COMP',
    meaning: 'Complementizer',
    category: 'Subordination',
  ),
  LexicalGlossEntry(
    abbreviation: 'REL',
    meaning: 'Relativizer',
    category: 'Subordination',
  ),
  LexicalGlossEntry(
    abbreviation: 'SUB',
    meaning: 'Subordinator',
    category: 'Subordination',
  ),

  // Evidentiality
  LexicalGlossEntry(
    abbreviation: 'EV',
    meaning: 'Evidential',
    category: 'Evidentiality',
  ),
  LexicalGlossEntry(
    abbreviation: 'QUOT',
    meaning: 'Quotative',
    category: 'Evidentiality',
  ),
];

/// Flat list of all abbreviation strings for use in the gloss tag autocomplete.
///
/// Sorted alphabetically for predictable ordering.
const List<String> leipzigGlossAbbreviations = [
  'ACC',
  'AUX',
  'CAUS',
  'CERT',
  'COMP',
  'CONJ',
  'COP',
  'DAT',
  'DEF',
  'DET',
  'DISJ',
  'EMPH',
  'EV',
  'EXIST',
  'FOC',
  'FUT',
  'GEN',
  'INDF',
  'INTJ',
  'IPFV',
  'LOC',
  'MOD',
  'NEG',
  'PASS',
  'PERF',
  'POST',
  'PREP',
  'PRFV',
  'PROG',
  'PRS',
  'PST',
  'PTCL',
  'Q',
  'QUANT',
  'RECIP',
  'REFL',
  'REL',
  'SUB',
  'TOP',
];
