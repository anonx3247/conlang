// Plan 04-14 Task 1 — widget tests for the D-59 auto_apply checkbox in
// RuleEditorDialog (derivational mode only).
//
// Locks:
//   - Test 1: checkbox visible in derivational mode, labeled
//     "Auto-apply to all matching words"
//   - Test 2: checkbox HIDDEN in inflectional mode (D-59 is derivational-only)
//   - Test 3: save with checkbox checked writes autoApply=true to the row
//   - Test 4: template preview shows "(ruleName)" when checkbox is on
//   - Test 5: opening with an existing autoApply=true rule initializes the
//     checkbox as checked
//
// Pattern mirrors rule_editor_dialog_kind_test.dart — in-memory AppDatabase
// overridden into currentDatabaseProvider, FlutterError.onError swallows the
// pre-existing branch op-row overflow.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int nounPosId;
  late int verbPosId;

  Future<void> seedPos() async {
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    verbPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
  }

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
            body: SizedBox(width: 1400, height: 900, child: child),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
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

  group('D-59 auto_apply checkbox (plan 04-14)', () {
    testWidgets(
      'Test 1 — derivational mode shows the auto-apply checkbox below Input/Output POS',
      (tester) async {
        await seedPos();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.derivational)),
        );
        await settle(tester);

        expect(find.text('Auto-apply to all matching words'), findsOneWidget);
        // The checkbox should render with Input/Output POS still present.
        expect(find.text('Input POS'), findsOneWidget);
        expect(find.text('Output POS'), findsOneWidget);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — inflectional mode does NOT show the auto-apply checkbox',
      (tester) async {
        await seedPos();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.inflectional)),
        );
        await settle(tester);

        expect(find.text('Auto-apply to all matching words'), findsNothing);

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — save with checkbox checked writes autoApply=true to the row',
      (tester) async {
        await seedPos();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.derivational)),
        );
        await settle(tester);

        // Fill name.
        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Actor',
        );
        await settle(tester);

        // Select Input POS (Noun).
        final inputDropdown = find.byType(DropdownButtonFormField<int>).first;
        await tester.tap(inputDropdown);
        await settle(tester);
        await tester.tap(find.text('Noun (N)').last);
        await settle(tester);

        // Enter a suffix so there's a valid branch op. Target the last
        // EditableText (the suffix affix field).
        final editableTexts = find.byType(EditableText);
        expect(editableTexts, findsWidgets);
        await tester.enterText(editableTexts.last, 'er');
        await settle(tester);

        // Toggle the auto-apply flag. Rather than rely on the
        // CheckboxListTile's InkWell (which the layout of the dialog makes
        // fragile to exact hit targets inside the widget test surface), call
        // the state's setState directly via the CheckboxListTile's onChanged
        // callback — this exercises the exact production code path the
        // user's tap would invoke.
        final checkboxTile =
            tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
        checkboxTile.onChanged!(true);
        await settle(tester);

        // Save.
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        // Verify persisted row has autoApply=true.
        final rows = await db.select(db.morphologicalRules).get();
        expect(rows.length, 1);
        expect(rows.first.autoApply, isTrue);
        expect(rows.first.name, 'Actor');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — template preview surfaces the rule name in parentheses when auto-apply is checked',
      (tester) async {
        await seedPos();
        await tester.pumpWidget(
          buildApp(const RuleEditorDialog(kind: RuleKind.derivational)),
        );
        await settle(tester);

        // Type a rule name first so the template can interpolate it.
        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Actor',
        );
        await settle(tester);

        // Tap the checkbox to enable — target the Checkbox widget directly.
        await tester.tap(find.byType(Checkbox));
        await settle(tester);

        // The preview label should contain the literal substring "(Actor)"
        // proving the D-59 template `{parent meaning} (rule.name)` is
        // surfaced in the UI.
        expect(
          find.textContaining('(Actor)'),
          findsOneWidget,
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 5 — editing an existing autoApply=true rule initializes the checkbox checked',
      (tester) async {
        await seedPos();

        // Seed an existing derivational rule with autoApply=true.
        final ruleId = await db.into(db.morphologicalRules).insert(
              MorphologicalRulesCompanion.insert(
                name: 'Actor',
                source: 'suffix: er',
                ordering: const Value(0),
                kind: const Value('derivational'),
                inputPosId: Value(nounPosId),
                outputPosId: Value(nounPosId),
                autoApply: const Value(true),
              ),
            );
        final existing = await (db.select(db.morphologicalRules)
              ..where((t) => t.id.equals(ruleId)))
            .getSingle();

        await tester.pumpWidget(
          buildApp(
            RuleEditorDialog(
              kind: RuleKind.derivational,
              existing: existing,
            ),
          ),
        );
        await settle(tester);

        // The checkbox should be visible and checked.
        final checkbox = find.byType(Checkbox).first;
        expect(checkbox, findsOneWidget);
        final widget = tester.widget<Checkbox>(checkbox);
        expect(widget.value, isTrue);

        await teardownWidget(tester);
      },
    );
  });
}
