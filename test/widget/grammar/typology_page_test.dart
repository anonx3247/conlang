import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/data/typology_providers.dart';
import 'package:conlang_workbench/features/grammar/presentation/typology/typology_page.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for plan 04-04 Task 3: TypologyPage form with auto-save.
void main() {
  late AppDatabase db;

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
            body: SizedBox(width: 1000, height: 800, child: child),
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
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<String?> readKey(String key) async {
    final row = await (db.select(db.projectSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  testWidgets('renders the page title and three labeled sections',
      (tester) async {
    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    expect(find.text('Typology'), findsOneWidget);
    expect(find.text('Alignment'), findsOneWidget);
    expect(find.text('Basic Word Order'), findsOneWidget);
    expect(find.text('Modality Strategy'), findsOneWidget);

    await teardownWidget(tester);
  });

  testWidgets('each section shows an info tooltip icon', (tester) async {
    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    // Three info_outline icons — one per section.
    expect(find.byIcon(Icons.info_outline), findsNWidgets(3));

    await teardownWidget(tester);
  });

  testWidgets('selecting alignment writes typology.alignment',
      (tester) async {
    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    // Open the Alignment dropdown. Three DropdownButtonFormFields — the
    // first one (alignment) is the first widget of that type.
    final alignmentField =
        find.byType(DropdownButtonFormField<String>).first;
    await tester.tap(alignmentField);
    await settle(tester);
    // Pick "Ergative-Absolutive" from the popup.
    await tester.tap(find.text('Ergative-Absolutive').last);
    await settle(tester);

    expect(await readKey('typology.alignment'), equals('erg_abs'));

    await teardownWidget(tester);
  });

  testWidgets('selecting word order writes typology.word_order',
      (tester) async {
    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    final wordOrderField =
        find.byType(DropdownButtonFormField<String>).at(1);
    await tester.tap(wordOrderField);
    await settle(tester);
    await tester.tap(find.text('SOV').last);
    await settle(tester);

    expect(await readKey('typology.word_order'), equals('SOV'));

    await teardownWidget(tester);
  });

  testWidgets('selecting modality writes typology.modality', (tester) async {
    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    final modalityField =
        find.byType(DropdownButtonFormField<String>).at(2);
    await tester.tap(modalityField);
    await settle(tester);
    await tester.tap(find.text('Analytic').last);
    await settle(tester);

    expect(await readKey('typology.modality'), equals('analytic'));

    await teardownWidget(tester);
  });

  testWidgets(
    'no save button — form auto-saves on each selection (D-35)',
    (tester) async {
      await tester.pumpWidget(buildApp(const TypologyPage()));
      await settle(tester);

      // No ElevatedButton / FilledButton labelled "Save" anywhere on the page.
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Save'), findsNothing);

      await teardownWidget(tester);
    },
  );

  testWidgets('initial values reflect existing project_settings rows',
      (tester) async {
    // Pre-seed all three keys.
    await writeTypologyKey(db, 'typology.alignment', 'nom_acc');
    await writeTypologyKey(db, 'typology.word_order', 'VSO');
    await writeTypologyKey(db, 'typology.modality', 'synthetic');

    await tester.pumpWidget(buildApp(const TypologyPage()));
    await settle(tester);

    // The selected dropdown values render the display labels of the seeded
    // keys — just find them in the form.
    expect(find.text('Nominative-Accusative'), findsWidgets);
    expect(find.text('VSO'), findsWidgets);
    expect(find.text('Synthetic'), findsWidgets);

    await teardownWidget(tester);
  });
}
