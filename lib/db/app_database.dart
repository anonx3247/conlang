import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  ],
  daos: [PhonemeDao, NaturalClassDao, RomanizationDao, PhonotacticDao, RewriteRuleDao],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase with an injected [QueryExecutor].
  ///
  /// The executor is typically a [LazyDatabase] wrapping a [driftDatabase]
  /// (drift_flutter) pointing to `{projectDir}/project.db`.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

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
      },
      beforeOpen: (details) async {
        // Enable foreign key enforcement for every connection.
        await customStatement('PRAGMA foreign_keys = ON');
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
