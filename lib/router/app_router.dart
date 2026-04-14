import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app.dart';

import '../features/grammar/presentation/grammar_shell.dart';
import '../features/grammar/presentation/inflections/inflections_page.dart';
import '../features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import '../features/grammar/presentation/typology/typology_page.dart';
import '../features/lexicon/presentation/derivations/derivations_page.dart';
import '../features/lexicon/presentation/dictionary/dictionary_page.dart';
import '../features/lexicon/presentation/lexicon_shell.dart';
import '../features/lexicon/presentation/swadesh/swadesh_page.dart';
import '../features/lexicon/presentation/thesaurus/thesaurus_page.dart';
import '../features/phonology/presentation/inventory/inventory_page.dart';
import '../features/phonology/presentation/inventory/natural_classes_page.dart';
import '../features/phonology/presentation/phonology_shell.dart';
import '../features/phonology/presentation/sound_rules/sound_rules_page.dart';
import '../shared/widgets/app_shell.dart';

part 'app_router.g.dart';


/// The root GoRouter, provided via Riverpod.
///
/// Uses a two-level StatefulShellRoute architecture:
///  - Outer: AppShell — top-level tab bar (Phonology, Grammar, Lexicon)
///  - Inner: per-tab shells (PhonologyShell, GrammarShell, LexiconShell)
///
/// Phase 4 plan 04-04 surgery: the old Morphology branch (index 1) is
/// replaced by the new Grammar branch, and the old placeholder Grammar
/// branch is deleted. Final branch order matches the AppShell `_tabs`
/// list: 0=Phonology, 1=Grammar, 2=Lexicon.
@riverpod
GoRouter appRouter(Ref ref) {
  // Import the shared navigator key so PlatformMenuBar callbacks can
  // obtain a valid BuildContext for showDialog / ScaffoldMessenger.
  // ignore: depend_on_referenced_packages
  final navKey = rootNavigatorKey;

  return GoRouter(
    navigatorKey: navKey,
    initialLocation: '/phonology/inventory',
    // D-53 / plan 04-13: hard 404 on retired routes like /grammar/paradigm
    // and /grammar/inflectional. No silent redirect — the user explicitly
    // rejected the redirect approach; bookmarked/cached sessions visiting
    // the old routes land on this screen with a "Back to Grammar" button.
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Phonology (Phase 1)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/phonology',
                redirect: (_, _) => '/phonology/inventory',
              ),
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) =>
                    PhonologyShell(navigationShell: navigationShell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/phonology/inventory',
                        builder: (_, _) => const InventoryPage(),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/phonology/natural-classes',
                        builder: (_, _) => const NaturalClassesPage(),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/phonology/sound-rules',
                        builder: (_, _) => const SoundRulesPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Grammar (Phase 4)
          //
          // Plan 04-13 / D-48 — collapsed from 4 sub-routes to 3. The
          // `/grammar/inflectional` and `/grammar/paradigm` routes have
          // been DELETED (no redirect — D-53 hard 404 via errorBuilder
          // above). Their content is merged into the new `/grammar/
          // inflections` sub-tab hosting a stacked paradigm+rules layout.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/grammar',
                redirect: (_, _) => '/grammar/pos',
              ),
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) =>
                    GrammarShell(navigationShell: navigationShell),
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
          ),

          // Branch 2: Lexicon (Phase 3)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lexicon',
                redirect: (_, __) => '/lexicon/dictionary',
              ),
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) =>
                    LexiconShell(navigationShell: navigationShell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/lexicon/dictionary',
                        builder: (context, state) => DictionaryPage(
                          createWithMeaning:
                              state.uri.queryParameters['create'] == 'true'
                                  ? state.uri.queryParameters['meaning']
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/lexicon/swadesh',
                        builder: (_, __) => const SwadeshPage(),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/lexicon/thesaurus',
                        builder: (_, __) => const ThesaurusPage(),
                      ),
                    ],
                  ),
                  // Phase 4 plan 04-07: 4th sub-route — derivational rules
                  // relocated into the Lexicon per D-36 / D-37. Reuses
                  // RulesPage with the derivational kind filter.
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/lexicon/derivations',
                        builder: (_, __) => const DerivationsPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

        ],
      ),
    ],
  );
}
