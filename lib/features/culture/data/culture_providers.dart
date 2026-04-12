import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../../project/data/project_providers.dart';

// NOTE: plain Provider / StreamProvider (not @riverpod codegen) — per STATE
// 01-05, riverpod_generator 3.x cannot resolve Drift part-file types at
// codegen time, so culture-scoped providers that traffic in Drift-generated
// classes (CulturePage, etc.) must be hand-written.

/// All culture pages, ordered by title (for title -> id index / wiki-link resolution).
final culturePageListProvider = StreamProvider.autoDispose<List<CulturePage>>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return db.cultureDao.watchAllPages();
});

/// Map of page title -> page id for wiki-link resolution.
final pageTitleIndexProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final pages = ref.watch(culturePageListProvider).asData?.value ?? [];
  return {for (final p in pages) p.title: p.id};
});

/// Root pages (parentId == null) for top-level tree display.
final cultureRootPagesProvider = StreamProvider.autoDispose<List<CulturePage>>((ref) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return db.cultureDao.watchRootPages();
});

/// Children of a specific parent page.
final cultureChildPagesProvider =
    StreamProvider.autoDispose.family<List<CulturePage>, int>((ref, parentId) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return db.cultureDao.watchChildren(parentId);
});

/// Notifier backing [selectedCulturePageIdProvider].
///
/// StateProvider was removed in flutter_riverpod 3.x — use NotifierProvider.
class _SelectedCulturePageId extends Notifier<int?> {
  @override
  int? build() => null;

  /// Updates the selected culture page id.
  void set(int? id) => state = id;
}

/// Currently selected culture page id (ephemeral UI state).
final selectedCulturePageIdProvider =
    NotifierProvider<_SelectedCulturePageId, int?>(
  _SelectedCulturePageId.new,
);

/// Watch a single culture page by id.
final culturePageProvider =
    StreamProvider.autoDispose.family<CulturePage?, int>((ref, pageId) {
  final db = ref.watch(currentDatabaseProvider);
  if (db == null) return Stream.value(null);
  return db.cultureDao.watchPageById(pageId);
});
