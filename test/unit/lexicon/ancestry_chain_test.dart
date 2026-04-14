// Plan 11-01 — Unit tests for the ancestry chain traversal.
//
// Tests the pure `buildAncestryNode` function from lexeme_providers.dart
// directly by constructing lexeme maps and parent-link maps inline (no DB
// needed). The function is a package-visible top-level function (no underscore)
// since it has no side effects and is pure Dart.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/lexeme_parents_dao.dart';
import 'package:conlang_workbench/features/lexicon/data/lexeme_providers.dart';
import 'package:conlang_workbench/features/lexicon/domain/ancestry_node.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers — build minimal Lexeme objects without a real DB
// ---------------------------------------------------------------------------

/// Builds a minimal [LexemeParentRow] from a [childLexemeId] and
/// [parentLexemeId]. [relationship] defaults to null (displays as 'parent').
Future<LexemeParentRow> _parentRow(
  AppDatabase db, {
  required int childLexemeId,
  required int parentLexemeId,
  String? relationship,
}) async {
  await db.lexemeParentsDao.insertParent(
    childLexemeId: childLexemeId,
    parentLexemeId: parentLexemeId,
    relationship: relationship,
  );
  final rows = await db.select(db.lexemeParents).get();
  return rows.firstWhere(
    (r) =>
        r.childLexemeId == childLexemeId && r.parentLexemeId == parentLexemeId,
  );
}

/// Inserts a root lexeme (no parent links, no derivedFromLexemeId).
Future<int> _insertRoot(AppDatabase db, String ipa, {String? meaning}) {
  return db.into(db.lexemes).insert(
        LexemesCompanion.insert(
          ipa: ipa,
          meaning: Value(meaning),
        ),
      );
}

/// Inserts a lexeme with a rule-derived parent (derivedFromLexemeId +
/// derivedViaRuleId set). Stores ipa as parent's ipa (placeholder).
Future<int> _insertRuleDerived(
  AppDatabase db, {
  required String ipa,
  required int parentId,
  required int ruleId,
  String? meaning,
}) {
  return db.into(db.lexemes).insert(
        LexemesCompanion.insert(
          ipa: ipa,
          meaning: Value(meaning),
          derivedFromLexemeId: Value(parentId),
          derivedViaRuleId: Value(ruleId),
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper: build in-memory lexeme + parent maps from DB state
  // ---------------------------------------------------------------------------

  Future<Map<int, Lexeme>> lexemeMapFromDb() async {
    final all = await db.select(db.lexemes).get();
    return {for (final lx in all) lx.id: lx};
  }

  Future<Map<int, List<LexemeParentRow>>> parentMapFromDb() async {
    final all = await db.select(db.lexemeParents).get();
    final map = <int, List<LexemeParentRow>>{};
    for (final row in all) {
      map.putIfAbsent(row.childLexemeId, () => []).add(row);
    }
    return map;
  }

  group('buildAncestryNode — basic traversal', () {
    test('root word with no parents returns a single node with empty parents',
        () async {
      final rootId = await _insertRoot(db, 'kama', meaning: 'to run');
      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: rootId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      expect(node, isNotNull);
      expect(node!.lexemeId, equals(rootId));
      expect(node.parents, isEmpty);
      expect(node.isCycle, isFalse);
      expect(node.isTruncated, isFalse);
    });

    test(
        'word with manual parent returns tree with edge label parent or custom relationship',
        () async {
      final parentId = await _insertRoot(db, 'kama', meaning: 'to run');
      final childId = await _insertRoot(db, 'kamaz', meaning: 'runner');
      await _parentRow(db, childLexemeId: childId, parentLexemeId: parentId);

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: childId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      expect(node, isNotNull);
      expect(node!.parents, hasLength(1));
      final parentNode = node.parents.first;
      expect(parentNode.lexemeId, equals(parentId));
      expect(parentNode.edgeLabel, equals('parent'));
      expect(parentNode.isRuleDerived, isFalse);
    });

    test('word with custom relationship label uses that label', () async {
      final parentId = await _insertRoot(db, 'kama');
      final childId = await _insertRoot(db, 'kamaz');
      await _parentRow(
        db,
        childLexemeId: childId,
        parentLexemeId: parentId,
        relationship: 'cognate with',
      );

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: childId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      expect(node!.parents.first.edgeLabel, equals('cognate with'));
    });

    test('three-level chain A→B→C returns correct tree structure', () async {
      // A (root), B (child of A), C (child of B)
      final aId = await _insertRoot(db, 'ka', meaning: 'root');
      final bId = await _insertRoot(db, 'kab', meaning: 'mid');
      final cId = await _insertRoot(db, 'kabc', meaning: 'leaf');

      await _parentRow(db, childLexemeId: bId, parentLexemeId: aId);
      await _parentRow(db, childLexemeId: cId, parentLexemeId: bId);

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: cId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      // C has parent B
      expect(node, isNotNull);
      expect(node!.lexemeId, equals(cId));
      expect(node.parents, hasLength(1));

      // B has parent A
      final bNode = node.parents.first;
      expect(bNode.lexemeId, equals(bId));
      expect(bNode.parents, hasLength(1));

      // A has no parents
      final aNode = bNode.parents.first;
      expect(aNode.lexemeId, equals(aId));
      expect(aNode.parents, isEmpty);
    });

    test('word with BOTH rule-derived parent AND manual parent returns both branches',
        () async {
      // A is the rule-derived parent (stored via derivedFromLexemeId)
      // B is the manual parent (stored in LexemeParents table)
      final aId = await _insertRoot(db, 'ka', meaning: 'source A');
      final bId = await _insertRoot(db, 'ko', meaning: 'source B');

      // Set up a minimal rule id (we just need an int — no real rule object in pure test)
      // Insert a fake rule row directly.
      final ruleId = await db.into(db.morphologicalRules).insert(
            MorphologicalRulesCompanion.insert(
              name: 'TestRule',
              source: '+z',
            ),
          );

      // C derives from A via rule, and also has manual parent B
      final cId = await _insertRuleDerived(
        db,
        ipa: 'kaz',
        parentId: aId,
        ruleId: ruleId,
        meaning: 'dual-parent',
      );
      await _parentRow(db, childLexemeId: cId, parentLexemeId: bId);

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();
      // ruleNameById maps rule id -> rule name (the only info buildAncestryNode needs).
      final ruleNameMap = {ruleId: 'TestRule'};

      final node = buildAncestryNode(
        lexemeId: cId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: ruleNameMap,
        visited: {},
        depth: 0,
      );

      expect(node, isNotNull);
      // Should have 2 parents: the rule-derived one and the manual one
      expect(node!.parents, hasLength(2));

      // One parent should be rule-derived
      final ruleDerived =
          node.parents.where((p) => p.isRuleDerived).toList();
      expect(ruleDerived, hasLength(1));
      expect(ruleDerived.first.lexemeId, equals(aId));
      expect(ruleDerived.first.edgeLabel, contains('TestRule'));

      // One parent should be manual
      final manual =
          node.parents.where((p) => !p.isRuleDerived).toList();
      expect(manual, hasLength(1));
      expect(manual.first.lexemeId, equals(bId));
      expect(manual.first.edgeLabel, equals('parent'));
    });
  });

  group('buildAncestryNode — cycle detection', () {
    test(
        'cycle: X has manual parent Y, Y has manual parent X — X node in Y branch is marked isCycle=true',
        () async {
      final xId = await _insertRoot(db, 'x');
      final yId = await _insertRoot(db, 'y');
      // X's parent is Y, and Y's parent is X → cycle
      await _parentRow(db, childLexemeId: xId, parentLexemeId: yId);
      await _parentRow(db, childLexemeId: yId, parentLexemeId: xId);

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: xId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      // x -> y -> x (cycle detected)
      expect(node, isNotNull);
      expect(node!.parents, hasLength(1));

      final yNode = node.parents.first;
      expect(yNode.lexemeId, equals(yId));
      expect(yNode.isCycle, isFalse); // Y itself is not the cycle marker

      // Y's parent should be X marked as cycle
      expect(yNode.parents, hasLength(1));
      final cycleNode = yNode.parents.first;
      expect(cycleNode.lexemeId, equals(xId));
      expect(cycleNode.isCycle, isTrue,
          reason: 'X appearing in its own ancestor chain is a cycle');
    });

    test(
        'DAG diamond: D has parents B and C, both B and C have parent A — A should NOT be marked cycle',
        () async {
      // Diamond: A is ancestor of both B and C, both are parents of D
      final aId = await _insertRoot(db, 'a');
      final bId = await _insertRoot(db, 'b');
      final cId = await _insertRoot(db, 'c');
      final dId = await _insertRoot(db, 'd');

      await _parentRow(db, childLexemeId: bId, parentLexemeId: aId);
      await _parentRow(db, childLexemeId: cId, parentLexemeId: aId);
      await _parentRow(db, childLexemeId: dId, parentLexemeId: bId);
      await _parentRow(db, childLexemeId: dId, parentLexemeId: cId);

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: dId,
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      expect(node, isNotNull);
      // D has 2 parents (B and C)
      expect(node!.parents, hasLength(2));

      // Neither branch should mark A as a cycle
      void checkNoCycles(AncestryNode n) {
        if (n.isCycle) {
          fail('Node ${n.lexemeId} was wrongly marked as cycle in a DAG diamond');
        }
        for (final parent in n.parents) {
          checkNoCycles(parent);
        }
      }

      checkNoCycles(node);

      // Verify A appears in both branches (not as cycle)
      final bNode = node.parents.firstWhere((p) => p.lexemeId == bId);
      final cNode = node.parents.firstWhere((p) => p.lexemeId == cId);

      expect(bNode.parents, hasLength(1));
      expect(bNode.parents.first.lexemeId, equals(aId));
      expect(bNode.parents.first.isCycle, isFalse);

      expect(cNode.parents, hasLength(1));
      expect(cNode.parents.first.lexemeId, equals(aId));
      expect(cNode.parents.first.isCycle, isFalse);
    });
  });

  group('buildAncestryNode — truncation', () {
    test('chain of 12 words truncates at 10 levels with isTruncated=true',
        () async {
      // Build a chain: w0 <- w1 <- w2 <- ... <- w11
      // We query from w11; ancestry goes up 11 levels. Truncation at depth 10.
      final ids = <int>[];
      for (var i = 0; i < 12; i++) {
        final id = await _insertRoot(db, 'w$i');
        ids.add(id);
      }

      // Link each word to its predecessor: w1's parent is w0, w2's parent is w1, etc.
      for (var i = 1; i < 12; i++) {
        await _parentRow(db,
            childLexemeId: ids[i], parentLexemeId: ids[i - 1]);
      }

      final lexMap = await lexemeMapFromDb();
      final parentMap = await parentMapFromDb();

      final node = buildAncestryNode(
        lexemeId: ids[11], // deepest word
        lexemeById: lexMap,
        parentsByChild: parentMap,
        ruleNameById: {},
        visited: {},
        depth: 0,
      );

      // Walk down to the 10th ancestor (depth 10) — should be truncated.
      AncestryNode? current = node;
      var depth = 0;
      while (current != null && current.parents.isNotEmpty && !current.parents.first.isTruncated) {
        current = current.parents.first;
        depth++;
        if (depth > 15) fail('Traversal exceeded 15 levels — truncation not working');
      }

      expect(current, isNotNull);
      expect(current!.parents, hasLength(1));
      expect(current.parents.first.isTruncated, isTrue,
          reason: 'Ancestry must truncate at depth 10');
    });
  });

  group('AncestryNode model', () {
    test('AncestryNode has correct default values for optional fields', () {
      const rootNode = AncestryNode(
        lexemeId: 1,
        lexeme: null,
        edgeLabel: '',
        isRuleDerived: false,
      );

      expect(rootNode.parents, isEmpty);
      expect(rootNode.isCycle, isFalse);
      expect(rootNode.isTruncated, isFalse);
    });

    test('AncestryNode with cycle flag set', () {
      const cycleNode = AncestryNode(
        lexemeId: 42,
        lexeme: null,
        edgeLabel: 'parent',
        isRuleDerived: false,
        isCycle: true,
      );

      expect(cycleNode.isCycle, isTrue);
      expect(cycleNode.isTruncated, isFalse);
    });

    test('AncestryNode with truncated flag set', () {
      const truncNode = AncestryNode(
        lexemeId: 7,
        lexeme: null,
        edgeLabel: '',
        isRuleDerived: false,
        isTruncated: true,
      );

      expect(truncNode.isTruncated, isTrue);
      expect(truncNode.isCycle, isFalse);
    });
  });
}
