import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/phonotactic_providers.dart';
import 'constraint_editor.dart';
import 'rewrite_rule_editor.dart';
import 'template_editor.dart';
import 'word_generator_panel.dart';

/// Sound rules page with an integrated template editor, constraint editor,
/// and live word generation preview.
///
/// Layout:
///   Left column  — TemplateEditor + ConstraintEditor (scrollable)
///   Right column — WordGeneratorPanel (live preview)
///
/// When no project is open: shows empty state.
/// When a project is open but no templates exist: shows guidance text inside
/// the word generator panel.
class SoundRulesPage extends ConsumerWidget {
  const SoundRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine whether a project is open by checking the DAO.
    final dao = ref.watch(phonotacticDaoProvider);
    final hasProject = dao != null;

    if (!hasProject) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule_outlined,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or open a project to start defining sound rules.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Left: editors -------------------------------------------------
        SizedBox(
          width: 400,
          child: Material(
            color: cs.surface,
            child: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TemplateEditor(),
                  SizedBox(height: 8),
                  Divider(height: 1),
                  SizedBox(height: 8),
                  ConstraintEditor(),
                  SizedBox(height: 8),
                  Divider(height: 1),
                  SizedBox(height: 8),
                  RewriteRuleEditor(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // ---- Vertical divider ----------------------------------------------
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: cs.outlineVariant,
        ),

        // ---- Right: word generator panel -----------------------------------
        const Expanded(
          child: WordGeneratorPanel(),
        ),
      ],
    );
  }
}
