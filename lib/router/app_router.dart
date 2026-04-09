import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/lexicon/presentation/dictionary/dictionary_page.dart';
import '../features/lexicon/presentation/lexicon_shell.dart';
import '../features/lexicon/presentation/swadesh/swadesh_page.dart';
import '../features/lexicon/presentation/thesaurus/thesaurus_page.dart';
import '../features/morphology/presentation/morphology_shell.dart';
import '../features/morphology/presentation/pos/pos_page.dart';
import '../features/morphology/presentation/rules/rules_page.dart';
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
///  - Outer: AppShell — top-level tab bar (Phonology, Lexicon, Grammar, Culture)
///  - Inner: PhonologyShell — sidebar (Inventory, Sound Rules)
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/phonology/inventory',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Phonology (active in Phase 1)
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

          // Branch 1: Morphology (Phase 2)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/morphology',
                redirect: (_, _) => '/morphology/pos',
              ),
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) =>
                    MorphologyShell(navigationShell: navigationShell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/morphology/pos',
                        builder: (_, _) => const PosPage(),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/morphology/rules',
                        builder: (_, _) => const RulesPage(),
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
                ],
              ),
            ],
          ),

          // Branch 3: Grammar (Phase 4 placeholder)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/grammar',
                builder: (_, _) => const _ComingSoonPage(section: 'Grammar'),
              ),
            ],
          ),

          // Branch 4: Culture (Phase 5 placeholder)
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
