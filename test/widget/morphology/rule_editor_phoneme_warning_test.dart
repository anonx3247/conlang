// Plan 04-16 Task 4 — D-81 / G-69 widget tests:
// * Rule editor inline phoneme-violation warning beneath each literal
//   field (soft warning only, never blocks save).
// * Rules list warning icon in _buildInflectionalGroupedList.
// * Reactivity via phonemeInventoryProvider — adding a phoneme clears
//   warnings without reopening the dialog.
//
// The scaffold mirrors rule_editor_dialog_kind_test.dart (in-memory
// AppDatabase, RenderFlex overflow suppression, IpaTextField focus
// debounce drain on teardown) and adds a phonemeInventoryProvider
// override so tests can inject synthetic inventories without seeding
// phoneme/natural_class rows.

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/inflectional_rule_pos_dao.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rules_page.dart';
import 'package:conlang_workbench/features/phonology/data/phonotactic_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:conlang_workbench/shared/widgets/violation_text.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late InflectionalRulePOSDao junctionDao;
  late int nounPosId;
  const int sgLevelId = 1;
  const int plLevelId = 2;

  // Overflow-warning suppressor copied from the existing rule editor
  // widget test — the dialog's branch op-row overflows by ~165px at
  // widget-test dialog width; plan 04-16 does not widen it.
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
    junctionDao = InflectionalRulePOSDao(db);
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Number',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: sgLevelId, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(
                  id: plLevelId, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
            templateId: const Value('number.sg_pl'),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // Build a ProviderScope with both the in-memory DB and an explicit
  // PhonemeInventory override. Tests pass `inventory` to inject the
  // phoneme set they want for a given scenario. This bypasses the
  // consonant/vowel/naturalClass list providers entirely.
  Widget buildApp({
    required Widget child,
    required PhonemeInventory inventory,
  }) =>
      ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
          phonemeInventoryProvider.overrideWithValue(inventory),
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

  Finder suffixAffixField() {
    // The default dialog has a single SuffixOp branch with one
    // IpaTextField. The rule name is a plain TextField higher up
    // (outside any branch card). The IpaTextField's hint is
    // 'IPA affix, e.g. in, ɯ' — we find by hint-text-ancestor lookup
    // via the last EditableText descendant of the dialog.
    return find.byType(EditableText).last;
  }

  // Locked tooltip substring from D-81 / CONTEXT.md §D-81.
  const lockedRuleEditorTooltip =
      'is not in the phoneme inventory (did you mean to define it first?)';

  group('D-81 rule editor inline phoneme warning (plan 04-16 / G-69)', () {
    testWidgets(
      'Test 1 — unknown phoneme in SuffixOp affix shows inline ViolationText',
      (tester) async {
        // Inventory WITHOUT 'c'.
        const inventory = PhonemeInventory(
          consonants: ['n', 't', 'p'],
          vowels: ['a', 'e', 'i'],
          naturalClasses: {},
        );
        await tester.pumpWidget(buildApp(
          child: const RuleEditorDialog(kind: RuleKind.inflectional),
          inventory: inventory,
        ));
        await settle(tester);

        // Type 'ci' into the suffix affix field. The suffix affix is
        // the last EditableText; the rule-name field is an earlier
        // EditableText.
        await tester.enterText(suffixAffixField(), 'ci');
        await settle(tester);

        // A ViolationText widget is rendered beneath the field with
        // at least one violation carrying the locked tooltip substring
        // AND quoting the offending char 'c'.
        final violationTexts =
            tester.widgetList<ViolationText>(find.byType(ViolationText));
        final withViolations = violationTexts
            .where((v) => v.violations.isNotEmpty)
            .toList();
        expect(withViolations, isNotEmpty,
            reason:
                'D-81: inline ViolationText must appear when a literal '
                'field contains an unknown phoneme.');
        final anyLocked = withViolations.any((v) => v.violations.any((x) =>
            x.ruleDescription.contains(lockedRuleEditorTooltip) &&
            x.ruleDescription.contains("'c'")));
        expect(anyLocked, isTrue,
            reason: 'D-81: violation description must embed the locked '
                "tooltip substring and quote the offending char 'c'.");

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 2 — save is NOT blocked when phoneme violations are present '
      '(soft warning only)',
      (tester) async {
        const inventory = PhonemeInventory(
          consonants: ['n', 't'],
          vowels: ['a', 'e', 'i'],
          naturalClasses: {},
        );
        await tester.pumpWidget(buildApp(
          child: const RuleEditorDialog(kind: RuleKind.inflectional),
          inventory: inventory,
        ));
        await settle(tester);

        // Select POS Noun so save-validation is satisfied on that axis.
        await tester.tap(find.widgetWithText(FilterChip, 'Noun (N)'));
        await settle(tester);

        // Enter a rule name.
        await tester.enterText(
          find.widgetWithText(TextField, 'Rule name'),
          'Plural',
        );
        await settle(tester);

        // Bind the Plural level so inflectional bindings validation passes.
        await tester.tap(find.widgetWithText(FilterChip, 'PL'));
        await settle(tester);

        // Type 'ci' into the suffix affix field — violating but NOT
        // blocking save.
        await tester.enterText(suffixAffixField(), 'ci');
        await settle(tester);

        // Tap Save.
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        // The DB now has exactly one inflectional rule whose source
        // contains the 'c' char. Save was NOT blocked.
        final rows = await db.select(db.morphologicalRules).get();
        expect(rows.length, 1,
            reason:
                'D-81: save must complete even when violations exist — '
                'warnings are soft-only.');
        expect(rows.first.source.contains('c'), isTrue,
            reason:
                'The violating source string was persisted unchanged.');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 3 — adding phoneme to inventory reactively clears warning',
      (tester) async {
        // Start with inventory missing 'c'.
        final inventoryNotifier = ValueNotifier<PhonemeInventory>(
          const PhonemeInventory(
            consonants: ['n', 't'],
            vowels: ['a', 'e', 'i'],
            naturalClasses: {},
          ),
        );

        // Helper build that watches the ValueNotifier so we can pump
        // an inventory update during the test.
        Widget reactiveHarness() => ValueListenableBuilder<PhonemeInventory>(
              valueListenable: inventoryNotifier,
              builder: (ctx, inv, _) => ProviderScope(
                overrides: [
                  currentDatabaseProvider.overrideWithValue(db),
                  phonemeInventoryProvider.overrideWithValue(inv),
                ],
                child: const MaterialApp(
                  home: Scaffold(
                    body: SizedBox(
                      width: 1400,
                      height: 900,
                      child: RuleEditorDialog(kind: RuleKind.inflectional),
                    ),
                  ),
                ),
              ),
            );

        await tester.pumpWidget(reactiveHarness());
        await settle(tester);

        await tester.enterText(suffixAffixField(), 'ci');
        await settle(tester);

        // Warning visible.
        final before =
            tester.widgetList<ViolationText>(find.byType(ViolationText));
        final hasViolationBefore =
            before.any((v) => v.violations.isNotEmpty);
        expect(hasViolationBefore, isTrue,
            reason: 'D-81: warning must be visible before the phoneme '
                'is added.');

        // Now add 'c' to the inventory and pump — the ValueListenable
        // triggers a widget rebuild and Riverpod recomputes the
        // provider because the override value changed.
        inventoryNotifier.value = const PhonemeInventory(
          consonants: ['n', 't', 'c'],
          vowels: ['a', 'e', 'i'],
          naturalClasses: {},
        );
        await settle(tester);

        // Warning is gone.
        final after =
            tester.widgetList<ViolationText>(find.byType(ViolationText));
        final hasViolationAfter =
            after.any((v) => v.violations.isNotEmpty);
        expect(hasViolationAfter, isFalse,
            reason: 'D-81 reactivity: adding the missing phoneme to the '
                'inventory must clear the warning without reopening '
                'the dialog.');

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 4 — PatternCond V/C/F class-refs do NOT trigger warning',
      (tester) async {
        // Inventory has 'a' as a vowel but no 'c'.
        const inventory = PhonemeInventory(
          consonants: ['n', 't'],
          vowels: ['a', 'e'],
          naturalClasses: {},
        );
        await tester.pumpWidget(buildApp(
          child: const RuleEditorDialog(kind: RuleKind.inflectional),
          inventory: inventory,
        ));
        await settle(tester);

        // The condition pattern IpaTextField is the FIRST IpaTextField
        // in the branch card (before the suffix affix field). We locate
        // it via its hint text substring which is unique to conditions.
        final condField = find.widgetWithText(
          // ignore: avoid_dynamic_calls
          IpaTextFieldLike,
          'e.g. [nasal]V, CV, Vk(l)',
        );
        // Fallback: find by EditableText at index 1 (rule name at 0,
        // condition pattern at 1, suffix affix at 2) if the hint-based
        // lookup returns nothing — widget test scaffolding doesn't
        // guarantee hint-text finders traverse into ancestors.
        Finder condTarget = condField;
        if (condField.evaluate().isEmpty) {
          condTarget = find.byType(EditableText).at(1);
        }

        await tester.enterText(condTarget, 'V');
        await settle(tester);
        {
          final violations =
              tester.widgetList<ViolationText>(find.byType(ViolationText));
          expect(violations.every((v) => v.violations.isEmpty), isTrue,
              reason: 'V class-ref must not trigger a violation.');
        }

        await tester.enterText(condTarget, 'C');
        await settle(tester);
        {
          final violations =
              tester.widgetList<ViolationText>(find.byType(ViolationText));
          expect(violations.every((v) => v.violations.isEmpty), isTrue,
              reason: 'C class-ref must not trigger a violation.');
        }

        await tester.enterText(condTarget, '[nasal]');
        await settle(tester);
        {
          final violations =
              tester.widgetList<ViolationText>(find.byType(ViolationText));
          expect(violations.every((v) => v.violations.isEmpty), isTrue,
              reason: 'Bracketed class-ref must not trigger a violation.');
        }

        await teardownWidget(tester);
      },
    );
  });

  // -------------------------------------------------------------------
  // Rules list warning icon tests
  // -------------------------------------------------------------------
  group('D-81 rules list warning icon (plan 04-16 / G-69)', () {
    Future<int> insertInflectionalRule({
      required String name,
      required String source,
      required Set<int> posIds,
    }) async {
      final id = await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: name,
          source: source,
          featureBindings: const Value(
            // Bind the Plural level so the rule is well-formed.
            FeatureBindings(pos: [], dims: {}),
          ),
        ),
        RuleKind.inflectional,
      );
      await junctionDao.replaceForRule(ruleId: id, posIds: posIds);
      return id;
    }

    testWidgets(
      'Test 5 — rule row shows Icons.warning_amber_outlined when rule has '
      "unknown phoneme + tooltip 'Contains unknown phoneme: \\'c\\''",
      (tester) async {
        // Inventory missing 'c'.
        const inventory = PhonemeInventory(
          consonants: ['n', 't'],
          vowels: ['a', 'e', 'i'],
          naturalClasses: {},
        );
        await insertInflectionalRule(
          name: 'BadRule',
          source: '+ci',
          posIds: {nounPosId},
        );
        await tester.pumpWidget(buildApp(
          child: const RulesPage(kind: RuleKind.inflectional),
          inventory: inventory,
        ));
        await settle(tester);

        // The rule row contains a warning icon and a Tooltip with the
        // locked rules-list copy.
        expect(
          find.byIcon(Icons.warning_amber_outlined),
          findsOneWidget,
          reason: 'D-81: rule row must render the warning icon when '
              'scanner reports a violation.',
        );
        expect(
          find.byTooltip("Contains unknown phoneme: 'c'"),
          findsOneWidget,
          reason: 'D-81: locked tooltip copy must be exact.',
        );

        await teardownWidget(tester);
      },
    );

    testWidgets(
      'Test 6 — rule row shows NO warning icon for a clean rule',
      (tester) async {
        const inventory = PhonemeInventory(
          consonants: ['n', 't'],
          vowels: ['a', 'i'],
          naturalClasses: {},
        );
        await insertInflectionalRule(
          name: 'CleanRule',
          source: '+in',
          posIds: {nounPosId},
        );
        await tester.pumpWidget(buildApp(
          child: const RulesPage(kind: RuleKind.inflectional),
          inventory: inventory,
        ));
        await settle(tester);

        expect(
          find.byIcon(Icons.warning_amber_outlined),
          findsNothing,
          reason: 'D-81: clean rules (all phonemes in inventory) must not '
              'render the warning icon.',
        );

        await teardownWidget(tester);
      },
    );
  });
}

// Placeholder type used by the D-81 class-ref test's hint-text finder —
// IpaTextField's type is not directly exported for tests, so the finder
// falls back to EditableText indexing if this lookup returns nothing.
class IpaTextFieldLike {}
