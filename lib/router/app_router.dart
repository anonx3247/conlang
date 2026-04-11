import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/grammar/presentation/grammar_shell.dart';
import '../features/grammar/presentation/inflectional_rules/inflectional_rules_page.dart';
import '../features/grammar/presentation/paradigm_viewer/paradigm_viewer_page.dart';
import '../features/grammar/presentation/pos_dimensions/pos_dimensions_page.dart';
import '../features/grammar/presentation/typology/typology_page.dart';
import '../features/lexicon/presentation/derivations/derivations_page.dart';
import '../features/lexicon/presentation/dictionary/dictionary_page.dart';
import '../features/lexicon/presentation/lexicon_shell.dart';
import '../features/lexicon/presentation/swadesh/swadesh_page.dart';
import '../features/lexicon/presentation/thesaurus/thesaurus_page.dart';
import '../features/phonology/presentation/inventory/inventory_page.dart';
import '../features/phonology/presentation/phonology_shell.dart';
import '../features/phonology/presentation/sound_rules/sound_rules_page.dart';
import '../shared/widgets/app_shell.dart';

part 'app_router.g.dart';

/// Placeholder page for tabs not yet implemented.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            section,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming in a future phase.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// The root GoRouter, provided via Riverpod.
///
/// Uses a two-level StatefulShellRoute architecture:
///  - Outer: AppShell — top-level tab bar (Phonology, Grammar, Lexicon, Culture)
///  - Inner: per-tab shells (PhonologyShell, GrammarShell, LexiconShell)
///
/// Phase 4 plan 04-04 surgery: the old Morphology branch (index 1) is
/// replaced by the new Grammar branch, and the old placeholder Grammar
/// branch is deleted. Final branch order matches the AppShell `_tabs`
/// list: 0=Phonology, 1=Grammar, 2=Lexicon, 3=Culture.
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/phonology/inventory',
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
          // Four sub-routes in the order shown in GrammarShell's sidebar.
          // The top-level `/grammar` path redirects to the first sub-route.
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

          // Branch 3: Culture (Phase 5 placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/culture',
                builder: (_, _) => const _ComingSoonPage(section: 'Culture'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
