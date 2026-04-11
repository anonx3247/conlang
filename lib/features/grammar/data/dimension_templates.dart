// lib/features/grammar/data/dimension_templates.dart
//
// Hardcoded template catalog for the Phase 4 grammar "Add Dimension" picker.
// Same pattern as Phase 3.2 default_natural_classes.dart — const data ships
// with the app, NOT seeded into the database. Users pick a template in the
// UI and it's inserted into their project as an editable Dimension instance.
//
// See Phase 4 CONTEXT.md D-03 (rich catalog) and D-04 (each entry has a
// plain-text tooltip description).

import '../domain/dimension_level.dart';

/// A pickable dimension template. The user selects one in the "Add Dimension"
/// modal and it becomes an editable instance on the chosen POS (levels can
/// then be added, removed, or edited).
class DimensionTemplate {
  const DimensionTemplate({
    required this.id,
    required this.group,
    required this.name,
    required this.levels,
    required this.description,
  });

  /// Stable machine id (e.g. `gender.mf`). Unique across the catalog.
  final String id;

  /// Feature group for UI grouping — one of: Gender, Number, Case, Tense,
  /// Aspect, Person, Mood, Voice, Definiteness.
  final String group;

  /// Display label.
  final String name;

  /// Pre-filled level list. Level ids are 1-based and unique within this
  /// template.
  final List<DimensionLevel> levels;

  /// Plain-text tooltip shown next to the template in the picker.
  final String description;
}

const dimensionTemplates = <DimensionTemplate>[
  // ---- Gender ------------------------------------------------------------
  DimensionTemplate(
    id: 'gender.mf',
    group: 'Gender',
    name: 'Masculine / Feminine',
    levels: [
      DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
      DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
    ],
    description: 'Two-gender system distinguishing masculine and feminine. '
        'Common in Romance languages (Spanish, French, Italian).',
  ),
  DimensionTemplate(
    id: 'gender.mfn',
    group: 'Gender',
    name: 'Masculine / Feminine / Neuter',
    levels: [
      DimensionLevel(id: 1, name: 'Masculine', abbr: 'M', ordering: 0),
      DimensionLevel(id: 2, name: 'Feminine', abbr: 'F', ordering: 1),
      DimensionLevel(id: 3, name: 'Neuter', abbr: 'N', ordering: 2),
    ],
    description: 'Three-gender system distinguishing masculine, feminine, and '
        'neuter. Common in Indo-European languages (German, Latin, Russian).',
  ),
  DimensionTemplate(
    id: 'gender.anim_inanim',
    group: 'Gender',
    name: 'Animate / Inanimate',
    levels: [
      DimensionLevel(id: 1, name: 'Animate', abbr: 'ANIM', ordering: 0),
      DimensionLevel(id: 2, name: 'Inanimate', abbr: 'INAN', ordering: 1),
    ],
    description: 'Noun class system based on animacy. Common in Algonquian '
        'languages and in some Slavic gender subsystems.',
  ),
  DimensionTemplate(
    id: 'gender.common_neuter',
    group: 'Gender',
    name: 'Common / Neuter',
    levels: [
      DimensionLevel(id: 1, name: 'Common', abbr: 'C', ordering: 0),
      DimensionLevel(id: 2, name: 'Neuter', abbr: 'N', ordering: 1),
    ],
    description: 'Two-gender system merging masculine and feminine into '
        '"common" vs neuter. Found in Swedish, Danish, Dutch.',
  ),

  // ---- Number ------------------------------------------------------------
  DimensionTemplate(
    id: 'number.sg_pl',
    group: 'Number',
    name: 'Singular / Plural',
    levels: [
      DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
      DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
    ],
    description: 'Two-number system: one vs more than one. The most common '
        'number system worldwide.',
  ),
  DimensionTemplate(
    id: 'number.sg_du_pl',
    group: 'Number',
    name: 'Singular / Dual / Plural',
    levels: [
      DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
      DimensionLevel(id: 2, name: 'Dual', abbr: 'DU', ordering: 1),
      DimensionLevel(id: 3, name: 'Plural', abbr: 'PL', ordering: 2),
    ],
    description: 'Three-number system with a separate form for exactly two. '
        'Found in Arabic, Ancient Greek, and Slovene.',
  ),
  DimensionTemplate(
    id: 'number.sg_pl_coll',
    group: 'Number',
    name: 'Singular / Plural / Collective',
    levels: [
      DimensionLevel(id: 1, name: 'Singular', abbr: 'SG', ordering: 0),
      DimensionLevel(id: 2, name: 'Plural', abbr: 'PL', ordering: 1),
      DimensionLevel(id: 3, name: 'Collective', abbr: 'COLL', ordering: 2),
    ],
    description: 'Number system including a collective form referring to a '
        'group as an undifferentiated whole (e.g. "cattle").',
  ),

  // ---- Case --------------------------------------------------------------
  DimensionTemplate(
    id: 'case.nom_acc_gen_dat',
    group: 'Case',
    name: 'NOM / ACC / GEN / DAT (basic accusative)',
    levels: [
      DimensionLevel(id: 1, name: 'Nominative', abbr: 'NOM', ordering: 0),
      DimensionLevel(id: 2, name: 'Accusative', abbr: 'ACC', ordering: 1),
      DimensionLevel(id: 3, name: 'Genitive', abbr: 'GEN', ordering: 2),
      DimensionLevel(id: 4, name: 'Dative', abbr: 'DAT', ordering: 3),
    ],
    description:
        'Four-case nominative-accusative system: subject, object, possessor, '
        'recipient. Core of German and Russian inflection.',
  ),
  DimensionTemplate(
    id: 'case.abs_erg_gen_dat',
    group: 'Case',
    name: 'ABS / ERG / GEN / DAT (basic ergative)',
    levels: [
      DimensionLevel(id: 1, name: 'Absolutive', abbr: 'ABS', ordering: 0),
      DimensionLevel(id: 2, name: 'Ergative', abbr: 'ERG', ordering: 1),
      DimensionLevel(id: 3, name: 'Genitive', abbr: 'GEN', ordering: 2),
      DimensionLevel(id: 4, name: 'Dative', abbr: 'DAT', ordering: 3),
    ],
    description:
        'Four-case ergative-absolutive system: absolutive marks the subject '
        'of intransitive verbs and the object of transitive verbs; ergative '
        'marks the agent of a transitive verb.',
  ),
  DimensionTemplate(
    id: 'case.latin_like',
    group: 'Case',
    name: 'Latin-style (NOM/ACC/GEN/DAT/ABL/LOC/INSTR)',
    levels: [
      DimensionLevel(id: 1, name: 'Nominative', abbr: 'NOM', ordering: 0),
      DimensionLevel(id: 2, name: 'Accusative', abbr: 'ACC', ordering: 1),
      DimensionLevel(id: 3, name: 'Genitive', abbr: 'GEN', ordering: 2),
      DimensionLevel(id: 4, name: 'Dative', abbr: 'DAT', ordering: 3),
      DimensionLevel(id: 5, name: 'Ablative', abbr: 'ABL', ordering: 4),
      DimensionLevel(id: 6, name: 'Locative', abbr: 'LOC', ordering: 5),
      DimensionLevel(id: 7, name: 'Instrumental', abbr: 'INS', ordering: 6),
    ],
    description: 'Rich seven-case system covering spatial, instrumental, and '
        'grammatical roles. Found in Latin, Sanskrit, and many Slavic '
        'languages.',
  ),

  // ---- Tense -------------------------------------------------------------
  DimensionTemplate(
    id: 'tense.prs_pst',
    group: 'Tense',
    name: 'Present / Past',
    levels: [
      DimensionLevel(id: 1, name: 'Present', abbr: 'PRS', ordering: 0),
      DimensionLevel(id: 2, name: 'Past', abbr: 'PST', ordering: 1),
    ],
    description: 'Two-tense system (present vs past). Future is often '
        'expressed analytically with an auxiliary. Found in English.',
  ),
  DimensionTemplate(
    id: 'tense.prs_pst_fut',
    group: 'Tense',
    name: 'Present / Past / Future',
    levels: [
      DimensionLevel(id: 1, name: 'Present', abbr: 'PRS', ordering: 0),
      DimensionLevel(id: 2, name: 'Past', abbr: 'PST', ordering: 1),
      DimensionLevel(id: 3, name: 'Future', abbr: 'FUT', ordering: 2),
    ],
    description: 'Three-tense system. Found in Latin, French, Spanish, and '
        'many other Romance and Slavic languages.',
  ),
  DimensionTemplate(
    id: 'tense.nonfut_fut',
    group: 'Tense',
    name: 'Non-future / Future',
    levels: [
      DimensionLevel(id: 1, name: 'Non-future', abbr: 'NFUT', ordering: 0),
      DimensionLevel(id: 2, name: 'Future', abbr: 'FUT', ordering: 1),
    ],
    description:
        'Two-tense system distinguishing future from everything else. Common '
        'in Australian Aboriginal languages and some Papuan languages.',
  ),

  // ---- Aspect ------------------------------------------------------------
  DimensionTemplate(
    id: 'aspect.pfv_ipfv',
    group: 'Aspect',
    name: 'Perfective / Imperfective',
    levels: [
      DimensionLevel(id: 1, name: 'Perfective', abbr: 'PFV', ordering: 0),
      DimensionLevel(id: 2, name: 'Imperfective', abbr: 'IPFV', ordering: 1),
    ],
    description:
        'Binary aspectual distinction: completed whole action vs ongoing or '
        'repeated action. Core to Slavic verb morphology.',
  ),
  DimensionTemplate(
    id: 'aspect.prog_hab_perf',
    group: 'Aspect',
    name: 'Progressive / Habitual / Perfect',
    levels: [
      DimensionLevel(id: 1, name: 'Progressive', abbr: 'PROG', ordering: 0),
      DimensionLevel(id: 2, name: 'Habitual', abbr: 'HAB', ordering: 1),
      DimensionLevel(id: 3, name: 'Perfect', abbr: 'PRF', ordering: 2),
    ],
    description: 'Three-way aspectual system: ongoing action, customary '
        'action, completed action with current relevance.',
  ),

  // ---- Person ------------------------------------------------------------
  DimensionTemplate(
    id: 'person.1_2_3',
    group: 'Person',
    name: '1st / 2nd / 3rd',
    levels: [
      DimensionLevel(id: 1, name: 'First', abbr: '1', ordering: 0),
      DimensionLevel(id: 2, name: 'Second', abbr: '2', ordering: 1),
      DimensionLevel(id: 3, name: 'Third', abbr: '3', ordering: 2),
    ],
    description:
        'Standard three-way person distinction: speaker, addressee, other.',
  ),
  DimensionTemplate(
    id: 'person.incl_excl',
    group: 'Person',
    name: '1 INCL / 1 EXCL / 2 / 3',
    levels: [
      DimensionLevel(id: 1, name: 'First inclusive', abbr: '1INCL', ordering: 0),
      DimensionLevel(id: 2, name: 'First exclusive', abbr: '1EXCL', ordering: 1),
      DimensionLevel(id: 3, name: 'Second', abbr: '2', ordering: 2),
      DimensionLevel(id: 4, name: 'Third', abbr: '3', ordering: 3),
    ],
    description: 'Four-way person distinction including clusivity: first '
        'person inclusive includes the addressee, exclusive does not. Common '
        'in Austronesian and Dravidian languages.',
  ),

  // ---- Mood --------------------------------------------------------------
  DimensionTemplate(
    id: 'mood.ind_subj_imp',
    group: 'Mood',
    name: 'Indicative / Subjunctive / Imperative',
    levels: [
      DimensionLevel(id: 1, name: 'Indicative', abbr: 'IND', ordering: 0),
      DimensionLevel(id: 2, name: 'Subjunctive', abbr: 'SBJV', ordering: 1),
      DimensionLevel(id: 3, name: 'Imperative', abbr: 'IMP', ordering: 2),
    ],
    description: 'Three-mood system distinguishing factual statement, '
        'counterfactual / volitional, and direct command.',
  ),
  DimensionTemplate(
    id: 'mood.ind_opt_imp',
    group: 'Mood',
    name: 'Indicative / Optative / Imperative',
    levels: [
      DimensionLevel(id: 1, name: 'Indicative', abbr: 'IND', ordering: 0),
      DimensionLevel(id: 2, name: 'Optative', abbr: 'OPT', ordering: 1),
      DimensionLevel(id: 3, name: 'Imperative', abbr: 'IMP', ordering: 2),
    ],
    description: 'Three-mood system including an optative for wishes and '
        'hopes. Found in Ancient Greek and Sanskrit.',
  ),

  // ---- Voice -------------------------------------------------------------
  DimensionTemplate(
    id: 'voice.act_pass',
    group: 'Voice',
    name: 'Active / Passive',
    levels: [
      DimensionLevel(id: 1, name: 'Active', abbr: 'ACT', ordering: 0),
      DimensionLevel(id: 2, name: 'Passive', abbr: 'PASS', ordering: 1),
    ],
    description: 'Two-voice system contrasting the agent-as-subject active '
        'with the patient-as-subject passive.',
  ),
  DimensionTemplate(
    id: 'voice.act_mid_pass',
    group: 'Voice',
    name: 'Active / Middle / Passive',
    levels: [
      DimensionLevel(id: 1, name: 'Active', abbr: 'ACT', ordering: 0),
      DimensionLevel(id: 2, name: 'Middle', abbr: 'MID', ordering: 1),
      DimensionLevel(id: 3, name: 'Passive', abbr: 'PASS', ordering: 2),
    ],
    description:
        'Three-voice system with a middle voice for reflexive / self-affecting '
        'actions. Found in Ancient Greek and Sanskrit.',
  ),

  // ---- Definiteness ------------------------------------------------------
  DimensionTemplate(
    id: 'definiteness.def_indef',
    group: 'Definiteness',
    name: 'Definite / Indefinite',
    levels: [
      DimensionLevel(id: 1, name: 'Definite', abbr: 'DEF', ordering: 0),
      DimensionLevel(id: 2, name: 'Indefinite', abbr: 'INDEF', ordering: 1),
    ],
    description: 'Two-way definiteness system typically marked on the noun '
        '(e.g. Arabic, Swedish, Romanian) rather than with articles.',
  ),
];
