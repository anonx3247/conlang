// Plan 04-17 Task 6 — D-90 rule editor save-time validator tests.
//
// Locks:
// * Case 1 — sole-intrinsic binding {gender=M} on a Noun whose gender
//            dim is intrinsic → Save is BLOCKED with the exact locked
//            error copy in both SnackBar and inline Text, and the DB
//            still contains 0 morphological rule rows after the tap.
// * Case 2 — {gender=M, number=PL} (gender intrinsic, number NOT
//            intrinsic) → Save PROCEEDS, 1 row persisted.
// * Case 3 — empty dim bindings are NOT touched by D-90; a different
//            validator blocks them via `_validationError` (D-13).
// * Case 4 — only non-intrinsic binding {number=PL} → Save proceeds.
// * Case 5 — [WARN-3 revision] multi-POS mixed intrinsicness: Noun
//            gender is intrinsic, Adjective gender is NOT. A rule
//            targeting BOTH POS with binding on Adjective's gender id
//            persists regardless of POS list order. Locks the
//            `for (final posId in bindings.pos)` iteration semantics.
// * Case 6 — [WARN-3 revision] multi-POS all-intrinsic on the bound
//            dim: a rule targeting [Noun, Adjective] whose only bound
//            dim is Noun's intrinsic gender (absent entirely on
//            Adjective) is BLOCKED because neither POS yields a
//            non-intrinsic axis.
//
// The harness mirrors rule_editor_phoneme_warning_test.dart (in-memory
// AppDatabase, RenderFlex overflow suppression, Drift stream-query
// settle pattern, explicit teardown).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/morphology/presentation/rules/rule_editor_dialog.dart';
import 'package:conlang_workbench/features/phonology/data/phonotactic_providers.dart';
import 'package:conlang_workbench/features/phonology/domain/word_generator.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Locked error copy from D-90 / plan 04-17 §D-90.
const lockedD90ErrorCopy =
    'Rule has no non-intrinsic axes — it would produce no paradigm variation. '
    'Intrinsic-only behavior belongs in standard-form patterns at word '
    'creation, not inflection rules.';

void main() {
  late AppDatabase db;
  late int nounPosId;
  late int adjPosId;
  // level ids used in the DimensionLevel json (local to each dim row)
  const int mLevelId = 1;
  const int fLevelId = 2;
  const int sgLevelId = 1;
  const int plLevelId = 2;

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

  /// Inventory containing every phoneme the affix fields use in this file,
  /// so the D-81 phoneme scanner never raises a side warning that would
  /// confuse the tests (a soft warning never blocks save, but noise is
  /// noise).
  const inventory = PhonemeInventory(
    consonants: ['k', 't', 'n', 's', 'z', 'r'],
    vowels: ['a', 'e', 'i', 'o', 'u'],
    naturalClasses: {},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    adjPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(
              name: 'Adjective', abbreviation: 'Adj'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  /// Seeds the default multi-dim shape used by most test cases:
  ///   Noun.Gender   (intrinsic=true,  {M, F})
  ///   Noun.Number   (intrinsic=false, {SG, PL})
  /// Returns the dim ids for follow-up assertions / chip interaction.
  Future<({int genderDimId, int numberDimId})> seedNounDims() async {
    final genderDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Gender',
            ordering: const Value(0),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: mLevelId, name: 'Masculine', abbr: 'M', ordering: 0),
              DimensionLevel(
                  id: fLevelId, name: 'Feminine', abbr: 'F', ordering: 1),
            ]),
            intrinsic: const Value(true),
          ),
        );
    final numberDimId = await db.into(db.dimensions).insert(
          DimensionsCompanion.insert(
            posId: nounPosId,
            name: 'Number',
            ordering: const Value(1),
            levelsJson: encodeLevelsJson(const [
              DimensionLevel(
                  id: sgLevelId, name: 'Singular', abbr: 'SG', ordering: 0),
              DimensionLevel(
                  id: plLevelId, name: 'Plural', abbr: 'PL', ordering: 1),
            ]),
          ),
        );
    return (genderDimId: genderDimId, numberDimId: numberDimId);
  }

  Widget buildApp({required Widget child}) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
          // Pin the phoneme inventory to avoid noisy literal-phoneme
          // warnings from the default inventory provider.
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

  /// The suffix affix field is the LAST EditableText in the dialog — the
  /// earlier ones are the rule-name TextField and any condition
  /// IpaTextField inside the single default branch card.
  Finder suffixAffixField() => find.byType(EditableText).last;

  /// Taps the rule-name field and types a name so the first-line save
  /// validation passes.
  Future<void> fillRuleName(WidgetTester tester, String name) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Rule name'),
      name,
    );
    await settle(tester);
  }

  /// Taps a POS chip by display label ("Noun (N)", "Adjective (Adj)").
  Future<void> tapPosChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilterChip, label));
    await settle(tester);
  }

  /// Taps a level chip by abbreviation (e.g. "M", "PL"). Level chips
  /// live in the dimension chip rows below the POS picker.
  Future<void> tapLevelChip(WidgetTester tester, String abbr) async {
    await tester.tap(find.widgetWithText(FilterChip, abbr));
    await settle(tester);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
  }

  // -------------------------------------------------------------------------
  // Case 1 — sole-intrinsic binding → Save is BLOCKED
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 1 — sole-intrinsic binding {gender=M} → Save blocked + '
    'locked copy in SnackBar and inline Text',
    (tester) async {
      await seedNounDims();

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'Masc Suffix');
      await tapPosChip(tester, 'Noun (N)');

      // Bind ONLY gender=M (intrinsic). No number chip tapped.
      await tapLevelChip(tester, 'M');

      // Fill the affix field so the "at least one branch" gate is
      // satisfied — otherwise that earlier validation would fire
      // instead of the D-90 path.
      await tester.enterText(suffixAffixField(), 'os');
      await settle(tester);

      // Tap Save — the D-90 validator must intercept.
      await tapSave(tester);

      // SnackBar carries the locked copy.
      final snackBarFinder = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(lockedD90ErrorCopy),
      );
      expect(snackBarFinder, findsOneWidget,
          reason:
              'D-90: SnackBar must surface the locked error copy on the '
              'first blocked save attempt.');

      // Inline red Text beneath the Save button also carries the copy.
      final inlineFinder = find.byKey(const ValueKey('saveBlockedReasonText'));
      expect(inlineFinder, findsOneWidget,
          reason:
              'D-90: inline red reason Text must render below the Save '
              'button when the validator blocks.');
      final inlineWidget = tester.widget<Text>(inlineFinder);
      expect(inlineWidget.data, equals(lockedD90ErrorCopy));

      // The DB still has zero morphological rules — insertRule was
      // NOT called.
      final rows = await db.select(db.morphologicalRules).get();
      expect(rows, isEmpty,
          reason:
              'D-90: blocked save must NOT persist any rule — the '
              'early return guards the DAO call.');

      await teardownWidget(tester);
    },
  );

  // -------------------------------------------------------------------------
  // Case 2 — mixed binding → Save proceeds
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 2 — {gender=M, number=PL} (mixed axes) → Save proceeds, '
    'rule is persisted',
    (tester) async {
      await seedNounDims();

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'Masc Plural');
      await tapPosChip(tester, 'Noun (N)');

      // Bind gender=M (intrinsic) AND number=PL (non-intrinsic) — the
      // rule has a non-intrinsic axis so D-90 MUST allow it.
      await tapLevelChip(tester, 'M');
      await tapLevelChip(tester, 'PL');

      await tester.enterText(suffixAffixField(), 'os');
      await settle(tester);

      await tapSave(tester);

      // 1 rule persisted.
      final rows = await db.select(db.morphologicalRules).get();
      expect(rows.length, equals(1),
          reason: 'D-90: mixed-axis rules must persist normally.');

      // No inline blocked reason visible.
      expect(find.byKey(const ValueKey('saveBlockedReasonText')), findsNothing,
          reason: 'D-90: inline reason must not render when save succeeds.');

      await teardownWidget(tester);
    },
  );

  // -------------------------------------------------------------------------
  // Case 3 — empty bindings NOT touched by D-90
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 3 — empty dim bindings → D-90 does NOT fire; an earlier '
    'validator blocks via _validationError instead',
    (tester) async {
      await seedNounDims();

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'No Bindings');
      await tapPosChip(tester, 'Noun (N)');
      // Intentionally NO level chip tapped — bindings.dims is empty.

      await tester.enterText(suffixAffixField(), 'os');
      await settle(tester);

      await tapSave(tester);

      // The D-13 "must bind at least one feature" validator fires, not
      // the D-90 snackbar. The inline D-90 reason key must be absent.
      expect(find.byKey(const ValueKey('saveBlockedReasonText')), findsNothing,
          reason:
              'D-90 must NOT claim credit for empty-bindings rules — a '
              'different upstream validator handles that.');

      // DB is empty.
      final rows = await db.select(db.morphologicalRules).get();
      expect(rows, isEmpty);

      await teardownWidget(tester);
    },
  );

  // -------------------------------------------------------------------------
  // Case 4 — only non-intrinsic binding → Save proceeds
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 4 — only non-intrinsic binding {number=PL} → persists',
    (tester) async {
      await seedNounDims();

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'Plural');
      await tapPosChip(tester, 'Noun (N)');
      await tapLevelChip(tester, 'PL');

      await tester.enterText(suffixAffixField(), 'os');
      await settle(tester);

      await tapSave(tester);

      final rows = await db.select(db.morphologicalRules).get();
      expect(rows.length, equals(1),
          reason: 'D-90: rules with only non-intrinsic bindings must '
              'persist normally.');

      await teardownWidget(tester);
    },
  );

  // -------------------------------------------------------------------------
  // Case 5 — WARN-3 multi-POS: gender intrinsic on Noun, non-intrinsic
  //           on Adjective; rule targets BOTH POS with binding on
  //           Adjective's gender id → PERSISTS regardless of POS order.
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 5 — WARN-3 multi-POS mixed intrinsicness: Adjective gender '
    'non-intrinsic allows the rule for BOTH Noun + Adjective',
    (tester) async {
      // Noun.Gender intrinsic
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounPosId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: mLevelId, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(
                    id: fLevelId, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              intrinsic: const Value(true),
            ),
          );
      // Adjective.Gender NON-intrinsic (same conceptual dim, different row).
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: adjPosId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: mLevelId, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(
                    id: fLevelId, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              // intrinsic: false (default)
            ),
          );

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'Masc Agreement');
      // Select BOTH POS with Adjective FIRST so the intersection row
      // renders Adjective's (non-intrinsic) gender dim row — the chip
      // tap then binds `{adjGenderId: M}`. Under WARN-3 the validator
      // iterates both POS: for Adjective the bound dim is non-intrinsic
      // (axis present), for Noun the bound dim id isn't in Noun's dim
      // map at all (the Noun gender dim is a different row with a
      // different id), so the loop never finds a non-intrinsic axis
      // for Noun — but Adjective's axis is enough to short-circuit to
      // `anyPosHasNonIntrinsicAxis = true`, and the rule is allowed.
      await tapPosChip(tester, 'Adjective (Adj)');
      await tapPosChip(tester, 'Noun (N)');
      await tapLevelChip(tester, 'M');

      await tester.enterText(suffixAffixField(), 'us');
      await settle(tester);

      await tapSave(tester);

      final rows = await db.select(db.morphologicalRules).get();
      expect(rows.length, equals(1),
          reason:
              'WARN-3: multi-POS mixed intrinsicness must persist when '
              'ANY pos yields a non-intrinsic axis.');

      // And no inline block was raised.
      expect(find.byKey(const ValueKey('saveBlockedReasonText')), findsNothing,
          reason: 'WARN-3: mixed-intrinsicness rule must not show the '
              'D-90 block text.');

      await teardownWidget(tester);
    },
  );

  // -------------------------------------------------------------------------
  // Case 6 — WARN-3 multi-POS all-intrinsic on bound dim → BLOCKED
  // -------------------------------------------------------------------------
  testWidgets(
    'Case 6 — WARN-3 multi-POS where no pos yields a non-intrinsic '
    'axis → BLOCKED',
    (tester) async {
      // Noun.Gender intrinsic (bindable)
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: nounPosId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: mLevelId, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(
                    id: fLevelId, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              intrinsic: const Value(true),
            ),
          );
      // Adjective.Gender ALSO intrinsic (same conceptual dim, both intrinsic)
      await db.into(db.dimensions).insert(
            DimensionsCompanion.insert(
              posId: adjPosId,
              name: 'Gender',
              ordering: const Value(0),
              levelsJson: encodeLevelsJson(const [
                DimensionLevel(
                    id: mLevelId, name: 'Masculine', abbr: 'M', ordering: 0),
                DimensionLevel(
                    id: fLevelId, name: 'Feminine', abbr: 'F', ordering: 1),
              ]),
              intrinsic: const Value(true),
            ),
          );

      await tester.pumpWidget(buildApp(
        child: const RuleEditorDialog(kind: RuleKind.inflectional),
      ));
      await settle(tester);

      await fillRuleName(tester, 'Masc Only');
      await tapPosChip(tester, 'Noun (N)');
      await tapPosChip(tester, 'Adjective (Adj)');
      await tapLevelChip(tester, 'M');

      await tester.enterText(suffixAffixField(), 'o');
      await settle(tester);

      await tapSave(tester);

      // Both POS have their gender dim marked intrinsic — no POS yields
      // a non-intrinsic axis → D-90 fires.
      expect(find.byKey(const ValueKey('saveBlockedReasonText')), findsOneWidget,
          reason: 'WARN-3: when every pos is intrinsic on the bound '
              'dim, the rule must be blocked.');

      final rows = await db.select(db.morphologicalRules).get();
      expect(rows, isEmpty,
          reason: 'WARN-3: blocked multi-POS rule must NOT persist.');

      await teardownWidget(tester);
    },
  );
}
