import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../lexicon/data/lexeme_providers.dart';
import '../../morphology/data/morphology_providers.dart';
import '../../phonology/data/phonotactic_providers.dart'
    show phonemeInventoryProvider;
import '../../phonology/domain/word_generator.dart' show PhonemeInventory;
import '../../project/data/project_providers.dart';
import '../domain/dimension_level.dart';
import '../domain/inflectional_rule.dart';
import '../domain/paradigm_axes.dart';
import '../domain/paradigm_cell.dart';
import '../domain/paradigm_engine.dart';
import '../domain/pos_resolver.dart';
import 'grammar_providers.dart';

// ---------------------------------------------------------------------------
// Typology settings value type (D-35)
// ---------------------------------------------------------------------------

/// Plain value object for the three top-level typology fields. Persisted in
/// `project_settings` under keys `typology.alignment`, `typology.word_order`,
/// and `typology.modality`.
class TypologySettings {
  const TypologySettings({
    this.alignment,
    this.wordOrder,
    this.modality,
  });

  /// `'nom_acc'` | `'erg_abs'` | `'split'` | null
  final String? alignment;

  /// `'SVO'` | `'SOV'` | `'VSO'` | `'VOS'` | `'OVS'` | `'OSV'` | null
  final String? wordOrder;

  /// `'synthetic'` | `'analytic'` | `'mixed'` | null
  final String? modality;

  TypologySettings copyWith({
    String? alignment,
    String? wordOrder,
    String? modality,
  }) =>
      TypologySettings(
        alignment: alignment ?? this.alignment,
        wordOrder: wordOrder ?? this.wordOrder,
        modality: modality ?? this.modality,
      );

  @override
  bool operator ==(Object other) =>
      other is TypologySettings &&
      other.alignment == alignment &&
      other.wordOrder == wordOrder &&
      other.modality == modality;

  @override
  int get hashCode => Object.hash(alignment, wordOrder, modality);

  @override
  String toString() =>
      'TypologySettings(alignment: $alignment, wordOrder: $wordOrder, modality: $modality)';
}

// ---------------------------------------------------------------------------
// project_settings key constants
// ---------------------------------------------------------------------------

const String _kAlignmentKey = 'typology.alignment';
const String _kWordOrderKey = 'typology.word_order';
const String _kModalityKey = 'typology.modality';

String paradigmAxesKey(int posId) => 'typology.paradigm_axes.$posId';

// ---------------------------------------------------------------------------
// Pure-DB helpers (directly callable from tests + provider bodies)
// ---------------------------------------------------------------------------

/// Reads all three typology keys from [db.projectSettings] and returns a
/// [TypologySettings] with nulls for missing keys.
Future<TypologySettings> readTypologySettings(AppDatabase db) async {
  final rows = await db.select(db.projectSettings).get();
  String? lookup(String key) {
    for (final row in rows) {
      if (row.key == key) return row.value;
    }
    return null;
  }

  return TypologySettings(
    alignment: lookup(_kAlignmentKey),
    wordOrder: lookup(_kWordOrderKey),
    modality: lookup(_kModalityKey),
  );
}

/// Upserts a single typology key. Follows the update-then-insert pattern
/// from `romanization_providers.dart` because Drift's `insertOnConflictUpdate`
/// targets the primary key (`id`), not the unique `key` column, so a second
/// insert would create a duplicate row instead of replacing the existing one.
Future<void> writeTypologyKey(
  AppDatabase db,
  String key,
  String value,
) async {
  final updated = await (db.update(db.projectSettings)
        ..where((t) => t.key.equals(key)))
      .write(ProjectSettingsCompanion(value: Value(value)));
  if (updated == 0) {
    await db.into(db.projectSettings).insert(
          ProjectSettingsCompanion.insert(key: key, value: value),
        );
  }
}

/// Reads the paradigm axis config for a POS from `project_settings`. Returns
/// the stored value, or `ParadigmAxes.defaultsFor(dims)` when no row exists.
/// If no dimensions are available for the POS either, returns
/// `const ParadigmAxes()`.
Future<ParadigmAxes> readParadigmAxes(
  AppDatabase db, {
  required int posId,
}) async {
  final key = paradigmAxesKey(posId);
  final rows = await (db.select(db.projectSettings)
        ..where((t) => t.key.equals(key)))
      .get();
  if (rows.isNotEmpty) {
    return ParadigmAxes.fromJsonString(rows.first.value);
  }
  // Fall back to defaults derived from the POS's dimensions.
  final dims = await (db.select(db.dimensions)
        ..where((t) => t.posId.equals(posId))
        ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
      .get();
  return ParadigmAxes.defaultsFor(dims);
}

/// Upserts a paradigm axis config for a POS.
Future<void> writeParadigmAxes(
  AppDatabase db, {
  required int posId,
  required ParadigmAxes axes,
}) async {
  await writeTypologyKey(db, paradigmAxesKey(posId), axes.toJsonString());
}

// ---------------------------------------------------------------------------
// Pure-Dart paradigm chart generator
// ---------------------------------------------------------------------------

/// Cartesian product of dimension levels — yields one [FeatureSet] per
/// combination. Zero dimensions yields a single empty feature set (the
/// identity element). Dimensions whose levelsJson decodes to an empty
/// list contribute nothing and collapse the entire product to empty.
Iterable<FeatureSet> cartesianFeatureSets(List<Dimension> dims) sync* {
  if (dims.isEmpty) {
    yield <int, int>{};
    return;
  }
  final first = dims.first;
  final rest = dims.skip(1).toList();
  final firstLevels = decodeLevelsJson(first.levelsJson);
  if (firstLevels.isEmpty) return;
  for (final level in firstLevels) {
    for (final tail in cartesianFeatureSets(rest)) {
      yield {first.id: level.id, ...tail};
    }
  }
}

/// Stable string key for a [FeatureSet], usable as a Map key that survives
/// Dart's non-structural Map equality. Entries are sorted by dimension id
/// so the same feature set always produces the same key regardless of
/// insertion order.
///
/// Example: `{11:1, 10:2}` -> `"10:2,11:1"`.
String featureSetKey(FeatureSet featureSet) {
  final entries = featureSet.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}

/// One entry in a generated paradigm chart: the feature set identifying the
/// cell and the engine's result for it.
class ParadigmChartEntry {
  const ParadigmChartEntry({required this.featureSet, required this.cell});

  final FeatureSet featureSet;
  final ParadigmCell cell;
}

/// A full paradigm chart — the result of [generateParadigm]. Backed by a
/// stable string-keyed map so callers can look up cells by feature set
/// without depending on Dart's non-structural Map equality.
class ParadigmChart {
  ParadigmChart(this._entries);

  final Map<String, ParadigmChartEntry> _entries;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;
  Iterable<ParadigmChartEntry> get entries => _entries.values;

  /// Looks up the cell for a given feature set. Returns null when the cell
  /// is not in the chart (e.g. an axis was skipped or the dim was never
  /// part of the source dimensions).
  ParadigmCell? cellFor(FeatureSet featureSet) =>
      _entries[featureSetKey(featureSet)]?.cell;
}

/// Generates a full paradigm chart for [root] across the Cartesian product of
/// [dimensions] × [rules]. Honors [skippedDimensionIds] (D-07): any dimension
/// whose id is in the set is dropped from the expansion BEFORE the product
/// is computed, so its levels never appear as cell keys.
///
/// Returns an empty chart when every dimension is skipped or no active dims
/// exist.
ParadigmChart generateParadigm({
  required String root,
  required List<Dimension> dimensions,
  required List<InflectionalRule> rules,
  required PhonemeInventory inventory,
  Set<int> skippedDimensionIds = const {},
}) {
  final activeDims =
      dimensions.where((d) => !skippedDimensionIds.contains(d.id)).toList();
  if (activeDims.isEmpty) return ParadigmChart(const {});

  final entries = <String, ParadigmChartEntry>{};
  for (final featureSet in cartesianFeatureSets(activeDims)) {
    if (featureSet.isEmpty) continue;
    final cell = computeParadigmCell(
      root: root,
      target: featureSet,
      rules: rules,
      inventory: inventory,
    );
    entries[featureSetKey(featureSet)] =
        ParadigmChartEntry(featureSet: featureSet, cell: cell);
  }
  return ParadigmChart(entries);
}

/// Decodes a nullable [Lexemes.skippedDimensionsJson] value (a JSON array of
/// dimension ids) to a set. Returns an empty set on null / empty / malformed
/// input (defense in depth against hand-edited state, T-04-07 parallel).
Set<int> decodeSkippedDimensionIds(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const {};
    return decoded.whereType<int>().toSet();
  } on FormatException {
    return const {};
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Streams the current project's [TypologySettings]. Backed by a full
/// `project_settings` stream so updates to any key propagate reactively.
/// Matches the STATE 01-12 pattern used by `romanizationEnabledProvider`.
final typologySettingsProvider = StreamProvider<TypologySettings>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) {
    return Stream.value(const TypologySettings());
  }
  return db.select(db.projectSettings).watch().map((rows) {
    String? lookup(String key) {
      for (final row in rows) {
        if (row.key == key) return row.value;
      }
      return null;
    }

    return TypologySettings(
      alignment: lookup(_kAlignmentKey),
      wordOrder: lookup(_kWordOrderKey),
      modality: lookup(_kModalityKey),
    );
  });
});

/// Streams the paradigm axis config for a specific POS. Emits the default
/// axes (first two dims as rows+cols) when no row exists.
final paradigmAxesProvider =
    StreamProvider.family<ParadigmAxes, int>((ref, posId) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(const ParadigmAxes());
  final key = paradigmAxesKey(posId);
  return db.select(db.projectSettings).watch().asyncMap((rows) async {
    for (final row in rows) {
      if (row.key == key) return ParadigmAxes.fromJsonString(row.value);
    }
    // No stored axis config — derive defaults from the POS's dimensions.
    final dims = await (db.select(db.dimensions)
          ..where((t) => t.posId.equals(posId))
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .get();
    return ParadigmAxes.defaultsFor(dims);
  });
});

/// The computed paradigm chart for a single lexeme — Cartesian product of
/// the lexeme's POS dimensions (minus any per-word skipped dims) × the
/// feature-consumption engine, one cell per combination. Honors [D-07]
/// via the lexeme's `skippedDimensionsJson` column.
///
/// Keyed by lexemeId so Riverpod auto-caches per-word.
final computedInflectedParadigmProvider =
    Provider.family<ParadigmChart, int>((ref, lexemeId) {
  final lexemeAsync = ref.watch(lexemeByIdProvider(lexemeId));
  final lexeme = lexemeAsync.asData?.value;
  if (lexeme == null) return ParadigmChart(const {});

  final posListAsync = ref.watch(posListProvider);
  final posList =
      posListAsync.asData?.value ?? const <PartsOfSpeechData>[];
  final pos = posForLexeme(lexeme, posList);
  if (pos == null) return ParadigmChart(const {});

  final dimsAsync = ref.watch(dimensionsForPosProvider(pos.id));
  final dims = dimsAsync.asData?.value ?? const <Dimension>[];
  if (dims.isEmpty) return ParadigmChart(const {});

  final rulesAsync = ref.watch(inflectionalRulesForPosProvider(pos.id));
  final rules = rulesAsync.asData?.value ?? const <InflectionalRule>[];

  final inventory = ref.watch(phonemeInventoryProvider);

  return generateParadigm(
    root: lexeme.ipa,
    dimensions: dims,
    rules: rules,
    inventory: inventory,
    skippedDimensionIds:
        decodeSkippedDimensionIds(lexeme.skippedDimensionsJson),
  );
});
