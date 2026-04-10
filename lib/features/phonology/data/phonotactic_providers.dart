import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';
import '../domain/default_natural_classes.dart';
import '../domain/phonotactic_dsl.dart';
import '../domain/word_generator.dart';
import 'phoneme_providers.dart';
import 'phonotactic_dao.dart';
import 'rewrite_rule_dao.dart';

// ---------------------------------------------------------------------------
// DAO providers
// ---------------------------------------------------------------------------

/// Returns the [PhonotacticDao] for the currently open project database, or
/// null when no project is open.
///
/// Uses a plain [Provider] (not riverpod_generator) to avoid build_runner
/// type-traversal issues with Drift-generated types.
final phonotacticDaoProvider = Provider<PhonotacticDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.phonotacticDao;
});

/// Returns the [RewriteRuleDao] for the currently open project database, or
/// null when no project is open.
final rewriteRuleDaoProvider = Provider<RewriteRuleDao?>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  return db?.rewriteRuleDao;
});

// ---------------------------------------------------------------------------
// Rewrite rule providers
// ---------------------------------------------------------------------------

/// Watches all rewrite rules in the current project.
///
/// Emits an empty list when no project is open.
final rewriteRuleListProvider = StreamProvider<List<RewriteRule>>((ref) {
  final dao = ref.watch(rewriteRuleDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAll();
});

/// Parsed rewrite rules (only valid ones) for the word generator to apply.
final parsedRewriteRulesProvider = Provider<List<PhonologicalRewriteRule>>((ref) {
  final rulesAsync = ref.watch(rewriteRuleListProvider);
  final rules = rulesAsync.asData?.value ?? [];
  final parsed = <PhonologicalRewriteRule>[];
  for (final r in rules) {
    final p = parseRewriteRule(r.source);
    if (p.isValid && p.rule != null) parsed.add(p.rule!);
  }
  return parsed;
});

// ---------------------------------------------------------------------------
// Template providers
// ---------------------------------------------------------------------------

/// Watches all phonotactic templates in the current project.
///
/// Emits an empty list when no project is open.
final allTemplatesProvider = StreamProvider<List<PhonotacticTemplate>>((ref) {
  final dao = ref.watch(phonotacticDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllTemplates();
});

/// Watches only the active phonotactic templates.
///
/// Emits an empty list when no project is open.
final activeTemplatesProvider = StreamProvider<List<PhonotacticTemplate>>((ref) {
  final dao = ref.watch(phonotacticDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchActiveTemplates();
});

/// Parses the active template strings via the DSL parser.
///
/// Returns [AsyncValue<List<ParsedTemplate>>]. Invalid templates are included
/// with [ParsedTemplate.isValid] == false so the UI can show parse errors.
final parsedTemplatesProvider =
    StreamProvider<List<ParsedTemplate>>((ref) async* {
  final templatesAsync = ref.watch(activeTemplatesProvider);
  await for (final list in templatesAsync.when(
    data: (v) => Stream.value(v),
    loading: () => const Stream<List<PhonotacticTemplate>>.empty(),
    error: (_, e) => const Stream<List<PhonotacticTemplate>>.empty(),
  )) {
    yield list.map((t) => parseSyllableTemplate(t.pattern)).toList();
  }
});

// ---------------------------------------------------------------------------
// Constraint providers
// ---------------------------------------------------------------------------

/// Watches all phonotactic constraint rules in the current project.
final allConstraintsProvider =
    StreamProvider<List<PhonotacticConstraint>>((ref) {
  final dao = ref.watch(phonotacticDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchAllConstraints();
});

/// Watches only the active constraint rules.
final activeConstraintsProvider =
    StreamProvider<List<PhonotacticConstraint>>((ref) {
  final dao = ref.watch(phonotacticDaoProvider);
  if (dao == null) return Stream.value([]);
  return dao.watchActiveConstraints();
});

/// Parses the active constraint rule strings via the DSL parser.
///
/// Invalid constraints are silently skipped — they can't match anything.
final parsedConstraintsProvider =
    StreamProvider<List<ConstraintRule>>((ref) async* {
  final constraintsAsync = ref.watch(activeConstraintsProvider);
  await for (final list in constraintsAsync.when(
    data: (v) => Stream.value(v),
    loading: () => const Stream<List<PhonotacticConstraint>>.empty(),
    error: (_, e) => const Stream<List<PhonotacticConstraint>>.empty(),
  )) {
    yield list
        .map((c) {
          final parsed = parseConstraintRule(c.pattern);
          if (!parsed.isValid) return null;
          // Apply DB position to the parsed rule.
          final pos = switch (c.position) {
            'start' => ConstraintPosition.start,
            'end' => ConstraintPosition.end,
            _ => ConstraintPosition.anywhere,
          };
          return ConstraintRule(
            pattern: parsed.rule!.pattern,
            description: parsed.rule!.description,
            isForbidden: parsed.rule!.isForbidden,
            source: parsed.rule!.source,
            position: pos,
          );
        })
        .whereType<ConstraintRule>()
        .toList();
  }
});

// ---------------------------------------------------------------------------
// Inventory snapshot provider
// ---------------------------------------------------------------------------

/// Builds a [PhonemeInventory] snapshot from the current project's phoneme
/// inventory and natural classes. This is the input to the word generator.
///
/// Returns [PhonemeInventory.empty] when no project is open or inventory is
/// still loading.
final phonemeInventoryProvider = Provider<PhonemeInventory>((ref) {
  final consonants = ref.watch(consonantListProvider).when(
        data: (v) => v,
        loading: () => <Phoneme>[],
        error: (_, e) => <Phoneme>[],
      );
  final vowels = ref.watch(vowelListProvider).when(
        data: (v) => v,
        loading: () => <Phoneme>[],
        error: (_, e) => <Phoneme>[],
      );
  final classes = ref.watch(naturalClassListProvider).when(
        data: (v) => v,
        loading: () => <NaturalClassesData>[],
        error: (_, e) => <NaturalClassesData>[],
      );

  return buildInventory(consonants, vowels, classes);
});

/// Builds a [PhonemeInventory] from the raw DB rows.
///
/// Seeds `naturalClasses` with the nine predefined default classes
/// (see `default_natural_classes.dart`) BEFORE overlaying user-defined
/// classes, so every DSL consumer transparently resolves `[stop]`,
/// `[nasal]`, etc. even when the project defines no natural classes.
///
/// User-defined classes whose lowercased name collides with a default key
/// win — last write wins → D-06 precedence.
///
/// See RESEARCH.md F-1: this is THE load-bearing integration point for the
/// predefined-natural-classes feature. Patching `NaturalClassDao.resolveClass`
/// would be invisible to every actual DSL consumer (that method is dead code).
@visibleForTesting
PhonemeInventory buildInventory(
  List<Phoneme> consonants,
  List<Phoneme> vowels,
  List<NaturalClassesData> classes,
) {
  final allPhonemes = [...consonants, ...vowels];
  final idToSymbol = <int, String>{
    for (final p in allPhonemes) p.id: p.symbol,
  };

  // Seed with defaults (lowercased keys to match the existing convention).
  // User-defined classes overlay below — last write wins → user precedence (D-06).
  final naturalClassMap = <String, List<String>>{
    for (final entry in defaultNaturalClasses.entries)
      entry.key.toLowerCase(): List<String>.from(entry.value),
  };

  for (final cls in classes) {
    try {
      final decoded = jsonDecode(cls.phonemeIds);
      if (decoded is List) {
        final ids = decoded.whereType<int>().toList();
        final symbols = ids
            .map((id) => idToSymbol[id])
            .whereType<String>()
            .toList();
        naturalClassMap[cls.name.toLowerCase()] = symbols;
      }
    } catch (_) {
      // Malformed phonemeIds JSON — skip this class.
    }
  }

  return PhonemeInventory(
    consonants: consonants.map((p) => p.symbol).toList(),
    vowels: vowels.map((p) => p.symbol).toList(),
    naturalClasses: naturalClassMap,
  );
}

// ---------------------------------------------------------------------------
// Generated words provider
// ---------------------------------------------------------------------------

/// Generates sample IPA words from the current active templates and inventory.
///
/// Returns an empty list when no templates or no phonemes are defined.
/// Auto-refreshes whenever templates or the inventory changes.
final generatedWordsProvider = Provider<List<String>>((ref) {
  final templates = ref.watch(parsedTemplatesProvider).when(
        data: (v) => v,
        loading: () => <ParsedTemplate>[],
        error: (_, e) => <ParsedTemplate>[],
      );
  final inventory = ref.watch(phonemeInventoryProvider);

  return WordGenerator().generateWords(
    templates: templates,
    inventory: inventory,
    count: 20,
  );
});
