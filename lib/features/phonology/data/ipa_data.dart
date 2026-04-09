// IPA data model and static data for the full IPA chart.
//
// Covers:
// - Pulmonic consonants (manner x place grid)
// - Vowels (height x backness grid)
// - Non-pulmonic consonants (clicks, implosives, ejectives)
// - Common suprasegmentals

// ignore_for_file: constant_identifier_names

/// The type of an IPA sound.
enum IpaSoundType { consonant, vowel }

/// Manner of articulation for consonants.
enum Manner {
  plosive,
  nasal,
  trill,
  tapOrFlap,
  fricative,
  lateralFricative,
  approximant,
  lateralApproximant,
  // Non-pulmonic
  click,
  implosive,
  ejective,
}

/// Place of articulation for consonants.
enum Place {
  bilabial,
  labiodental,
  dental,
  alveolar,
  postalveolar,
  retroflex,
  palatal,
  velar,
  uvular,
  pharyngeal,
  glottal,
  // Clicks only
  palatoalveolar,
  alveolarlateral,
}

/// Vowel height.
enum VowelHeight {
  close,
  nearClose,
  closeMid,
  mid,
  openMid,
  nearOpen,
  open,
}

/// Vowel backness.
enum VowelBackness {
  front,
  nearFront,
  central,
  nearBack,
  back,
}

/// An IPA sound with all relevant properties and optional audio asset path.
class IpaSound {
  const IpaSound({
    required this.symbol,
    required this.name,
    required this.type,
    this.manner,
    this.place,
    this.voiced,
    this.height,
    this.backness,
    this.rounded,
    this.audioAssetPath,
  });

  /// The IPA symbol (e.g. "b", "ɑ").
  final String symbol;

  /// Full articulation name (e.g. "voiced bilabial plosive").
  final String name;

  final IpaSoundType type;

  // Consonant fields
  final Manner? manner;
  final Place? place;
  final bool? voiced;

  // Vowel fields
  final VowelHeight? height;
  final VowelBackness? backness;
  final bool? rounded;

  /// Path to bundled OGG audio file, or null if no recording available.
  final String? audioAssetPath;

  // ─────────────────────────────────────────────────────────────────────────
  // PULMONIC CONSONANTS
  // Organized as a list for the standard IPA chart.
  // ─────────────────────────────────────────────────────────────────────────

  /// All pulmonic consonants in standard IPA chart order.
  static const List<IpaSound> pulmonicConsonants = [
    // ── Plosives ──────────────────────────────────────────────────────────
    IpaSound(symbol: 'p', name: 'voiceless bilabial plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.bilabial, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_bilabial_plosive.ogg'),
    IpaSound(symbol: 'b', name: 'voiced bilabial plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.bilabial, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_bilabial_plosive.ogg'),
    IpaSound(symbol: 't', name: 'voiceless alveolar plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.alveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_alveolar_plosive.ogg'),
    IpaSound(symbol: 'd', name: 'voiced alveolar plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_plosive.ogg'),
    IpaSound(symbol: 'ʈ', name: 'voiceless retroflex plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.retroflex, voiced: false, audioAssetPath: null),
    IpaSound(symbol: 'ɖ', name: 'voiced retroflex plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.retroflex, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_retroflex_plosive.ogg'),
    IpaSound(symbol: 'c', name: 'voiceless palatal plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.palatal, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_palatal_plosive.ogg'),
    IpaSound(symbol: 'ɟ', name: 'voiced palatal plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_plosive.ogg'),
    IpaSound(symbol: 'k', name: 'voiceless velar plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.velar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_velar_plosive.ogg'),
    IpaSound(symbol: 'ɡ', name: 'voiced velar plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_plosive.ogg'),
    IpaSound(symbol: 'q', name: 'voiceless uvular plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.uvular, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_uvular_plosive.ogg'),
    IpaSound(symbol: 'ɢ', name: 'voiced uvular plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.uvular, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_uvular_plosive.ogg'),
    IpaSound(symbol: 'ʔ', name: 'voiceless glottal plosive', type: IpaSoundType.consonant, manner: Manner.plosive, place: Place.glottal, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_glottal_plosive.ogg'),

    // ── Nasals ────────────────────────────────────────────────────────────
    IpaSound(symbol: 'm', name: 'voiced bilabial nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.bilabial, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_bilabial_nasal.ogg'),
    IpaSound(symbol: 'ɱ', name: 'voiced labiodental nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.labiodental, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_labiodental_nasal.ogg'),
    IpaSound(symbol: 'n', name: 'voiced alveolar nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_nasal.ogg'),
    IpaSound(symbol: 'ɳ', name: 'voiced retroflex nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.retroflex, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_retroflex_nasal.ogg'),
    IpaSound(symbol: 'ɲ', name: 'voiced palatal nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_nasal.ogg'),
    IpaSound(symbol: 'ŋ', name: 'voiced velar nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_nasal.ogg'),
    IpaSound(symbol: 'ɴ', name: 'voiced uvular nasal', type: IpaSoundType.consonant, manner: Manner.nasal, place: Place.uvular, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_uvular_nasal.ogg'),

    // ── Trills ────────────────────────────────────────────────────────────
    IpaSound(symbol: 'ʙ', name: 'voiced bilabial trill', type: IpaSoundType.consonant, manner: Manner.trill, place: Place.bilabial, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_bilabial_trill.ogg'),
    IpaSound(symbol: 'r', name: 'voiced alveolar trill', type: IpaSoundType.consonant, manner: Manner.trill, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_trill.ogg'),
    IpaSound(symbol: 'ʀ', name: 'voiced uvular trill', type: IpaSoundType.consonant, manner: Manner.trill, place: Place.uvular, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_uvular_trill.ogg'),

    // ── Taps / Flaps ──────────────────────────────────────────────────────
    IpaSound(symbol: 'ɾ', name: 'voiced alveolar tap', type: IpaSoundType.consonant, manner: Manner.tapOrFlap, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_tap.ogg'),
    IpaSound(symbol: 'ɽ', name: 'voiced retroflex tap', type: IpaSoundType.consonant, manner: Manner.tapOrFlap, place: Place.retroflex, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_retroflex_tap.ogg'),

    // ── Fricatives ────────────────────────────────────────────────────────
    IpaSound(symbol: 'ɸ', name: 'voiceless bilabial fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.bilabial, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_bilabial_fricative.ogg'),
    IpaSound(symbol: 'β', name: 'voiced bilabial fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.bilabial, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_bilabial_fricative.ogg'),
    IpaSound(symbol: 'f', name: 'voiceless labiodental fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.labiodental, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_labiodental_fricative.ogg'),
    IpaSound(symbol: 'v', name: 'voiced labiodental fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.labiodental, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_labiodental_fricative.ogg'),
    IpaSound(symbol: 'θ', name: 'voiceless dental fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.dental, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_dental_fricative.ogg'),
    IpaSound(symbol: 'ð', name: 'voiced dental fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.dental, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_dental_fricative.ogg'),
    IpaSound(symbol: 's', name: 'voiceless alveolar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.alveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_alveolar_fricative.ogg'),
    IpaSound(symbol: 'z', name: 'voiced alveolar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_fricative.ogg'),
    IpaSound(symbol: 'ʃ', name: 'voiceless postalveolar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.postalveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_postalveolar_fricative.ogg'),
    IpaSound(symbol: 'ʒ', name: 'voiced postalveolar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.postalveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_postalveolar_fricative.ogg'),
    IpaSound(symbol: 'ʂ', name: 'voiceless retroflex fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.retroflex, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_retroflex_fricative.ogg'),
    IpaSound(symbol: 'ʐ', name: 'voiced retroflex fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.retroflex, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_retroflex_fricative.ogg'),
    IpaSound(symbol: 'ç', name: 'voiceless palatal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.palatal, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_palatal_fricative.ogg'),
    IpaSound(symbol: 'ʝ', name: 'voiced palatal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_fricative.ogg'),
    IpaSound(symbol: 'x', name: 'voiceless velar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.velar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_velar_fricative.ogg'),
    IpaSound(symbol: 'ɣ', name: 'voiced velar fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_fricative.ogg'),
    IpaSound(symbol: 'χ', name: 'voiceless uvular fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.uvular, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_uvular_fricative.ogg'),
    IpaSound(symbol: 'ʁ', name: 'voiced uvular fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.uvular, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_uvular_fricative.ogg'),
    IpaSound(symbol: 'ħ', name: 'voiceless pharyngeal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.pharyngeal, voiced: false, audioAssetPath: null),
    IpaSound(symbol: 'ʕ', name: 'voiced pharyngeal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.pharyngeal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_pharyngeal_fricative.ogg'),
    IpaSound(symbol: 'h', name: 'voiceless glottal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.glottal, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_glottal_fricative.ogg'),
    IpaSound(symbol: 'ɦ', name: 'voiced glottal fricative', type: IpaSoundType.consonant, manner: Manner.fricative, place: Place.glottal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_glottal_fricative.ogg'),

    // ── Lateral Fricatives ────────────────────────────────────────────────
    IpaSound(symbol: 'ɬ', name: 'voiceless alveolar lateral fricative', type: IpaSoundType.consonant, manner: Manner.lateralFricative, place: Place.alveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/voiceless_alveolar_lateral_fricative.ogg'),
    IpaSound(symbol: 'ɮ', name: 'voiced alveolar lateral fricative', type: IpaSoundType.consonant, manner: Manner.lateralFricative, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_lateral_fricative.ogg'),

    // ── Approximants ──────────────────────────────────────────────────────
    IpaSound(symbol: 'ʋ', name: 'voiced labiodental approximant', type: IpaSoundType.consonant, manner: Manner.approximant, place: Place.labiodental, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_labiodental_approximant.ogg'),
    IpaSound(symbol: 'ɹ', name: 'voiced alveolar approximant', type: IpaSoundType.consonant, manner: Manner.approximant, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_approximant.ogg'),
    IpaSound(symbol: 'ɻ', name: 'voiced retroflex approximant', type: IpaSoundType.consonant, manner: Manner.approximant, place: Place.retroflex, voiced: true, audioAssetPath: null),
    IpaSound(symbol: 'j', name: 'voiced palatal approximant', type: IpaSoundType.consonant, manner: Manner.approximant, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_approximant.ogg'),
    IpaSound(symbol: 'ɰ', name: 'voiced velar approximant', type: IpaSoundType.consonant, manner: Manner.approximant, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_approximant.ogg'),

    // ── Lateral Approximants ───────────────────────────────────────────────
    IpaSound(symbol: 'l', name: 'voiced alveolar lateral approximant', type: IpaSoundType.consonant, manner: Manner.lateralApproximant, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_lateral_approximant.ogg'),
    IpaSound(symbol: 'ɭ', name: 'voiced retroflex lateral approximant', type: IpaSoundType.consonant, manner: Manner.lateralApproximant, place: Place.retroflex, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_retroflex_lateral_approximant.ogg'),
    IpaSound(symbol: 'ʎ', name: 'voiced palatal lateral approximant', type: IpaSoundType.consonant, manner: Manner.lateralApproximant, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_lateral_approximant.ogg'),
    IpaSound(symbol: 'ʟ', name: 'voiced velar lateral approximant', type: IpaSoundType.consonant, manner: Manner.lateralApproximant, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_lateral_approximant.ogg'),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // VOWELS
  // ─────────────────────────────────────────────────────────────────────────

  static const List<IpaSound> vowels = [
    // ── Close ─────────────────────────────────────────────────────────────
    IpaSound(symbol: 'i', name: 'close front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.front, rounded: false, audioAssetPath: 'assets/ipa_audio/close_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'y', name: 'close front rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.front, rounded: true, audioAssetPath: 'assets/ipa_audio/close_front_rounded_vowel.ogg'),
    IpaSound(symbol: 'ɨ', name: 'close central unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.central, rounded: false, audioAssetPath: 'assets/ipa_audio/close_central_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ʉ', name: 'close central rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.central, rounded: true, audioAssetPath: 'assets/ipa_audio/close_central_rounded_vowel.ogg'),
    IpaSound(symbol: 'ɯ', name: 'close back unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.back, rounded: false, audioAssetPath: 'assets/ipa_audio/close_back_unrounded_vowel.ogg'),
    IpaSound(symbol: 'u', name: 'close back rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.close, backness: VowelBackness.back, rounded: true, audioAssetPath: 'assets/ipa_audio/close_back_rounded_vowel.ogg'),

    // ── Near-close ────────────────────────────────────────────────────────
    IpaSound(symbol: 'ɪ', name: 'near-close near-front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.nearClose, backness: VowelBackness.nearFront, rounded: false, audioAssetPath: 'assets/ipa_audio/near_close_near_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ʏ', name: 'near-close near-front rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.nearClose, backness: VowelBackness.nearFront, rounded: true, audioAssetPath: 'assets/ipa_audio/near_close_near_front_rounded_vowel.ogg'),
    IpaSound(symbol: 'ʊ', name: 'near-close near-back rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.nearClose, backness: VowelBackness.nearBack, rounded: true, audioAssetPath: 'assets/ipa_audio/near_close_near_back_rounded_vowel.ogg'),

    // ── Close-mid ─────────────────────────────────────────────────────────
    IpaSound(symbol: 'e', name: 'close-mid front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.front, rounded: false, audioAssetPath: 'assets/ipa_audio/close_mid_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ø', name: 'close-mid front rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.front, rounded: true, audioAssetPath: 'assets/ipa_audio/close_mid_front_rounded_vowel.ogg'),
    IpaSound(symbol: 'ɘ', name: 'close-mid central unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.central, rounded: false, audioAssetPath: null),
    IpaSound(symbol: 'ɵ', name: 'close-mid central rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.central, rounded: true, audioAssetPath: 'assets/ipa_audio/close_mid_central_rounded_vowel.ogg'),
    IpaSound(symbol: 'ɤ', name: 'close-mid back unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.back, rounded: false, audioAssetPath: 'assets/ipa_audio/close_mid_back_unrounded_vowel.ogg'),
    IpaSound(symbol: 'o', name: 'close-mid back rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.closeMid, backness: VowelBackness.back, rounded: true, audioAssetPath: 'assets/ipa_audio/close_mid_back_rounded_vowel.ogg'),

    // ── Mid ───────────────────────────────────────────────────────────────
    IpaSound(symbol: 'e̞', name: 'mid front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.mid, backness: VowelBackness.front, rounded: false, audioAssetPath: null),
    IpaSound(symbol: 'ə', name: 'mid central vowel (schwa)', type: IpaSoundType.vowel, height: VowelHeight.mid, backness: VowelBackness.central, rounded: false, audioAssetPath: 'assets/ipa_audio/mid_central_vowel.ogg'),

    // ── Open-mid ──────────────────────────────────────────────────────────
    IpaSound(symbol: 'ɛ', name: 'open-mid front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.front, rounded: false, audioAssetPath: 'assets/ipa_audio/open_mid_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'œ', name: 'open-mid front rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.front, rounded: true, audioAssetPath: 'assets/ipa_audio/open_mid_front_rounded_vowel.ogg'),
    IpaSound(symbol: 'ɜ', name: 'open-mid central unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.central, rounded: false, audioAssetPath: 'assets/ipa_audio/open_mid_central_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ɞ', name: 'open-mid central rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.central, rounded: true, audioAssetPath: null),
    IpaSound(symbol: 'ʌ', name: 'open-mid back unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.back, rounded: false, audioAssetPath: 'assets/ipa_audio/open_mid_back_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ɔ', name: 'open-mid back rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.openMid, backness: VowelBackness.back, rounded: true, audioAssetPath: 'assets/ipa_audio/open_mid_back_rounded_vowel.ogg'),

    // ── Near-open ─────────────────────────────────────────────────────────
    IpaSound(symbol: 'æ', name: 'near-open front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.nearOpen, backness: VowelBackness.front, rounded: false, audioAssetPath: 'assets/ipa_audio/near_open_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ɐ', name: 'near-open central vowel', type: IpaSoundType.vowel, height: VowelHeight.nearOpen, backness: VowelBackness.central, rounded: false, audioAssetPath: 'assets/ipa_audio/near_open_central_vowel.ogg'),

    // ── Open ──────────────────────────────────────────────────────────────
    IpaSound(symbol: 'a', name: 'open front unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.open, backness: VowelBackness.front, rounded: false, audioAssetPath: 'assets/ipa_audio/open_front_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ɶ', name: 'open front rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.open, backness: VowelBackness.front, rounded: true, audioAssetPath: null),
    IpaSound(symbol: 'ä', name: 'open central unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.open, backness: VowelBackness.central, rounded: false, audioAssetPath: null),
    IpaSound(symbol: 'ɑ', name: 'open back unrounded vowel', type: IpaSoundType.vowel, height: VowelHeight.open, backness: VowelBackness.back, rounded: false, audioAssetPath: 'assets/ipa_audio/open_back_unrounded_vowel.ogg'),
    IpaSound(symbol: 'ɒ', name: 'open back rounded vowel', type: IpaSoundType.vowel, height: VowelHeight.open, backness: VowelBackness.back, rounded: true, audioAssetPath: 'assets/ipa_audio/open_back_rounded_vowel.ogg'),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // NON-PULMONIC CONSONANTS
  // ─────────────────────────────────────────────────────────────────────────

  static const List<IpaSound> nonPulmonicConsonants = [
    // ── Clicks ────────────────────────────────────────────────────────────
    IpaSound(symbol: 'ʘ', name: 'bilabial click', type: IpaSoundType.consonant, manner: Manner.click, place: Place.bilabial, voiced: false, audioAssetPath: 'assets/ipa_audio/bilabial_click.ogg'),
    IpaSound(symbol: 'ǀ', name: 'dental click', type: IpaSoundType.consonant, manner: Manner.click, place: Place.dental, voiced: false, audioAssetPath: 'assets/ipa_audio/dental_click.ogg'),
    IpaSound(symbol: 'ǃ', name: 'alveolar click', type: IpaSoundType.consonant, manner: Manner.click, place: Place.alveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/alveolar_click.ogg'),
    IpaSound(symbol: 'ǂ', name: 'palatoalveolar click', type: IpaSoundType.consonant, manner: Manner.click, place: Place.palatoalveolar, voiced: false, audioAssetPath: 'assets/ipa_audio/palatoalveolar_click.ogg'),
    IpaSound(symbol: 'ǁ', name: 'alveolar lateral click', type: IpaSoundType.consonant, manner: Manner.click, place: Place.alveolarlateral, voiced: false, audioAssetPath: 'assets/ipa_audio/alveolar_lateral_click.ogg'),

    // ── Voiced Implosives ─────────────────────────────────────────────────
    IpaSound(symbol: 'ɓ', name: 'voiced bilabial implosive', type: IpaSoundType.consonant, manner: Manner.implosive, place: Place.bilabial, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_bilabial_implosive.ogg'),
    IpaSound(symbol: 'ɗ', name: 'voiced alveolar implosive', type: IpaSoundType.consonant, manner: Manner.implosive, place: Place.alveolar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_alveolar_implosive.ogg'),
    IpaSound(symbol: 'ʄ', name: 'voiced palatal implosive', type: IpaSoundType.consonant, manner: Manner.implosive, place: Place.palatal, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_palatal_implosive.ogg'),
    IpaSound(symbol: 'ɠ', name: 'voiced velar implosive', type: IpaSoundType.consonant, manner: Manner.implosive, place: Place.velar, voiced: true, audioAssetPath: 'assets/ipa_audio/voiced_velar_implosive.ogg'),
    IpaSound(symbol: 'ʛ', name: 'voiced uvular implosive', type: IpaSoundType.consonant, manner: Manner.implosive, place: Place.uvular, voiced: true, audioAssetPath: null),

    // ── Ejectives ─────────────────────────────────────────────────────────
    IpaSound(symbol: 'pʼ', name: 'bilabial ejective', type: IpaSoundType.consonant, manner: Manner.ejective, place: Place.bilabial, voiced: false, audioAssetPath: null),
    IpaSound(symbol: 'tʼ', name: 'alveolar ejective', type: IpaSoundType.consonant, manner: Manner.ejective, place: Place.alveolar, voiced: false, audioAssetPath: null),
    IpaSound(symbol: 'kʼ', name: 'velar ejective', type: IpaSoundType.consonant, manner: Manner.ejective, place: Place.velar, voiced: false, audioAssetPath: null),
    IpaSound(symbol: 'sʼ', name: 'alveolar ejective fricative', type: IpaSoundType.consonant, manner: Manner.ejective, place: Place.alveolar, voiced: false, audioAssetPath: null),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // SUPRASEGMENTALS
  // ─────────────────────────────────────────────────────────────────────────

  /// Common suprasegmentals and tone diacritics.
  static const List<({String symbol, String name})> suprasegmentals = [
    (symbol: 'ˈ', name: 'primary stress'),
    (symbol: 'ˌ', name: 'secondary stress'),
    (symbol: 'ː', name: 'long'),
    (symbol: 'ˑ', name: 'half-long'),
    (symbol: '̆', name: 'extra-short'),
    (symbol: '.', name: 'syllable break'),
    (symbol: '|', name: 'minor group'),
    (symbol: '‖', name: 'major group'),
    (symbol: '‿', name: 'linking (absence of a break)'),
    // Tones
    (symbol: '˥', name: 'extra high tone'),
    (symbol: '˦', name: 'high tone'),
    (symbol: '˧', name: 'mid tone'),
    (symbol: '˨', name: 'low tone'),
    (symbol: '˩', name: 'extra low tone'),
    (symbol: '↗', name: 'upstep'),
    (symbol: '↘', name: 'downstep'),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// All sounds combined.
  static List<IpaSound> get allSounds =>
      [...pulmonicConsonants, ...vowels, ...nonPulmonicConsonants];

  /// Consonants grouped by manner and place for chart rendering.
  static Map<Manner, Map<Place, List<IpaSound>>> get pulmonicByMannerAndPlace {
    final result = <Manner, Map<Place, List<IpaSound>>>{};
    for (final sound in pulmonicConsonants) {
      final manner = sound.manner!;
      final place = sound.place!;
      result.putIfAbsent(manner, () => {})[place] ??= [];
      result[manner]![place]!.add(sound);
    }
    return result;
  }

  /// Vowels grouped by height and backness.
  static Map<VowelHeight, Map<VowelBackness, List<IpaSound>>>
      get vowelsByHeightAndBackness {
    final result = <VowelHeight, Map<VowelBackness, List<IpaSound>>>{};
    for (final sound in vowels) {
      final height = sound.height!;
      final backness = sound.backness!;
      result.putIfAbsent(height, () => {})[backness] ??= [];
      result[height]![backness]!.add(sound);
    }
    return result;
  }
}
