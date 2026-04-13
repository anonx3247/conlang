import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'phonotactic_dao.g.dart';

/// Drift DAO for CRUD operations on the [PhonotacticTemplates] and
/// [PhonotacticConstraints] tables.
///
/// Obtain via `currentDatabase.phonotacticDao` or the Riverpod
/// [phonotacticDaoProvider] which derives it from the active project database.
@DriftAccessor(tables: [PhonotacticTemplates, PhonotacticConstraints])
class PhonotacticDao extends DatabaseAccessor<AppDatabase>
    with _$PhonotacticDaoMixin {
  PhonotacticDao(super.db);

  // ---------------------------------------------------------------------------
  // Template — reactive streams
  // ---------------------------------------------------------------------------

  /// Watches all templates, ordered by id (insertion order).
  Stream<List<PhonotacticTemplate>> watchAllTemplates() =>
      (select(phonotacticTemplates)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// Watches only active templates.
  Stream<List<PhonotacticTemplate>> watchActiveTemplates() =>
      (select(phonotacticTemplates)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  // ---------------------------------------------------------------------------
  // Template — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new template and returns its generated row ID.
  Future<int> insertTemplate(PhonotacticTemplatesCompanion companion) =>
      into(phonotacticTemplates).insert(companion);

  /// Updates all fields of an existing template row.
  Future<bool> updateTemplate(PhonotacticTemplate template) =>
      update(phonotacticTemplates).replace(template);

  /// Deletes the template with the given [id].
  Future<int> deleteTemplate(int id) =>
      (delete(phonotacticTemplates)..where((t) => t.id.equals(id))).go();

  /// Toggles the active state of a template.
  Future<void> toggleTemplateActive(int id, {required bool active}) async {
    await (update(phonotacticTemplates)..where((t) => t.id.equals(id)))
        .write(PhonotacticTemplatesCompanion(isActive: Value(active)));
  }

  // ---------------------------------------------------------------------------
  // Constraint — reactive streams
  // ---------------------------------------------------------------------------

  /// Watches all constraint rules, ordered by id (insertion order).
  Stream<List<PhonotacticConstraint>> watchAllConstraints() =>
      (select(phonotacticConstraints)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// Watches only active constraint rules.
  Stream<List<PhonotacticConstraint>> watchActiveConstraints() =>
      (select(phonotacticConstraints)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  // ---------------------------------------------------------------------------
  // Constraint — CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a new constraint rule and returns its generated row ID.
  Future<int> insertConstraint(PhonotacticConstraintsCompanion companion) =>
      into(phonotacticConstraints).insert(companion);

  /// Updates all fields of an existing constraint rule row.
  Future<bool> updateConstraint(PhonotacticConstraint constraint) =>
      update(phonotacticConstraints).replace(constraint);

  /// Deletes the constraint with the given [id].
  Future<int> deleteConstraint(int id) =>
      (delete(phonotacticConstraints)..where((t) => t.id.equals(id))).go();

  /// Toggles the active state of a constraint rule.
  Future<void> toggleConstraintActive(int id, {required bool active}) async {
    await (update(phonotacticConstraints)..where((t) => t.id.equals(id)))
        .write(PhonotacticConstraintsCompanion(isActive: Value(active)));
  }

  // ---------------------------------------------------------------------------
  // Gemination convenience methods
  // ---------------------------------------------------------------------------

  /// Inserts a gemination constraint row with [type] = 'gemination'.
  ///
  /// [dslPattern] is the serialized `!GG` or `!GG/pos` source string.
  /// [positions] is the comma-separated position string (from
  /// [serializeGeminationPositions]).
  /// [description] is an optional human-readable label.
  Future<int> insertGeminationConstraint({
    required String dslPattern,
    required String positions,
    String? description,
  }) =>
      into(phonotacticConstraints).insert(
        PhonotacticConstraintsCompanion.insert(
          pattern: dslPattern,
          description: Value(description),
          position: Value(positions),
          type: const Value('gemination'),
        ),
      );

  /// Returns the number of existing gemination constraints (type = 'gemination').
  ///
  /// Used to enforce the one-gemination-constraint-per-project rule.
  Future<int> countGeminationConstraints() async {
    final count = phonotacticConstraints.id.count();
    final query = selectOnly(phonotacticConstraints)
      ..addColumns([count])
      ..where(phonotacticConstraints.type.equals('gemination'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
