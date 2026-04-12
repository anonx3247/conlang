import 'package:drift/drift.dart';

import '../../../db/app_database.dart';

part 'culture_dao.g.dart';

@DriftAccessor(tables: [CulturePages])
class CultureDao extends DatabaseAccessor<AppDatabase> with _$CultureDaoMixin {
  CultureDao(super.db);

  // Watch root pages (parentId IS NULL), ordered by ordering
  Stream<List<CulturePage>> watchRootPages() {
    return (select(culturePages)
          ..where((t) => t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .watch();
  }

  // Watch children of a parent, ordered by ordering
  Stream<List<CulturePage>> watchChildren(int parentId) {
    return (select(culturePages)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.ordering)]))
        .watch();
  }

  // Watch all pages (for title -> id index used by wiki-link resolver)
  Stream<List<CulturePage>> watchAllPages() {
    return (select(culturePages)
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  // Get single page by id
  Future<CulturePage?> getPageById(int id) {
    return (select(culturePages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Watch single page by id
  Stream<CulturePage?> watchPageById(int id) {
    return (select(culturePages)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  // Create a new page. Returns the auto-generated id.
  Future<int> createPage({
    required String title,
    int? parentId,
    String content = '',
    String? icon,
    int ordering = 0,
  }) {
    final now = DateTime.now();
    return into(culturePages).insert(CulturePagesCompanion.insert(
      title: title,
      parentId: Value(parentId),
      content: Value(content),
      icon: Value(icon),
      ordering: Value(ordering),
      createdAt: now,
      updatedAt: now,
    ));
  }

  // Update page fields. Always bumps updatedAt.
  Future<void> updatePage(
    int id, {
    String? title,
    String? content,
    Value<String?>? icon,
  }) {
    final companion = CulturePagesCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      content: content != null ? Value(content) : const Value.absent(),
      icon: icon ?? const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    return (update(culturePages)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  // Delete a page. Children get parentId=null via onDelete: setNull.
  Future<void> deletePage(int id) {
    return (delete(culturePages)..where((t) => t.id.equals(id))).go();
  }

  // Reparent a page (drag-and-drop target change).
  // Updates parentId and ordering atomically.
  Future<void> reparentPage(int pageId, int? newParentId, int newOrdering) {
    return transaction(() async {
      await (update(culturePages)..where((t) => t.id.equals(pageId)))
          .write(CulturePagesCompanion(
        parentId: Value(newParentId),
        ordering: Value(newOrdering),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  // Reorder siblings: swap ordering values of two pages atomically.
  // Same pattern as morphology rule reordering (02-07 decision).
  Future<void> swapOrdering(
      int pageIdA, int orderingA, int pageIdB, int orderingB) {
    return transaction(() async {
      await (update(culturePages)..where((t) => t.id.equals(pageIdA)))
          .write(CulturePagesCompanion(ordering: Value(orderingB)));
      await (update(culturePages)..where((t) => t.id.equals(pageIdB)))
          .write(CulturePagesCompanion(ordering: Value(orderingA)));
    });
  }

  // Get max ordering among siblings (for appending new pages)
  Future<int> maxSiblingOrdering(int? parentId) async {
    final query = selectOnly(culturePages)
      ..addColumns([culturePages.ordering.max()]);
    if (parentId == null) {
      query.where(culturePages.parentId.isNull());
    } else {
      query.where(culturePages.parentId.equals(parentId));
    }
    final result = await query.getSingle();
    return result.read(culturePages.ordering.max()) ?? -1;
  }
}
