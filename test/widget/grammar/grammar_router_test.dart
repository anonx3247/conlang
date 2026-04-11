import 'dart:io';

import 'package:conlang_workbench/features/grammar/presentation/grammar_shell.dart';
import 'package:conlang_workbench/features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import 'package:conlang_workbench/features/grammar/presentation/typology/typology_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Widget + source-level tests for the plan 04-04 router surgery.
///
/// The real app router lives in `lib/router/app_router.dart`, but pumping it
/// requires a full ProviderScope + project selection + DB overrides. For the
/// route smoke tests we build a minimal GoRouter that mirrors the Grammar
/// branch shape (one `StatefulShellRoute.indexedStack` with four branches)
/// so we can verify each sub-route resolves to the expected widget class.
void main() {
  Widget buildApp(GoRouter router) => ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      );

  // In the real app, AppShell wraps the whole navigation shell in a Scaffold
  // so every sub-route has an ambient Material ancestor. This minimal
  // isolated router does the same by building an AppShell-substitute
  // Scaffold around the GrammarShell so route pages that use Material
  // widgets (DropdownButtonFormField in TypologyPage) find a Material.
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
                    path: '/grammar/inflectional',
                    builder: (_, _) => const InflectionalRulesPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/grammar/paradigm',
                    builder: (_, _) => const ParadigmViewerPage(),
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

  testWidgets('/grammar/inflectional renders InflectionalRulesPage',
      (tester) async {
    await tester
        .pumpWidget(buildApp(grammarOnlyRouter('/grammar/inflectional')));
    await tester.pumpAndSettle();
    expect(find.byType(InflectionalRulesPage), findsOneWidget);
  });

  testWidgets('/grammar/paradigm renders ParadigmViewerPage', (tester) async {
    await tester.pumpWidget(buildApp(grammarOnlyRouter('/grammar/paradigm')));
    await tester.pumpAndSettle();
    expect(find.byType(ParadigmViewerPage), findsOneWidget);
  });

  testWidgets('/grammar/typology renders TypologyPage', (tester) async {
    await tester.pumpWidget(buildApp(grammarOnlyRouter('/grammar/typology')));
    await tester.pumpAndSettle();
    expect(find.byType(TypologyPage), findsOneWidget);
  });

  test(
      'app_router.dart has no /morphology routes and has /grammar/* routes',
      () async {
    final file = await File('lib/router/app_router.dart').readAsString();
    expect(file.contains('/morphology'), isFalse,
        reason: 'All /morphology routes must be removed');
    expect(file.contains('/grammar/pos'), isTrue);
    expect(file.contains('/grammar/inflectional'), isTrue);
    expect(file.contains('/grammar/paradigm'), isTrue);
    expect(file.contains('/grammar/typology'), isTrue);
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
}
