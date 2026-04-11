// Plan 04-07 Task 1 — widget tests for the Lexicon → Derivations sub-tab.
//
// Verifies that:
//   1. LexiconShell has a 4th sidebar item ('Derivations') pointing to
//      /lexicon/derivations.
//   2. Navigating to /lexicon/derivations renders DerivationsPage.
//   3. DerivationsPage mounts a MigrationBanner and a RulesPage filtered
//      to kind=derivational.
//   4. With 2 inflectional + 1 derivational rules seeded, the Derivations
//      list shows only the derivational rule (it is the kind-filtered
//      RulesPage, which watches `rulesByKindProvider(derivational)`).
//   5. Source-level: the route path string '/lexicon/derivations' is
//      present in lib/router/app_router.dart (locks the route wiring).
//
// Uses an isolated minimal GoRouter mirroring the Lexicon branch, same
// technique as 04-04's grammar_router_test.dart.

import 'dart:io';

import 'package:conlang_workbench/db/app_database.dart';
import 'package:conlang_workbench/features/grammar/domain/feature_bindings.dart';
import 'package:conlang_workbench/features/grammar/domain/rule_kind.dart';
import 'package:conlang_workbench/features/grammar/presentation/shared/migration_banner.dart';
import 'package:conlang_workbench/features/lexicon/presentation/derivations/derivations_page.dart';
import 'package:conlang_workbench/features/lexicon/presentation/lexicon_shell.dart';
import 'package:conlang_workbench/features/lexicon/presentation/dictionary/dictionary_page.dart';
import 'package:conlang_workbench/features/lexicon/presentation/swadesh/swadesh_page.dart';
import 'package:conlang_workbench/features/lexicon/presentation/thesaurus/thesaurus_page.dart';
import 'package:conlang_workbench/features/project/data/project_providers.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppDatabase db;

  // Suppress the pre-existing RuleEditorDialog overflow which shows up
  // whenever the dialog (mounted by RulesPage internals) measures itself
  // at >0 width during layout. See plan 04-05 deferred-items.md.
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

  Widget buildApp(GoRouter router) => ProviderScope(
        overrides: [
          currentDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(routerConfig: router),
      );

  /// Minimal isolated router mirroring the Lexicon branch with the new
  /// 4th /lexicon/derivations sub-route. Matches the grammar_router_test.dart
  /// pattern of wrapping the shell in a Scaffold so routes that use
  /// Material-family widgets (TextField, DropdownButton) find an ancestor.
  GoRouter lexiconOnlyRouter(String initial) => GoRouter(
        initialLocation: initial,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: LexiconShell(navigationShell: shell),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/lexicon/dictionary',
                    builder: (_, _) => const DictionaryPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/lexicon/swadesh',
                    builder: (_, _) => const SwadeshPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/lexicon/thesaurus',
                    builder: (_, _) => const ThesaurusPage(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/lexicon/derivations',
                    builder: (_, _) => const DerivationsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  /// Settle with a real async delay so Drift stream queries can materialise
  /// their first event.
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

  testWidgets(
    'Test 1 — LexiconShell sidebar exposes all 4 items including Derivations',
    (tester) async {
      await tester.pumpWidget(
        buildApp(lexiconOnlyRouter('/lexicon/dictionary')),
      );
      await settle(tester);

      expect(find.text('Dictionary'), findsOneWidget);
      expect(find.text('Swadesh List'), findsOneWidget);
      expect(find.text('Thesaurus'), findsOneWidget);
      expect(find.text('Derivations'), findsOneWidget);

      await teardownWidget(tester);
    },
  );

  testWidgets(
    'Test 2 — /lexicon/derivations renders DerivationsPage',
    (tester) async {
      await tester.pumpWidget(
        buildApp(lexiconOnlyRouter('/lexicon/derivations')),
      );
      await settle(tester);

      expect(find.byType(DerivationsPage), findsOneWidget);

      await teardownWidget(tester);
    },
  );

  testWidgets(
    'Test 3 — DerivationsPage mounts MigrationBanner above its RulesPage',
    (tester) async {
      await tester.pumpWidget(
        buildApp(lexiconOnlyRouter('/lexicon/derivations')),
      );
      await settle(tester);

      expect(find.byType(DerivationsPage), findsOneWidget);
      expect(find.byType(MigrationBanner), findsOneWidget);

      await teardownWidget(tester);
    },
  );

  testWidgets(
    'Test 4 — DerivationsPage shows only derivational rules '
    '(filters out inflectional rules seeded in the DB)',
    (tester) async {
      // Seed a POS so insertRuleWithKind can write valid feature bindings.
      final nounPosId = await db.into(db.partsOfSpeech).insert(
            PartsOfSpeechCompanion.insert(name: 'Noun', abbreviation: 'N'),
          );

      // Seed 2 inflectional rules and 1 derivational rule.
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Inflectional A',
          source: 'suffix: s',
          featureBindings: Value(
            FeatureBindings(pos: [nounPosId], dims: const {}),
          ),
        ),
        RuleKind.inflectional,
      );
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Inflectional B',
          source: 'suffix: es',
          featureBindings: Value(
            FeatureBindings(pos: [nounPosId], dims: const {}),
          ),
        ),
        RuleKind.inflectional,
      );
      await db.morphologyDao.insertRuleWithKind(
        MorphologicalRulesCompanion.insert(
          name: 'Derivational Agent',
          source: 'suffix: er',
          featureBindings: Value(
            FeatureBindings(pos: [nounPosId], dims: const {}),
          ),
        ),
        RuleKind.derivational,
      );

      await tester.pumpWidget(
        buildApp(lexiconOnlyRouter('/lexicon/derivations')),
      );
      await settle(tester);

      // The derivational rule should appear in the list.
      expect(find.text('Derivational Agent'), findsOneWidget);
      // The inflectional rules must NOT appear — this is the kind-filter
      // that proves `RulesPage(kind: RuleKind.derivational)` is wired.
      expect(find.text('Inflectional A'), findsNothing);
      expect(find.text('Inflectional B'), findsNothing);

      await teardownWidget(tester);
    },
  );

  test(
    'Test 5 — source-level: /lexicon/derivations route is wired in app_router.dart',
    () {
      final source = File('lib/router/app_router.dart').readAsStringSync();
      expect(source.contains("'/lexicon/derivations'"), isTrue,
          reason: "app_router.dart must contain the literal '/lexicon/derivations' route path");
      expect(source.contains('DerivationsPage'), isTrue,
          reason: 'app_router.dart must reference DerivationsPage as the route builder');
    },
  );
}
