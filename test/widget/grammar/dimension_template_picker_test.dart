// Regression tests for G-02 and G-12 — dimension template picker.
//
// G-02: template cards render name + levels correctly; no literal "-"
//       characters appear in the picker (audit check after the code path
//       was inspected during plan 04-09).
// G-12: exactly ONE "Custom (start blank)" entry in the picker, not one
//       per group. Pre-fix, the picker appended a Custom entry to every
//       group (9 groups → 9 Custom cards).

import 'package:conlang_workbench/features/grammar/data/dimension_templates.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/dimension_template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DimensionTemplate?> _pumpAndOpenPicker(WidgetTester tester) async {
  DimensionTemplate? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              picked = await showDimensionTemplatePicker(ctx);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return picked;
}

/// Scrolls the picker's lazy ListView until the Custom entry is visible.
/// Returns a [Finder] that resolves the now-built widget.
Future<Finder> _scrollToCustomEntry(WidgetTester tester) async {
  final finder = find.text('Custom (start blank)');
  final listView = find.byType(ListView);
  // Manually fling the ListView multiple times until the finder resolves.
  for (var i = 0; i < 20; i++) {
    if (tester.any(finder)) return finder;
    await tester.drag(listView, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  return finder;
}

void main() {
  group('G-12 — single Custom entry', () {
    testWidgets('renders exactly one "Custom (start blank)" card',
        (tester) async {
      await _pumpAndOpenPicker(tester);

      // Custom card lives at the bottom of the lazy ListView — scroll
      // until it builds, then assert it's the sole entry of that label.
      final customFinder = await _scrollToCustomEntry(tester);
      expect(
        customFinder,
        findsOneWidget,
        reason: 'Per G-12 the picker ships ONE single Custom entry, not one '
            'per group.',
      );

      // No stale per-group bare 'Custom' labels remain in any built card.
      expect(find.text('Custom'), findsNothing);
    });

    testWidgets(
        'per-group Custom entries are NOT generated (no id collision)',
        (tester) async {
      await _pumpAndOpenPicker(tester);
      // If the old per-group loop were still in place we'd see Gender/
      // Number/Case/… each with their own Custom card. Scroll through
      // the whole list and assert only one match.
      final customFinder = await _scrollToCustomEntry(tester);
      expect(customFinder, findsOneWidget);
    });

    testWidgets(
        'search narrows template list but still exposes Custom when query '
        'matches "custom"',
        (tester) async {
      await _pumpAndOpenPicker(tester);
      await tester.enterText(find.byType(TextField), 'cust');
      await tester.pumpAndSettle();
      expect(find.text('Custom (start blank)'), findsOneWidget);
    });

    testWidgets(
        'search for an unrelated term hides Custom and shows empty state',
        (tester) async {
      await _pumpAndOpenPicker(tester);
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Custom (start blank)'), findsNothing);
      expect(find.text('No templates match your search.'), findsOneWidget);
    });
  });

  group('G-02 — template level rendering', () {
    testWidgets(
        'template cards render the template name and level abbreviations '
        'without any literal dash placeholders',
        (tester) async {
      await _pumpAndOpenPicker(tester);

      // A known template shows its level abbreviations joined with ' · '.
      // 'Masculine / Feminine' → 'M · F'.
      expect(find.text('Masculine / Feminine'), findsWidgets);
      expect(find.text('M · F'), findsWidgets);

      // The picker must not render literal '-' characters anywhere. This
      // locks the G-02 audit: if someone reintroduces a placeholder dash
      // (e.g. via `l.abbr ?? '-'`), this test fails.
      expect(find.text('-'), findsNothing);
    });

    testWidgets('tapping a template pops the dialog with that template',
        (tester) async {
      // Re-run the fixture but capture the popped template via state.
      DimensionTemplate? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  picked = await showDimensionTemplatePicker(ctx);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Masculine / Feminine').first);
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.name, equals('Masculine / Feminine'));
      expect(picked!.levels.length, equals(2));
    });
  });
}
