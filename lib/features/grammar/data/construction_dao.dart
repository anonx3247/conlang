import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'construction_dao.g.dart';

/// DAO for [PhraseConstructions] and [ConstructionSlots] CRUD.
///
/// Phase 10 D-06: phrase constructions are ordered word-pattern rules
/// (e.g. "S V O") composed of typed slots (D-07). Each slot carries a
/// [slotType] ('pos' | 'gloss_tag') and a [slotValue].
@DriftAccessor(tables: [PhraseConstructions, ConstructionSlots])
class ConstructionDao extends DatabaseAccessor<AppDatabase>
    with _$ConstructionDaoMixin {
  ConstructionDao(super.db);

  // ---------------------------------------------------------------------------
  // PhraseConstructions
  // ---------------------------------------------------------------------------

  Stream<List<PhraseConstruction>> watchAll() =>
      (select(phraseConstructions)
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  Future<int> insertConstruction(PhraseConstructionsCompanion c) =>
      into(phraseConstructions).insert(c);

  Future<bool> updateConstruction(PhraseConstruction c) =>
      update(phraseConstructions).replace(c);

  Future<int> deleteConstruction(int id) =>
      (delete(phraseConstructions)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------------------------------
  // ConstructionSlots
  // ---------------------------------------------------------------------------

  Stream<List<ConstructionSlot>> watchSlotsFor(int constructionId) =>
      (select(constructionSlots)
            ..where((t) => t.constructionId.equals(constructionId))
            ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
          .watch();

  Future<int> insertSlot(ConstructionSlotsCompanion c) =>
      into(constructionSlots).insert(c);

  Future<bool> updateSlot(ConstructionSlot s) =>
      update(constructionSlots).replace(s);

  Future<int> deleteSlot(int id) =>
      (delete(constructionSlots)..where((t) => t.id.equals(id))).go();

  /// Reorders [slots] by assigning each slot's position index as its
  /// new [ordering] value. Performed atomically in a single batch.
  Future<void> reorderSlots(List<ConstructionSlot> slots) async {
    await batch((b) {
      for (var i = 0; i < slots.length; i++) {
        b.update(
          constructionSlots,
          ConstructionSlotsCompanion(ordering: Value(i)),
          where: (t) => t.id.equals(slots[i].id),
        );
      }
    });
  }
}
