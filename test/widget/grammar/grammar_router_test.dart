import 'dart:io';

import 'package:conlang_workbench/features/grammar/presentation/grammar_shell.dart';
import 'package:conlang_workbench/features/grammar/presentation/inflections/inflections_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/typology/typology_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Widget + source-level tests for the Grammar router branch.
///
/// Plan 04-13 update: the router branch was collapsed from 4 sub-routes
/// to 3. `/grammar/paradigm` and `/grammar/inflectional` are GONE — they
/// now return a hard 404 via the errorBuilder (D-53). The new
/// `/grammar/inflections` sub-tab hosts a stacked paradigm + rules layout.
///
/// The real app router lives in `lib/router/app_router.dart`, but pumping
/// it requires a full ProviderScope + project selection + DB overrides.
/// For the route smoke tests we build a minimal GoRouter that mirrors the
/// Grammar branch shape so we can verify each sub-route resolves to the
/// expected widget class.
void main() {
  Widget buildApp(GoRouter router) => ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      );

  // Minimal isolated router — mirrors the 3-sub-tab Grammar branch.
  GoRouter grammarOnlyRouter(String initial) => GoRouter(
        initialLocation: initial,
        routes: [
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

  testWidgets('/grammar/pos renders PosDimensionsPage', (tester) async {
    await tester.pumpWidget(buildApp(grammarOnlyRouter('/grammar/pos')));
    await tester.pumpAndSettle();
    expect(find.byType(PosDimensionsPage), findsOneWidget);
  });

  testWidgets('/grammar/inflections renders InflectionsPage',
      (tester) async {
    await tester
        .pumpWidget(buildApp(grammarOnlyRouter('/grammar/inflections')));
    await tester.pumpAndSettle();
    expect(find.byType(InflectionsPage), findsOneWidget);
  });

  testWidgets('/grammar/typology renders TypologyPage', (tester) async {
    await tester.pumpWidget(buildApp(grammarOnlyRouter('/grammar/typology')));
    await tester.pumpAndSettle();
    expect(find.byType(TypologyPage), findsOneWidget);
  });

  test(
      'app_router.dart has no /morphology routes and has the 3-sub-tab '
      '/grammar branch (D-48)',
      () async {
    final file = await File('lib/router/app_router.dart').readAsString();
    expect(file.contains('/morphology'), isFalse,
        reason: 'All /morphology routes must be removed');
    expect(file.contains('/grammar/pos'), isTrue);
    // D-53 — old routes physically removed from the router.
    expect(
      file.contains("'/grammar/paradigm'"),
      isFalse,
      reason: '/grammar/paradigm must be deleted (D-53 hard 404)',
    );
    expect(
      file.contains("'/grammar/inflectional'"),
      isFalse,
      reason: '/grammar/inflectional must be deleted (D-53 hard 404)',
    );
    // D-48 — new sub-tab.
    expect(file.contains("'/grammar/inflections'"), isTrue);
    expect(file.contains('/grammar/typology'), isTrue);
    // D-53 — errorBuilder must be present for the hard 404 behavior.
    expect(file.contains('errorBuilder'), isTrue);
  });

  test('app_shell.dart has Grammar tab enabled and no Morphology tab',
      () async {
    final file =
        await File('lib/shared/widgets/app_shell.dart').readAsString();
    expect(file.contains("_TabItem(label: 'Morphology'"), isFalse);
    expect(file.contains("_TabItem(label: 'Grammar'"), isTrue);
    expect(
      RegExp(r"label: 'Grammar'[^)]*enabled:\s*true").hasMatch(file),
      isTrue,
      reason: 'Grammar tab must be enabled',
    );
  });

  test('morphology_shell.dart has been physically deleted', () async {
    expect(
      File('lib/features/morphology/presentation/morphology_shell.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('morphology pos_page.dart has been physically deleted', () async {
    expect(
      File('lib/features/morphology/presentation/pos/pos_page.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('inflectional_rules_page.dart has been physically deleted (plan 04-13)',
      () async {
    expect(
      File('lib/features/grammar/presentation/inflectional_rules/'
              'inflectional_rules_page.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('paradigm_viewer_page.dart has been physically deleted (plan 04-13)',
      () async {
    expect(
      File('lib/features/grammar/presentation/paradigm_viewer/'
              'paradigm_viewer_page.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('cell_override_dialog.dart is PRESERVED for Lexicon host (D-54)',
      () async {
    expect(
      File('lib/features/grammar/presentation/paradigm_viewer/'
              'cell_override_dialog.dart')
          .existsSync(),
      isTrue,
    );
  });
}
