import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  /// Comma-separated POS IDs (e.g. "1,3,5") for multi-POS assignment.
  /// Null or empty = applies to all. Supersedes [posId] for filtering.
  TextColumn get posIds => text().withDefault(const Constant(''))();
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
class Lexemes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ipa => text()();
  TextColumn get rootId => text().nullable()(); // ID as string for flexibility
  TextColumn get ruleIds => text().nullable()(); // JSON array
  TextColumn get computedForm => text().nullable()(); // derivation cache
  TextColumn get romanization => text().nullable()();
  TextColumn get meaning => text().nullable()();
  TextColumn get partOfSpeech => text().nullable()();
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
  ],
  daos: [PhonemeDao, NaturalClassDao, RomanizationDao, PhonotacticDao, RewriteRuleDao, MorphologyDao],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase with an injected [QueryExecutor].
  ///
  /// The executor is typically a [LazyDatabase] wrapping a [driftDatabase]
  /// (drift_flutter) pointing to `{projectDir}/project.db`.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

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
        } catch (_) {
          // Column already exists — safe to ignore.
        }
      },
    );
  }

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
