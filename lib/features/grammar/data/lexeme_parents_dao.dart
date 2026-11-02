import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'lexeme_parents_dao.g.dart';

/// Drift DAO for the `lexeme_parents` junction table (Phase 4 gap D-62).
///
/// Stores manual parent/etymology links between lexemes. Distinct from
/// rule-linked derivations (`Lexemes.derivedFromLexemeId` +
/// `Lexemes.derivedViaRuleId`, plan 04-12 Task 2): a lexeme can have
/// BOTH an auto-derived-via-rule parent AND additional manual parents
/// in this table for mixed etymologies (e.g. a compound word built from
/// two roots).
///
/// The composite primary key `(childLexemeId, parentLexemeId)` prevents
/// duplicate link rows; `insertParent` uses `InsertMode.insertOrIgnore`
/// so repeated inserts are harmless no-ops.
///
/// See plan `.planning/phases/04-grammar-morphology-revised/04-12-PLAN.md`.
@DriftAccessor(tables: [LexemeParents])
class LexemeParentsDao extends DatabaseAccessor<AppDatabase>
    with _$LexemeParentsDaoMixin {
  LexemeParentsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive queries
  // ---------------------------------------------------------------------------

  /// Streams the parents of [childLexemeId], ordered by parent id ascending.
  Stream<List<LexemeParentRow>> watchParentsForChild(int childLexemeId) {
    return (select(lexemeParents)
          ..where((t) => t.childLexemeId.equals(childLexemeId))
          ..orderBy([(t) => OrderingTerm.asc(t.parentLexemeId)]))
        .watch();
  }

  /// Streams the children of [parentLexemeId], ordered by child id ascending.
  Stream<List<LexemeParentRow>> watchChildrenForParent(int parentLexemeId) {
    return (select(lexemeParents)
          ..where((t) => t.parentLexemeId.equals(parentLexemeId))
          ..orderBy([(t) => OrderingTerm.asc(t.childLexemeId)]))
        .watch();
  }

  /// Streams ALL parent link rows across all lexemes. Used by
  /// [ancestryChainProvider] to react when any parent link changes
  /// anywhere in the lexicon (not just the current word's direct parents).
  Stream<List<LexemeParentRow>> watchAllParentLinks() {
    return select(lexemeParents).watch();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Inserts a parent link for [childLexemeId] -> [parentLexemeId].
  ///
  /// Uses `InsertMode.insertOrIgnore` so a duplicate pair is a silent
  /// no-op rather than an error — callers may insert idempotently.
  Future<void> insertParent({
    required int childLexemeId,
    required int parentLexemeId,
    String? relationship,
    String? notes,
  }) {
    return into(lexemeParents).insert(
      LexemeParentsCompanion.insert(
        childLexemeId: childLexemeId,
        parentLexemeId: parentLexemeId,
        relationship: Value(relationship),
        notes: Value(notes),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Updates the [relationship] and [notes] on an existing link.
  ///
  /// Only columns explicitly provided are written; omitted parameters leave
  /// the existing column value unchanged (`Value.absent()`). Pass
  /// [clearRelationship] or [clearNotes] as `true` to explicitly set a
  /// column to NULL rather than leaving it untouched.
  ///
  /// Silently does nothing when no row matches — callers should
  /// combine with [insertParent] (upsert) if they want to guarantee a
  /// row exists afterwards.
  Future<void> updateParent({
    required int childLexemeId,
    required int parentLexemeId,
    String? relationship,
    String? notes,
    bool clearRelationship = false,
    bool clearNotes = false,
  }) {
    return (update(lexemeParents)
          ..where((t) =>
              t.childLexemeId.equals(childLexemeId) &
              t.parentLexemeId.equals(parentLexemeId)))
        .write(LexemeParentsCompanion(
      relationship: relationship != null
          ? Value(relationship)
          : (clearRelationship ? const Value(null) : const Value.absent()),
      notes: notes != null
          ? Value(notes)
          : (clearNotes ? const Value(null) : const Value.absent()),
    ));
  }

  /// Deletes a single (child, parent) link. Returns the number of rows
  /// removed (0 or 1 — the composite PK guarantees uniqueness).
  Future<int> deleteParent({
    required int childLexemeId,
    required int parentLexemeId,
  }) {
    return (delete(lexemeParents)
          ..where((t) =>
              t.childLexemeId.equals(childLexemeId) &
              t.parentLexemeId.equals(parentLexemeId)))
        .go();
  }
}
