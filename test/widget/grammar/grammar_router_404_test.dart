// Plan 04-13 Task 5 — router 404 test for D-48 (3 sub-tabs) and D-53
// (hard 404 on retired /grammar/paradigm and /grammar/inflectional with
// NO silent redirect).
//
// We pump a minimal isolated router that mirrors the real Grammar branch
// shape from app_router.dart (3 sub-routes + top-level errorBuilder) so
// the test does not need a full ProviderScope + DB setup. The shape MUST
// stay in lockstep with lib/router/app_router.dart — any deviation is a
// test bug.

import 'package:conlang_workbench/features/grammar/presentation/grammar_shell.dart';
import 'package:conlang_workbench/features/grammar/presentation/inflections/inflections_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/typology/typology_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildApp(GoRouter router) => ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      );

  GoRouter grammarRouter(String initial) => GoRouter(
        initialLocation: initial,
        // D-53 hard 404 — matches the real router's errorBuilder shape.
        errorBuilder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('404')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go('/grammar/pos'),
                  child: const Text('Back to Grammar'),
                ),
              ],
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: '/grammar',
            redirect: (_, _) => '/grammar/pos',
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: GrammarShell(navigationShell: shell),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/grammar/pos',
                    builder: (_, _) => const PosDimensionsPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/grammar/inflections',
                    builder: (_, _) => const InflectionsPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/grammar/typology',
                    builder: (_, _) => const TypologyPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  testWidgets('D-53: /grammar/paradigm returns hard 404 (no redirect)',
      (tester) async {
    await tester.pumpWidget(buildApp(grammarRouter('/grammar/paradigm')));
    await tester.pumpAndSettle();

    // Hard 404 screen visible.
    expect(find.text('Page not found'), findsOneWidget);
    // And — critically — no silent redirect to the new Inflections page.
    expect(find.byType(InflectionsPage), findsNothing);
  });

  testWidgets('D-53: /grammar/inflectional returns hard 404', (tester) async {
    await tester.pumpWidget(buildApp(grammarRouter('/grammar/inflectional')));
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.byType(InflectionsPage), findsNothing);
  });

  testWidgets('D-48: Grammar sidebar has exactly 3 entries',
      (tester) async {
    await tester.pumpWidget(buildApp(grammarRouter('/grammar/pos')));
    await tester.pumpAndSettle();

    // The three sidebar labels.
    expect(find.text('POS & Dimensions'), findsOneWidget);
    expect(find.text('Inflections'), findsOneWidget);
    expect(find.text('Typology'), findsOneWidget);
    // And the old labels are gone.
    expect(find.text('Paradigm Viewer'), findsNothing);
    expect(find.text('Inflectional Rules'), findsNothing);
  });

  testWidgets('D-48: /grammar/inflections renders InflectionsPage',
      (tester) async {
    await tester.pumpWidget(buildApp(grammarRouter('/grammar/inflections')));
    await tester.pumpAndSettle();
    expect(find.byType(InflectionsPage), findsOneWidget);
  });

  testWidgets('/grammar top-level redirect still goes to /grammar/pos',
      (tester) async {
    await tester.pumpWidget(buildApp(grammarRouter('/grammar')));
    await tester.pumpAndSettle();
    expect(find.byType(PosDimensionsPage), findsOneWidget);
  });
}
