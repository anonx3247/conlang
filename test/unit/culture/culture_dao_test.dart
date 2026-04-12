import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/culture/data/culture_dao.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CultureDao cultureDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cultureDao = db.cultureDao;
  });

  tearDown(() async {
    await db.close();
  });

  // Test 1: createPage inserts a page and returns an id > 0
  test('createPage inserts a page and returns id > 0', () async {
    final id = await cultureDao.createPage(title: 'Welcome');
    expect(id, greaterThan(0));
  });

  // Test 2: watchRootPages returns only pages with parentId == null, ordered by ordering
  test('watchRootPages returns only root pages ordered by ordering', () async {
    await cultureDao.createPage(title: 'B', ordering: 2);
    await cultureDao.createPage(title: 'A', ordering: 1);
    // create a child page (should not appear in root pages)
    final parentId = await cultureDao.createPage(title: 'Parent', ordering: 0);
    await cultureDao.createPage(title: 'Child', parentId: parentId, ordering: 0);

    final roots = await cultureDao.watchRootPages().first;
    expect(roots.length, equals(3));
    expect(roots[0].title, equals('Parent'));
    expect(roots[1].title, equals('A'));
    expect(roots[2].title, equals('B'));
    expect(roots.every((p) => p.parentId == null), isTrue);
  });

  // Test 3: watchChildren returns children of a parent, ordered by ordering
  test('watchChildren returns children of parent ordered by ordering', () async {
    final parentId = await cultureDao.createPage(title: 'Parent');
    await cultureDao.createPage(title: 'ChildB', parentId: parentId, ordering: 2);
    await cultureDao.createPage(title: 'ChildA', parentId: parentId, ordering: 1);
    // another root page (should not appear)
    await cultureDao.createPage(title: 'OtherRoot');

    final children = await cultureDao.watchChildren(parentId).first;
    expect(children.length, equals(2));
    expect(children[0].title, equals('ChildA'));
    expect(children[1].title, equals('ChildB'));
    expect(children.every((p) => p.parentId == parentId), isTrue);
  });

  // Test 4: updatePage modifies title, content, icon, and sets updatedAt
  test('updatePage modifies title, content, icon and bumps updatedAt', () async {
    final id = await cultureDao.createPage(title: 'Original');
    final before = await cultureDao.getPageById(id);
    await Future.delayed(const Duration(milliseconds: 1100));

    await cultureDao.updatePage(id, title: 'Updated', content: 'New content', icon: const Value('📖'));
    final after = await cultureDao.getPageById(id);

    expect(after!.title, equals('Updated'));
    expect(after.content, equals('New content'));
    expect(after.icon, equals('📖'));
    expect(after.updatedAt.isAfter(before!.updatedAt), isTrue);
  });

  // Test 5: deletePage removes the page; children get parentId set to null
  test('deletePage removes page and sets children parentId to null', () async {
    final parentId = await cultureDao.createPage(title: 'Parent');
    final childId = await cultureDao.createPage(title: 'Child', parentId: parentId);

    await cultureDao.deletePage(parentId);

    final parent = await cultureDao.getPageById(parentId);
    expect(parent, isNull);

    final child = await cultureDao.getPageById(childId);
    expect(child, isNotNull);
    expect(child!.parentId, isNull);
  });

  // Test 6: reparentPage updates parentId and ordering atomically
  test('reparentPage updates parentId and ordering atomically', () async {
    final pageId = await cultureDao.createPage(title: 'Page', ordering: 0);
    final newParentId = await cultureDao.createPage(title: 'NewParent');

    await cultureDao.reparentPage(pageId, newParentId, 5);

    final page = await cultureDao.getPageById(pageId);
    expect(page!.parentId, equals(newParentId));
    expect(page.ordering, equals(5));
  });

  // Test 7: swapOrdering swaps ordering values in a transaction
  test('swapOrdering swaps ordering values between two pages', () async {
    final idA = await cultureDao.createPage(title: 'A', ordering: 1);
    final idB = await cultureDao.createPage(title: 'B', ordering: 2);

    await cultureDao.swapOrdering(idA, 1, idB, 2);

    final a = await cultureDao.getPageById(idA);
    final b = await cultureDao.getPageById(idB);
    expect(a!.ordering, equals(2));
    expect(b!.ordering, equals(1));
  });

  // Test 8: watchAllPages returns all pages (for title index)
  test('watchAllPages returns all pages ordered by title', () async {
    await cultureDao.createPage(title: 'Zephyr');
    await cultureDao.createPage(title: 'Alpha');
    await cultureDao.createPage(title: 'Mango');

    final all = await cultureDao.watchAllPages().first;
    expect(all.length, equals(3));
    expect(all[0].title, equals('Alpha'));
    expect(all[1].title, equals('Mango'));
    expect(all[2].title, equals('Zephyr'));
  });
}
