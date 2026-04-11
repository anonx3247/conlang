import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../features/grammar/data/grammar_dao.dart';
import '../features/grammar/data/inflectional_rule_pos_dao.dart';
import '../features/grammar/data/lexeme_parents_dao.dart';
import '../features/grammar/data/marker_dao.dart';
import '../features/grammar/data/paradigm_cell_override_dao.dart';
import '../features/grammar/domain/feature_bindings.dart';
import '../features/lexicon/data/lexeme_dao.dart';
import '../features/morphology/data/morphology_dao.dart';
import '../features/phonology/data/natural_class_dao.dart';
import '../features/phonology/data/phoneme_dao.dart';
import '../features/phonology/data/phonotactic_dao.dart';
import '../features/phonology/data/rewrite_rule_dao.dart';
import '../features/phonology/data/romanization_dao.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

/// IPA phoneme inventory for a project.
class Phonemes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get symbol => text()(); // IPA symbol, e.g. "p", "ɸ"
  TextColumn get type => text()(); // "consonant" | "vowel"

  // Consonant features (nullable — not applicable for vowels)
  TextColumn get manner => text().nullable()(); // e.g. "stop", "fricative"
  TextColumn get place => text().nullable()(); // e.g. "bilabial", "alveolar"
  TextColumn get voicing => text().nullable()(); // "voiced" | "voiceless"

  // Vowel features (nullable — not applicable for consonants)
  TextColumn get height => text().nullable()(); // "high" | "mid" | "low"
  TextColumn get backness => text().nullable()(); // "front" | "central" | "back"
  BoolColumn get rounded => boolean().nullable()();

  // Flexible extension slot (JSON object for future feature additions)
  TextColumn get customProperties => text().nullable()();
}

/// Natural phonological classes, e.g. "stops", "nasals", "obstruents".
///
/// [phonemeIds] is a JSON array of phoneme IDs (integers), e.g. "[1,2,3]".
class NaturalClasses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g. "stop", "nasal"
  TextColumn get phonemeIds => text()(); // JSON array of phoneme IDs
}

/// Syllable structure templates in a DSL string.
///
/// Example pattern: "(C)(C)V(C)" — items in parentheses are optional.
class PhonotacticTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text()(); // DSL string
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Phonological constraints/rules that modify or reject sequences.
///
/// Example pattern: "VN -> nasalised V" — vowel before nasal becomes nasalised.
class PhonotacticConstraints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text()(); // DSL string
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  /// Position constraint: 'anywhere' (default), 'start', 'end'.
  TextColumn get position => text().withDefault(const Constant('anywhere'))();
}

/// Maps an IPA symbol to a Latin romanization string.
class RomanizationMappings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ipaSymbol => text()();
  TextColumn get latinMapping => text()();
}

/// Phonological rewrite rules in SPE-style A -> B / C_D notation.
///
/// Example: "k -> x / V_V" (velar lenition between vowels).
/// The [source] column stores the raw DSL string verbatim for round-tripping.
/// [ordering] allows user-defined rule ordering (default 0 = insertion order).
class RewriteRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()(); // The raw DSL string, e.g. "k -> x / V_V"
  IntColumn get ordering => integer().withDefault(const Constant(0))();
}

/// Key-value store for project-level settings.
///
/// Example entries:
///  - key='romanization_enabled', value='true'
///
/// The [key] column has a unique constraint so upserts replace the old value.
class ProjectSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}

/// User-defined parts of speech (Noun, Verb, Adjective, etc.).
///
/// Used by morphological rules to restrict which words a rule applies to.
/// Will also be used in Phase 4 (Grammar) for declension/conjugation grouping.
class PartsOfSpeech extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g. "Noun", "Verb"
  TextColumn get abbreviation => text()(); // e.g. "N", "V", "ADJ"
}

/// Grammatical dimensions attached to a part of speech (Phase 4 D-01).
///
/// Each dimension represents one axis of grammatical variation for the POS
/// (e.g. "Gender", "Number", "Case"). The levels of the dimension
/// (e.g. Singular, Plural) are stored inline as a JSON array in [levelsJson]
/// rather than in a separate table — the "hybrid storage" shape from
/// CONTEXT.md D-01 / D-A6.
///
/// levelsJson format:
/// ```
/// [
///   {"id": 1, "name": "Singular", "abbr": "SG", "ordering": 0},
///   {"id": 2, "name": "Plural", "abbr": "PL", "ordering": 1}
/// ]
/// ```
/// Level ids are integers unique within this dimension row.
///
/// [templateId] is the catalog key of the dimension template used when this
/// dimension was first created (nullable; null means custom-from-scratch).
class Dimensions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get posId =>
      integer().references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get ordering => integer().withDefault(const Constant(0))();
  TextColumn get levelsJson => text()();
  TextColumn get templateId => text().nullable()();
}

/// Morphological rules (e.g. "Plural", "Agentive -er") in a pattern DSL.
///
/// [source] stores the raw DSL string verbatim for round-tripping.
/// [ordering] allows user-defined rule ordering (default 0 = insertion order).
/// [isActive] allows toggling a rule without deleting it.
/// [posId] optionally restricts this rule to a specific part of speech.
class MorphologicalRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g. "Plural", "Agentive -er"
  TextColumn get source => text()(); // Raw DSL string
  IntColumn get ordering => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get posId =>
      integer().nullable().references(PartsOfSpeech, #id)();
  /// Legacy v6 column. Comma-separated POS IDs (e.g. "1,3,5") — preserved
  /// for migration safety per Phase 4 research recommendation A9
  /// (keep-and-ignore). Do NOT write in v8+; replaced by [featureBindings]
  /// `{pos: [...]}`.
  TextColumn get posIds => text().withDefault(const Constant(''))();

  /// v8+ — Phase 4 CONTEXT.md D-17. 'inflectional' | 'derivational'.
  /// Default 'derivational' matches the v7→v8 silent reclassification (D-18).
  TextColumn get kind =>
      text().withDefault(const Constant('derivational'))();

  /// v8+ — Phase 4 CONTEXT.md D-09 / D-19. JSON of [FeatureBindings].
  TextColumn get featureBindings => text()
      .map(const FeatureBindingsConverter())
      .withDefault(const Constant('{}'))();

  /// v8+ — source POS for derivational rules (D-20). Nullable for inflectional.
  IntColumn get inputPosId =>
      integer().nullable().references(PartsOfSpeech, #id)();

  /// v8+ — output POS for derivational rules (D-20). Defaults to inputPosId on migration.
  IntColumn get outputPosId =>
      integer().nullable().references(PartsOfSpeech, #id)();

  /// v9+ — Phase 4 gap D-59. When true, the derivational rule automatically
  /// promotes every matching-POS word's derived form to a full Lexeme row with
  /// a templated gloss `"{parentLexeme.meaning} ({rule.name})"`. When false
  /// (default), the rule is a suggestion chip (D-60) in word detail UI.
  /// Unused for kind='inflectional' rows.
  BoolColumn get autoApply =>
      boolean().withDefault(const Constant(false))();
}

/// Per-lexeme exceptions overriding a morphological rule with an irregular form.
///
/// [lexemeId] is an FK to Lexemes; [ruleId] is an FK to MorphologicalRules.
/// [overrideForm] is the irregular surface form to use instead of the rule output.
/// [ruleSourceSnapshot] records the [MorphologicalRules.source] value at exception
/// creation time so stale exceptions can be detected when the rule is later edited.
class MorphologicalRuleExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lexemeId => integer()(); // FK to Lexemes
  IntColumn get ruleId => integer()(); // FK to MorphologicalRules
  TextColumn get overrideForm => text()(); // The irregular form
  TextColumn get ruleSourceSnapshot => text()(); // source at time of exception creation
}

/// Per-cell manual overrides in a paradigm table (Phase 4 D-22 / D-28 option B).
///
/// Keyed by `(lexemeId, featureSetJson)` — the feature set JSON identifies
/// exactly which paradigm cell (e.g. `{"5":2,"7":4}` = dim5=level2, dim7=level4).
/// This is cleaner than the sentinel-ruleId approach because a cell can be
/// overridden even when NO inflectional rule would have filled it (uncovered cells).
///
/// [overrideIpa] is the primary stored form. [overrideRomanization] is optional
/// and filled in when the user types romanization first (per D-28).
class ParadigmCellOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lexemeId =>
      integer().references(Lexemes, #id, onDelete: KeyAction.cascade)();
  TextColumn get featureSetJson => text()();
  TextColumn get overrideIpa => text()();
  TextColumn get overrideRomanization => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Unmarked-cell declarations for inflectional paradigms (Phase 4 gap D-44).
///
/// A marker asserts that a feature-binding set produces NO form change — the
/// root IS the form at that cell (standard zero-morpheme / zero-marker pattern
/// in natural languages). Parallel in shape to [MorphologicalRules] but:
///  - no DSL / no form output
///  - no [kind] column (all markers are inflectional-scoped)
///  - [featureBindings] reuses D-19's JSON format via FeatureBindingsConverter
///
/// Resolution order (D-45): per-word override -> inflectional rule -> marker
/// -> uncovered. Marker-vs-rule ties at identical specificity: rules win
/// (D-46) because rules carry an explicit form while markers assert absence.
class Markers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get posId =>
      integer().references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)();
  TextColumn get featureBindings => text()
      .map(const FeatureBindingsConverter())
      .withDefault(const Constant('{}'))();
}

/// Multi-POS junction for inflectional morphological rules (Phase 4 gap D-55).
///
/// A single inflectional rule can apply to multiple parts of speech (e.g. a
/// suffix that marks plural on both Noun and Adjective). Post-v9, the
/// legacy [MorphologicalRules.inputPosId] is no longer consulted for
/// `kind='inflectional'` rows — callers read the junction instead. The
/// legacy column is kept as a convenience cache but may be null-or-stale;
/// do not rely on it for inflectional rules in v9+.
///
/// Backfill on v9 migration: one row per existing inflectional
/// MorphologicalRules row using its current `input_pos_id` (derivational
/// rules are NOT backfilled per D-55).
@DataClassName('InflectionalRulePOSRow')
class InflectionalRulePOS extends Table {
  IntColumn get ruleId =>
      integer().references(MorphologicalRules, #id, onDelete: KeyAction.cascade)();
  IntColumn get posId =>
      integer().references(PartsOfSpeech, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {ruleId, posId};

  /// Drift's auto-snake converter mangles the all-caps "POS" suffix into
  /// `inflectional_rule_p_o_s`. Override the generated table name so that
  /// the migration SQL (`INSERT OR IGNORE INTO inflectional_rule_pos ...`)
  /// and the beforeOpen safety net (`CREATE TABLE IF NOT EXISTS
  /// inflectional_rule_pos ...`) match the physical table Drift creates.
  @override
  String get tableName => 'inflectional_rule_pos';
}

/// Manual parent/etymology links between lexemes (Phase 4 gap D-62).
///
/// Supports:
///  - Multiple parents per child (compounds: sun + flower -> sunflower)
///  - Optional free-text [relationship] label (e.g. "from", "via", "cognate with")
///  - Optional per-link [notes]
///  - Distinct from rule-linked derivations: [Lexemes.derivedFromLexemeId] +
///    [Lexemes.derivedViaRuleId] store the rule-linked case (D-57). A lexeme
///    can have BOTH an auto-derived-via-rule parent AND additional manual
///    parents in this table for mixed etymologies.
///
/// Tree queries (for the deferred etymology tree UI) walk the union of
/// rule-derived links and this table's manual links.
@DataClassName('LexemeParentRow')
class LexemeParents extends Table {
  IntColumn get childLexemeId =>
      integer().references(Lexemes, #id, onDelete: KeyAction.cascade)();
  IntColumn get parentLexemeId =>
      integer().references(Lexemes, #id, onDelete: KeyAction.cascade)();
  TextColumn get relationship => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {childLexemeId, parentLexemeId};
}

/// The lexeme table — supports derivation-aware morphology (Phase 2).
///
/// - [ipa]: the underlying IPA representation of the word
/// - [rootId]: optional FK to another lexeme that is the morphological root
///   (supports chained derivation; self-referential)
/// - [ruleIds]: JSON array of morphological rule IDs applied to the root
///   to produce this form (Phase 2)
/// - [computedForm]: cached result of applying [ruleIds] to the root IPA
///   (recomputed when rules change)
/// - [romanization]: the Latin form derived from [ipa] via romanization mappings
/// - [meaning]: plain-text gloss
/// - [partOfSpeech]: e.g. "noun", "verb", "adjective"
/// - [isPhonologicalException]: marks word as exempt from phonotactic violation
///   highlighting (e.g. loanwords) — added in schema v7
class Lexemes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ipa => text()();
  TextColumn get rootId => text().nullable()(); // ID as string for flexibility
  TextColumn get ruleIds => text().nullable()(); // JSON array
  TextColumn get computedForm => text().nullable()(); // derivation cache
  TextColumn get romanization => text().nullable()();
  TextColumn get meaning => text().nullable()();
  TextColumn get partOfSpeech => text().nullable()();
  /// Marks this word as exempt from phonotactic violation highlighting.
  /// Defaults to false. Added in schema v7.
  BoolColumn get isPhonologicalException =>
      boolean().withDefault(const Constant(false))();

  /// Phase 4 D-07 — per-word dimension opt-out. JSON array of dimension ids
  /// this word explicitly skips (e.g. mass nouns skip number). Null = no skips.
  /// Added in schema v8.
  TextColumn get skippedDimensionsJson => text().nullable()();

  /// v9+ — Phase 4 gap D-57. Parent lexeme id for rule-linked derivations.
  /// NULL for root words and for lexemes linked only via [LexemeParents].
  /// When non-null and [derivedViaRuleId] is also non-null, this row is a
  /// "promoted derivation" (D-57, D-58): its display form is computed at
  /// render time from the rule + parent unless rom/ipa have been explicitly
  /// edited (which nulls derivedViaRuleId — the implicit detach gesture).
  IntColumn get derivedFromLexemeId =>
      integer().nullable().references(Lexemes, #id)();

  /// v9+ — Phase 4 gap D-57 / D-58. The derivational rule that produces
  /// this lexeme's form from its [derivedFromLexemeId] parent. NULL means
  /// either: (a) this is a root word, (b) this is a manual-parent-only
  /// derivation, or (c) the user edited rom/ipa and implicitly detached
  /// from the rule.
  IntColumn get derivedViaRuleId =>
      integer().nullable().references(MorphologicalRules, #id)();

  /// v9+ — Phase 4 gap D-63. When true, this lexeme is rendered in muted
  /// gray in the main Dictionary sidebar list (NOT hidden — still findable
  /// via search, still present in Swadesh/Thesaurus, still openable for
  /// editing). Signals "this root only exists through its derivations" —
  /// e.g. a bound root that never surfaces as a standalone word.
  BoolColumn get rootOnlyViaDerivations =>
      boolean().withDefault(const Constant(false))();
}

// ---------------------------------------------------------------------------
// Database class
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Phonemes,
    NaturalClasses,
    PhonotacticTemplates,
    PhonotacticConstraints,
    RomanizationMappings,
    Lexemes,
    RewriteRules,
    ProjectSettings,
    PartsOfSpeech,
    MorphologicalRules,
    MorphologicalRuleExceptions,
    Dimensions,
    ParadigmCellOverrides,
    Markers, // v9
    InflectionalRulePOS, // v9
    LexemeParents, // v9
  ],
  daos: [
    PhonemeDao,
    NaturalClassDao,
    RomanizationDao,
    PhonotacticDao,
    RewriteRuleDao,
    MorphologyDao,
    LexemeDao,
    GrammarDao,
    ParadigmCellOverrideDao,
    InflectionalRulePOSDao, // v9 gap D-55
    LexemeParentsDao, // v9 gap D-62
    MarkerDao, // v9 gap D-44 (re-registered after 04-11 regression)
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase with an injected [QueryExecutor].
  ///
  /// The executor is typically a [LazyDatabase] wrapping a [driftDatabase]
  /// (drift_flutter) pointing to `{projectDir}/project.db`.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // v2: add rewrite_rules table
          await m.createTable(rewriteRules);
        }
        if (from < 3) {
          // v3: add project_settings table
          await m.createTable(projectSettings);
        }
        if (from < 4) {
          // v4: add morphological_rules and morphological_rule_exceptions tables
          await m.createTable(morphologicalRules);
          await m.createTable(morphologicalRuleExceptions);
        }
        if (from < 5) {
          // v5: add parts_of_speech table and posId FK on morphological_rules
          await m.createTable(partsOfSpeech);
          await m.addColumn(morphologicalRules, morphologicalRules.posId);
        }
        if (from < 6) {
          // v6: add posIds text column for multi-POS assignment
          await m.addColumn(morphologicalRules, morphologicalRules.posIds);
          // v6: add position column to phonotactic_constraints
          await m.addColumn(phonotacticConstraints, phonotacticConstraints.position);
        }
        if (from < 7) {
          // v7: add isPhonologicalException column to lexemes
          await m.addColumn(lexemes, lexemes.isPhonologicalException);
        }
        if (from < 8) {
          // v8: new Dimensions table for POS-dimensional feature systems (D-01, D-21)
          await m.createTable(dimensions);
          // v8: new ParadigmCellOverrides table for per-cell manual overrides (D-22)
          await m.createTable(paradigmCellOverrides);
          // v8: extend MorphologicalRules with kind, feature_bindings, input_pos_id, output_pos_id (D-17, D-19, D-20)
          await m.addColumn(morphologicalRules, morphologicalRules.kind);
          await m.addColumn(
              morphologicalRules, morphologicalRules.featureBindings);
          await m.addColumn(
              morphologicalRules, morphologicalRules.inputPosId);
          await m.addColumn(
              morphologicalRules, morphologicalRules.outputPosId);
          // v8: extend Lexemes with skippedDimensionsJson for per-word dim opt-out (D-07)
          await m.addColumn(lexemes, lexemes.skippedDimensionsJson);

          // Data migration (D-18): silently reclassify every existing rule
          // as derivational. Parse legacy pos_ids CSV → FeatureBindings(pos: [...]).
          //
          // Use raw SQL to read the legacy pos_ids column rather than the Drift
          // typed select API — at this point in the migration the row still has
          // the v7 shape, and Drift's generated row class is the v8 shape, so
          // querying via select(morphologicalRules) would attempt to read columns
          // that exist in code but may not be populated yet on legacy rows.
          final rows = await customSelect(
            'SELECT id, pos_ids FROM morphological_rules',
          ).get();
          for (final row in rows) {
            final ruleId = row.read<int>('id');
            final posIdsCsv = row.read<String>('pos_ids');
            final parsedPos = posIdsCsv.isEmpty
                ? const <int>[]
                : posIdsCsv
                    .split(',')
                    .map((s) => int.tryParse(s.trim()))
                    .whereType<int>()
                    .toList();
            final bindings = FeatureBindings(pos: parsedPos, dims: const {});
            final firstPos = parsedPos.isNotEmpty ? parsedPos.first : null;
            await (update(morphologicalRules)
                  ..where((t) => t.id.equals(ruleId)))
                .write(MorphologicalRulesCompanion(
              kind: const Value('derivational'),
              featureBindings: Value(bindings),
              inputPosId: Value(firstPos),
              outputPosId: Value(firstPos),
            ));
          }
        }
        if (from < 9) {
          // v9: Markers table for unmarked-cell declarations (D-44)
          await m.createTable(markers);
          // v9: InflectionalRulePOS junction for multi-POS inflectional rules (D-55)
          await m.createTable(inflectionalRulePOS);
          // v9: LexemeParents junction for manual etymology links (D-62)
          await m.createTable(lexemeParents);
          // v9: MorphologicalRules.autoApply for derivational auto-promote (D-59)
          await m.addColumn(morphologicalRules, morphologicalRules.autoApply);
          // v9: Lexemes promoted-derivation + root-only filter columns (D-57, D-58, D-63)
          await m.addColumn(lexemes, lexemes.derivedFromLexemeId);
          await m.addColumn(lexemes, lexemes.derivedViaRuleId);
          await m.addColumn(lexemes, lexemes.rootOnlyViaDerivations);

          // Backfill InflectionalRulePOS: one row per existing inflectional
          // rule using its current input_pos_id (D-55). Derivational rules are
          // NOT backfilled — the junction is scoped to inflectional per D-55.
          //
          // Uses raw customSelect rather than typed select to be robust
          // against any v8-row / v9-class shape mismatch during migration
          // (same pattern the v8 backfill used — see 04-01-SUMMARY.md
          // §Migration Data-Mutation Summary).
          final inflectionalRows = await customSelect(
            "SELECT id, input_pos_id FROM morphological_rules "
            "WHERE kind = 'inflectional' AND input_pos_id IS NOT NULL",
          ).get();
          for (final row in inflectionalRows) {
            final ruleId = row.read<int>('id');
            final posId = row.read<int>('input_pos_id');
            await customStatement(
              'INSERT OR IGNORE INTO inflectional_rule_pos (rule_id, pos_id) VALUES (?, ?)',
              [ruleId, posId],
            );
          }
        }
      },
      beforeOpen: (details) async {
        // Enable foreign key enforcement for every connection.
        await customStatement('PRAGMA foreign_keys = ON');

        // Safety net: ensure tables exist even if a prior hot-restart bumped
        // user_version without completing the migration.
        await customStatement(
          'CREATE TABLE IF NOT EXISTS rewrite_rules ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"source" TEXT NOT NULL, '
          '"ordering" INTEGER NOT NULL DEFAULT 0'
          ')',
        );
        await customStatement(
          'CREATE TABLE IF NOT EXISTS project_settings ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"key" TEXT NOT NULL UNIQUE, '
          '"value" TEXT NOT NULL'
          ')',
        );
        await customStatement(
          'CREATE TABLE IF NOT EXISTS morphological_rules ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL, '
          '"source" TEXT NOT NULL, '
          '"ordering" INTEGER NOT NULL DEFAULT 0, '
          '"is_active" INTEGER NOT NULL DEFAULT 1'
          ')',
        );
        await customStatement(
          'CREATE TABLE IF NOT EXISTS morphological_rule_exceptions ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"lexeme_id" INTEGER NOT NULL, '
          '"rule_id" INTEGER NOT NULL, '
          '"override_form" TEXT NOT NULL, '
          '"rule_source_snapshot" TEXT NOT NULL'
          ')',
        );
        await customStatement(
          'CREATE TABLE IF NOT EXISTS parts_of_speech ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"name" TEXT NOT NULL, '
          '"abbreviation" TEXT NOT NULL'
          ')',
        );
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"pos_id" INTEGER REFERENCES parts_of_speech(id)',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"pos_ids" TEXT NOT NULL DEFAULT \'\'',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE phonotactic_constraints ADD COLUMN '
            '"position" TEXT NOT NULL DEFAULT \'anywhere\'',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE lexemes ADD COLUMN '
            '"is_phonological_exception" INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
        // v8 safety net: new tables
        try {
          await customStatement(
            'CREATE TABLE IF NOT EXISTS dimensions ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
            '"name" TEXT NOT NULL, '
            '"ordering" INTEGER NOT NULL DEFAULT 0, '
            '"levels_json" TEXT NOT NULL, '
            '"template_id" TEXT'
            ')',
          );
        } catch (_) {}
        try {
          await customStatement(
            'CREATE TABLE IF NOT EXISTS paradigm_cell_overrides ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
            '"feature_set_json" TEXT NOT NULL, '
            '"override_ipa" TEXT NOT NULL, '
            '"override_romanization" TEXT, '
            '"notes" TEXT'
            ')',
          );
        } catch (_) {}
        // v8 safety net: new MorphologicalRules columns
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"kind" TEXT NOT NULL DEFAULT \'derivational\'',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\'',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"input_pos_id" INTEGER REFERENCES parts_of_speech(id)',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"output_pos_id" INTEGER REFERENCES parts_of_speech(id)',
          );
        } catch (_) {}
        // v8 safety net: Lexemes.skipped_dimensions_json
        try {
          await customStatement(
            'ALTER TABLE lexemes ADD COLUMN '
            '"skipped_dimensions_json" TEXT',
          );
        } catch (_) {}
        // v9 safety net: new tables
        try {
          await customStatement(
            'CREATE TABLE IF NOT EXISTS markers ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
            '"feature_bindings" TEXT NOT NULL DEFAULT \'{}\''
            ')',
          );
        } catch (_) {}
        try {
          await customStatement(
            'CREATE TABLE IF NOT EXISTS inflectional_rule_pos ('
            '"rule_id" INTEGER NOT NULL REFERENCES morphological_rules(id) ON DELETE CASCADE, '
            '"pos_id" INTEGER NOT NULL REFERENCES parts_of_speech(id) ON DELETE CASCADE, '
            'PRIMARY KEY ("rule_id", "pos_id")'
            ')',
          );
        } catch (_) {}
        try {
          await customStatement(
            'CREATE TABLE IF NOT EXISTS lexeme_parents ('
            '"child_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
            '"parent_lexeme_id" INTEGER NOT NULL REFERENCES lexemes(id) ON DELETE CASCADE, '
            '"relationship" TEXT, '
            '"notes" TEXT, '
            'PRIMARY KEY ("child_lexeme_id", "parent_lexeme_id")'
            ')',
          );
        } catch (_) {}
        // v9 safety net: MorphologicalRules.auto_apply
        try {
          await customStatement(
            'ALTER TABLE morphological_rules ADD COLUMN '
            '"auto_apply" INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
        // v9 safety net: Lexemes promoted-derivation + root-only columns
        try {
          await customStatement(
            'ALTER TABLE lexemes ADD COLUMN '
            '"derived_from_lexeme_id" INTEGER REFERENCES lexemes(id)',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE lexemes ADD COLUMN '
            '"derived_via_rule_id" INTEGER REFERENCES morphological_rules(id)',
          );
        } catch (_) {}
        try {
          await customStatement(
            'ALTER TABLE lexemes ADD COLUMN '
            '"root_only_via_derivations" INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      },
    );
  }

  /// Returns the [LexemeDao] for this database.
  LexemeDao get lexemeDao => LexemeDao(this);

  /// Factory that opens a Drift database backed by a file at [absolutePath].
  ///
  /// Use this from the Riverpod family provider. The [driftDatabase] call with
  /// a [DriftNativeOptions.databasePath] callback lets us put the database at
  /// any absolute path (e.g. `{appDocsDir}/conlang/{projectId}/project.db`).
  factory AppDatabase.fromPath(String absolutePath) {
    return AppDatabase(
      driftDatabase(
        name: 'project',
        native: DriftNativeOptions(
          databasePath: () async => absolutePath,
        ),
      ),
    );
  }
}
