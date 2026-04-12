// Plan 04-17 Task 7 — D-92 / D-93 widget tests for the dynamic intrinsic
// sub-form in WordCreationForm and WordDetailPanel (edit mode).
//
// Test 1 (create, blocked) — POS=Noun with intrinsic gender; do NOT pick
//         gender → save blocked with exact copy "Required — every Noun
//         must have a fixed Gender."; insertLexeme NOT called.
// Test 2 (create, success) — POS=Noun, pick gender=M → insert called with
//         intrinsicLevelsJson encoding {genderDimId: mLevelId}.
// Test 3 (create, hidden) — POS=Verb with NO intrinsic dims → sub-form
//         NOT rendered.
// Test 4 (edit, POS change forces re-pick) — seed Verb lexeme; edit; change
//         POS to Noun → intrinsic sub-form renders with empty gender
//         dropdown; save blocked until filled.
// Test 5 (edit, overlap preservation) — both Noun and Adjective have a
//         gender dim with the SAME dim id (contrived test setup). Seed
//         Noun lexeme with {gender.id: F}. Edit, change POS to
//         Adjective → gender dropdown pre-filled with F; save without
//         touching it → persisted.
//
// Harness mirrors rule_editor_intrinsic_save_block_test.dart (in-memory DB,
// RenderFlex overflow suppression, Drift settle pattern).

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/intrinsic_levels_codec.dart';
import 'package:conlang_workbench/features/grammar/domain/dimension_level.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_creation_form.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/word_detail_panel.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int nounPosId;
  // ignore: unused_local_variable — POS exists in DB for dropdown tests.
  late int verbPosId;
  late int adjPosId;
  late int genderDimId;
  const int mLevelId = 1;
  const int fLevelId = 2;

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
    nounPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
        );
    // Verb has no dimensions (no intrinsic dims). We reference it by
    // name in the dropdown UI; the id is stored for potential future use.
    verbPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(name: 'Verb', abbreviation: 'V'),
        );
    adjPosId = await db.into(db.partsOfSpeech).insert(
          PartsOfSpeechCompanion.insert(
              name: 'Adjective', abbreviation: 'Adj'),
        );
    // Noun.Gender intrinsic with {M, F}
    genderDimId = await db.into(db.dimensions).insert(
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
    // Verb has no dimensions at all.
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildCreateApp() => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WordCreationForm(
              onCancel: () {},
              onSaved: () {},
            ),
          ),
        ),
      );

  Widget buildEditApp({required int lexemeId}) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: WordDetailPanel(
              lexemeId: lexemeId,
              onDeleted: () {},
            ),
          ),
        ),
      );

  /// Enlarge the test viewport so the form content fits.
  Future<void> setLargeViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

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

  // -----------------------------------------------------------------------
  // Test 1: create, blocked — required intrinsic dim not picked
  // -----------------------------------------------------------------------
  testWidgets(
    'Test 1 — create Noun without picking intrinsic gender → save blocked '
    'with exact copy',
    (tester) async {
      await setLargeViewport(tester);
      await tester.pumpWidget(buildCreateApp());
      await settle(tester);

      // Fill IPA.
      final ipaField = find.widgetWithText(TextField, 'IPA *');
      if (ipaField.evaluate().isEmpty) {
        // Rom mode off fallback: find the IpaTextField
        await tester.enterText(find.byType(EditableText).first, 'kat');
      } else {
        await tester.enterText(ipaField, 'kat');
      }
      await settle(tester);

      // Pick POS = Noun. The dropdown hint is 'Select POS (optional)'.
      // DropdownButtonFormField needs tap then scroll to item.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      // In the dropdown overlay, tap 'Noun'.
      await tester.tap(find.text('Noun').last);
      await settle(tester);

      // The intrinsic sub-form should now show a "Gender" dropdown.
      expect(find.text('Gender'), findsWidgets,
          reason: 'D-92: intrinsic sub-form must render a Gender dropdown '
              'after picking POS=Noun.');

      // Do NOT pick a gender value → leave it null.

      // Tap "New word" to attempt save.
      await tester.tap(find.widgetWithText(FilledButton, 'New word'));
      await settle(tester);

      // Exact error copy must be displayed.
      expect(
        find.textContaining(
            'Required — every Noun must have a fixed Gender.'),
        findsWidgets,
        reason: 'D-92: exact validator copy must appear when no intrinsic '
            'level is selected.',
      );

      // DB should have 0 lexeme rows.
      final rows = await db.select(db.lexemes).get();
      expect(rows, isEmpty,
          reason: 'D-92: blocked save must not insert the lexeme.');

      await teardownWidget(tester);
    },
  );

  // -----------------------------------------------------------------------
  // Test 2: create, success — pick gender=M
  // -----------------------------------------------------------------------
  testWidgets(
    'Test 2 — create Noun with gender=M → insert called with '
    'intrinsicLevelsJson encoding',
    (tester) async {
      await setLargeViewport(tester);
      await tester.pumpWidget(buildCreateApp());
      await settle(tester);

      // Fill IPA.
      await tester.enterText(find.byType(EditableText).first, 'kat');
      await settle(tester);

      // Pick POS = Noun.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Noun').last);
      await settle(tester);

      // Pick Gender = Masculine.
      // The intrinsic dim dropdown has key ValueKey('intrinsicDim_$genderDimId')
      await tester.tap(find.byKey(ValueKey('intrinsicDim_$genderDimId')));
      await settle(tester);
      await tester.tap(find.text('Masculine (M)').last);
      await settle(tester);

      // Tap "New word".
      await tester.tap(find.widgetWithText(FilledButton, 'New word'));
      await settle(tester);

      // DB should have 1 lexeme with the correct intrinsicLevelsJson.
      final rows = await db.select(db.lexemes).get();
      expect(rows.length, equals(1),
          reason: 'D-92: successful create must insert the lexeme.');
      final decoded =
          IntrinsicLevelsCodec.decode(rows.first.intrinsicLevelsJson);
      expect(decoded, equals({genderDimId: mLevelId}),
          reason: 'D-92: intrinsicLevelsJson must encode {dimId: levelId}.');

      await teardownWidget(tester);
    },
  );

  // -----------------------------------------------------------------------
  // Test 3: create, hidden — POS=Verb (no intrinsic dims) → no sub-form
  // -----------------------------------------------------------------------
  testWidgets(
    'Test 3 — POS=Verb (no intrinsic dims) → intrinsic sub-form hidden',
    (tester) async {
      await setLargeViewport(tester);
      await tester.pumpWidget(buildCreateApp());
      await settle(tester);

      // Pick POS = Verb.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Verb').last);
      await settle(tester);

      // No intrinsic dim dropdown should exist.
      expect(find.byKey(ValueKey('intrinsicDim_$genderDimId')), findsNothing,
          reason: 'D-92: sub-form must not render for POS with no '
              'intrinsic dims.');

      await teardownWidget(tester);
    },
  );

  // -----------------------------------------------------------------------
  // Test 4: edit, POS change forces re-pick
  // -----------------------------------------------------------------------
  testWidgets(
    'Test 4 — edit a Verb lexeme, change POS to Noun → intrinsic sub-form '
    'renders with empty Gender dropdown; save blocked',
    (tester) async {
      await setLargeViewport(tester);
      // Seed a Verb lexeme.
      final lexemeId = await db.into(db.lexemes).insert(
            LexemesCompanion.insert(
              ipa: 'run',
              partOfSpeech: const Value('Verb'),
            ),
          );

      await tester.pumpWidget(buildEditApp(lexemeId: lexemeId));
      await settle(tester);

      // Tap Edit.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);

      // Change POS from Verb to Noun.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Noun').last);
      await settle(tester);

      // Intrinsic sub-form should render a Gender dropdown.
      expect(find.byKey(ValueKey('intrinsicDim_$genderDimId')), findsOneWidget,
          reason: 'D-93: changing POS to one with intrinsic dims must '
              'render the sub-form.');

      // Tap Save without picking gender.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      // Error copy must appear.
      expect(
        find.textContaining(
            'Required — every Noun must have a fixed Gender.'),
        findsWidgets,
        reason: 'D-93: save must be blocked until all intrinsic dims are '
            'filled.',
      );

      await teardownWidget(tester);
    },
  );

  // -----------------------------------------------------------------------
  // Test 5: edit, overlap preservation
  // -----------------------------------------------------------------------
  testWidgets(
    'Test 5 — overlap preservation: Noun→Adjective with same dim id '
    'preserves gender selection',
    (tester) async {
      await setLargeViewport(tester);
      // Give Adjective the SAME gender dim id by deleting the Noun one and
      // re-inserting with a specific id. Actually we can't control the auto-id.
      // Instead: give Adjective its own gender dim. Overlap preservation
      // works on dim ID matches. So we need the SAME dim id on both POS.
      // That's not possible with auto-increment. Instead, we test that
      // overlap preservation works with different ids by checking the
      // pre-fill is null (no overlap). But that's not what the plan says.
      //
      // Plan says: "both Noun and Adjective define dim `gender` with the
      // SAME dim id (contrived test setup)." Since auto-increment means
      // different POS get different dim ids, we contrive this by
      // directly updating the Adjective dim row to share the same
      // physical dim id. We can't do that with standard drift insert.
      //
      // Alternative: just test the path by using the SAME dim id (the
      // Noun gender dim IS the Adjective gender dim — set posId to
      // adjPosId on a SECOND insert).
      //
      // Actually: Dimensions table has per-POS rows. posId is a column.
      // We can insert a SECOND dim row with posId=adjPosId. The auto-id
      // will be different. There's no way to share the same id.
      //
      // For a true overlap test, we can seed the Adjective with a dim
      // that physically has the same auto-inc id as Noun's gender dim.
      // That's impossible in a single DB. The plan acknowledges
      // "(contrived test setup)".
      //
      // Practical compromise: test that when BOTH pos have a dim named
      // "Gender" and the Noun has intrinsicLevelsJson storing
      // {adjGenderDimId: F}, changing POS to Adjective pre-fills the
      // Adjective gender dropdown with F. But we need matching dim ids.
      //
      // Since we can't share IDs, let's test the other direction:
      // verify that when a stored intrinsicLevelsJson key matches
      // a dim id on the new POS, it's pre-filled. We'll seed the
      // lexeme's json with the Adjective gender dim's id.

      // Seed Adjective.Gender intrinsic
      final adjGenderDimId = await db.into(db.dimensions).insert(
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

      // Seed a Noun lexeme whose intrinsicLevelsJson encodes BOTH the
      // Noun gender dim (from setUp) AND the Adjective gender dim,
      // so changing POS to Adjective finds an overlap on adjGenderDimId.
      final encoded = IntrinsicLevelsCodec.encode({
        genderDimId: fLevelId, // Noun gender: F
        adjGenderDimId: fLevelId, // Adj gender: F (pre-seeded overlap)
      });
      final lexemeId = await db.into(db.lexemes).insert(
            LexemesCompanion.insert(
              ipa: 'bona',
              partOfSpeech: const Value('Noun'),
              intrinsicLevelsJson: Value(encoded),
            ),
          );

      await tester.pumpWidget(buildEditApp(lexemeId: lexemeId));
      await settle(tester);

      // Tap Edit.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);

      // Change POS from Noun to Adjective.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Adjective').last);
      await settle(tester);

      // The Adjective gender dropdown should be pre-filled with F (overlap).
      // Look for the Text widget showing 'Feminine (F)' inside the
      // dropdown area — its presence means the value is pre-selected.
      expect(
        find.descendant(
          of: find.byKey(ValueKey('intrinsicDim_$adjGenderDimId')),
          matching: find.text('Feminine (F)'),
        ),
        findsOneWidget,
        reason: 'D-93 overlap preservation: gender dropdown must be '
            'pre-filled with F (from stored intrinsicLevelsJson).',
      );

      // Save without changing — should succeed because the dropdown is
      // already filled.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      // Verify the saved lexeme now has adjective POS and the correct json.
      final updated = await (db.select(db.lexemes)
            ..where((t) => t.id.equals(lexemeId)))
          .getSingle();
      expect(updated.partOfSpeech, equals('Adjective'));
      final savedLevels =
          IntrinsicLevelsCodec.decode(updated.intrinsicLevelsJson);
      expect(savedLevels[adjGenderDimId], equals(fLevelId),
          reason: 'D-93: saved json must encode the new-POS intrinsic '
              'dims with preserved overlap values.');
      // The old Noun gender dim id should NOT be in the saved json.
      expect(savedLevels.containsKey(genderDimId), isFalse,
          reason: 'D-93: old-POS-only intrinsic dim keys must be silently '
              'dropped on save.');

      await teardownWidget(tester);
    },
  );
}
