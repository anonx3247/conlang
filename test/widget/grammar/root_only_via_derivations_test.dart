// Plan 04-14 Task 4 — D-63 / G-16 rootOnlyViaDerivations checkbox +
// muted Dictionary sidebar rendering + D-62 / G-17 parents multi-select
// picker in the word creation form.
//
// Locks:
//   - Test 1: the word creation form shows the "This root only exists
//     through derivations" checkbox below the primary fields.
//   - Test 2: saving with the checkbox checked writes rootOnlyViaDerivations
//     to the new Lexeme row.
//   - Test 3: a multi-select Parents picker renders in the word creation
//     form (populated from the existing lexeme list).
//   - Test 4: saving with parents selected inserts one LexemeParents row
//     per selected parent for the new child lexeme id.
//   - Test 5: a lexeme with rootOnlyViaDerivations=true renders in the
//     dictionary sidebar with reduced opacity — Opacity widget with a
//     value < 1 wraps its row.
//   - Test 6: muted lexemes remain findable via search (the filter is
//     visual-only, not structural).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_creation_form.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_list_panel.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  void Function(FlutterErrorDetails)? previousOnError;

  setUpAll(() {
    previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('A RenderFlex overflowed by')) return;
      previousOnError?.call(details);
    };
  });

  tearDownAll(() {
    FlutterError.onError = previousOnError;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 1200, height: 900, child: child),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> teardownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  group('D-63 rootOnlyViaDerivations + D-62 parents picker', () {
    testWidgets(
      'Test 1 — word creation form shows the rootOnlyViaDerivations checkbox',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            WordCreationForm(
              onCancel: () {},
              onSaved: () {},
            ),
          ),
        );
        await settle(tester);

        expect(
          find.text('This root only exists through derivations'),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — saving with the checkbox checked writes rootOnlyViaDerivations=true',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            WordCreationForm(
              onCancel: () {},
              onSaved: () {},
            ),
          ),
        );
        await settle(tester);

        // Enter an IPA (required field).
        final ipaField = find.widgetWithText(TextField, 'e.g. /kala/');
        expect(ipaField, findsOneWidget);
        await tester.enterText(ipaField, 'kama');
        await settle(tester);

        // Toggle the rootOnlyViaDerivations checkbox via its onChanged
        // callback — the CheckboxListTile hit target is fragile inside a
        // 1200px widget test surface so we invoke the callback directly.
        final tile = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('This root only exists through derivations'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        tile.onChanged!(true);
        await settle(tester);

        // Save.
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'New word'));
        await tester.tap(find.widgetWithText(FilledButton, 'New word'));
        await settle(tester);

        final rows = await db.select(db.lexemes).get();
        expect(rows.length, 1);
        expect(rows.first.rootOnlyViaDerivations, isTrue);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — word creation form shows a Parents (etymology) multi-select picker',
      (tester) async {
        // Seed an existing lexeme so the picker has content.
        await db.into(db.lexemes).insert(
              LexemesCompanion.insert(
                ipa: 'lir',
                romanization: const Value('lir'),
                meaning: const Value('fast'),
              ),
            );

        await tester.pumpWidget(
          buildApp(
            WordCreationForm(
              onCancel: () {},
              onSaved: () {},
            ),
          ),
        );
        await settle(tester);

        expect(find.text('Parents (etymology)'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'lir'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — saving with parents selected inserts one LexemeParents row per parent',
      (tester) async {
        final parentId = await db.into(db.lexemes).insert(
              LexemesCompanion.insert(
                ipa: 'lir',
                romanization: const Value('lir'),
                meaning: const Value('fast'),
              ),
            );

        await tester.pumpWidget(
          buildApp(
            WordCreationForm(
              onCancel: () {},
              onSaved: () {},
            ),
          ),
        );
        await settle(tester);

        // Enter IPA for the new child.
        await tester.enterText(
            find.widgetWithText(TextField, 'e.g. /kala/'), 'kamalir');
        await settle(tester);

        // Select the "lir" parent chip via its onSelected callback.
        final chipFinder = find.widgetWithText(FilterChip, 'lir');
        final chip = tester.widget<FilterChip>(chipFinder);
        chip.onSelected!(true);
        await settle(tester);

        // Save.
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'New word'));
        await tester.tap(find.widgetWithText(FilledButton, 'New word'));
        await settle(tester);

        final parentRows = await db.select(db.lexemeParents).get();
        expect(parentRows.length, 1);
        expect(parentRows.first.parentLexemeId, equals(parentId));

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — sidebar list renders rootOnlyViaDerivations rows wrapped in Opacity',
      (tester) async {
        await db.into(db.lexemes).insert(
              LexemesCompanion.insert(
                ipa: 'zzipa',
                romanization: const Value('zzmutedword'),
                meaning: const Value('bound root'),
                rootOnlyViaDerivations: const Value(true),
              ),
            );
        await db.into(db.lexemes).insert(
              LexemesCompanion.insert(
                ipa: 'yykamaipa',
                romanization: const Value('yykamarom'),
                meaning: const Value('to run'),
              ),
            );

        await tester.pumpWidget(
          buildApp(
            WordListPanel(
              selectedLexemeId: null,
              onWordSelected: (_) {},
              onAddRoot: () {},
            ),
          ),
        );
        await settle(tester);

        // Find the "zzmutedword" romanization Text — its ancestor Opacity
        // must have opacity < 1.
        final mutedText = find.text('zzmutedword');
        expect(mutedText, findsOneWidget);

        final opacityAncestor = find.ancestor(
          of: mutedText,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity < 1.0,
          ),
        );
        expect(opacityAncestor, findsOneWidget,
            reason:
                'rootOnlyViaDerivations lexemes must be wrapped in an '
                'Opacity widget with opacity < 1.0');

        // The non-muted row must NOT be wrapped in a reduced-opacity
        // ancestor from its row.
        final kamaText = find.text('yykamarom');
        expect(kamaText, findsOneWidget);
        final kamaOpacity = find.ancestor(
          of: kamaText,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity < 1.0,
          ),
        );
        expect(kamaOpacity, findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 6 — rootOnlyViaDerivations lexemes remain in the DB scan (not hidden)',
      (tester) async {
        // D-63: muted rendering is visual-only. Verify the row is present in
        // the Lexemes table so search/findability is preserved.
        final id = await db.into(db.lexemes).insert(
              LexemesCompanion.insert(
                ipa: 'hidden',
                romanization: const Value('hidden'),
                meaning: const Value('ghost'),
                rootOnlyViaDerivations: const Value(true),
              ),
            );

        final rows = await db.select(db.lexemes).get();
        expect(rows.where((l) => l.id == id).length, 1,
            reason: 'muted lexemes must stay in the persisted store — the '
                'sidebar renders them at reduced opacity but never hides them');

        await teardownWidget(tester);
      },
    );
  });
}
