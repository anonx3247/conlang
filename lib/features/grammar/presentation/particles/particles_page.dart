import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../lexicon/data/lexeme_providers.dart';
import '../../../morphology/data/morphology_providers.dart';
import '../../data/particle_providers.dart';
import 'particle_dialog.dart';

/// Particles sub-tab — Phase 10 Plan 02 (AGRAM-01).
///
/// Displays closed-class words (particles, auxiliaries, determiners,
/// conjunctions, etc.) grouped by POS with collapsible sections. Users
/// can add, edit, and delete particles. Each particle is stored in the
/// shared Lexemes table with [Lexemes.isClosedClass] = true, so it
/// automatically appears in unified lexicon search and Anki export.
class ParticlesPage extends ConsumerWidget {
  const ParticlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final particlesAsync = ref.watch(closedClassLexemeListProvider);
    final posListAsync = ref.watch(posListProvider);

    final particles = particlesAsync.asData?.value ?? const <Lexeme>[];
    final posList =
        posListAsync.asData?.value ?? const <PartsOfSpeechData>[];

    // Group particles by POS name. Only POS groups with at least one
    // particle are shown (empty POS sections are hidden per UI-SPEC).
    final Map<String, List<Lexeme>> byPos = {};
    for (final lexeme in particles) {
      final pos = lexeme.partOfSpeech ?? '';
      byPos.putIfAbsent(pos, () => []).add(lexeme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Particles', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Add Particle button — always visible at top.
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Particle'),
            onPressed: () => _openDialog(context, null),
          ),
          const SizedBox(height: 24),

          // Empty state — shown when no particles exist at all.
          if (particles.isEmpty)
            _EmptyState(theme: theme)
          else ...[
            // POS-grouped sections. Render in POS list order when possible,
            // then fall back to alphabetical for orphan groups.
            for (final posEntry in _orderedEntries(byPos, posList))
              _PosSection(
                posName: posEntry.key,
                lexemes: posEntry.value,
                theme: theme,
                cs: cs,
                onAdd: () => _openDialog(context, null),
                onEdit: (lexeme) => _openDialog(context, lexeme),
                onDelete: (lexeme) => _confirmDelete(context, ref, lexeme),
              ),
          ],
        ],
      ),
    );
  }

  /// Orders the `byPos` entries by the position of each POS in [posList],
  /// putting groups whose POS isn't in the list at the end (alphabetically).
  List<MapEntry<String, List<Lexeme>>> _orderedEntries(
    Map<String, List<Lexeme>> byPos,
    List<PartsOfSpeechData> posList,
  ) {
    final posOrder = {
      for (var i = 0; i < posList.length; i++) posList[i].name: i,
    };

    final entries = byPos.entries.toList();
    entries.sort((a, b) {
      final ai = posOrder[a.key] ?? 999;
      final bi = posOrder[b.key] ?? 999;
      if (ai != bi) return ai.compareTo(bi);
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  void _openDialog(BuildContext context, Lexeme? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => ParticleDialog(existingParticle: existing),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Lexeme lexeme,
  ) async {
    final glossTag = lexeme.glossTag;
    final label =
        glossTag != null && glossTag.isNotEmpty ? glossTag : 'particle';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete particle?'),
        content: Text(
          "'${lexeme.ipa}' ($label) will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final dao = ref.read(lexemeDaoProvider);
    if (dao == null) return;
    await dao.deleteLexeme(lexeme.id);
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No particles yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add closed-class words -- particles, auxiliaries, determiners, '
          'and conjunctions -- using the button above.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// A collapsible section header + list for one POS group.
class _PosSection extends StatefulWidget {
  const _PosSection({
    required this.posName,
    required this.lexemes,
    required this.theme,
    required this.cs,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String posName;
  final List<Lexeme> lexemes;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onAdd;
  final ValueChanged<Lexeme> onEdit;
  final ValueChanged<Lexeme> onDelete;

  @override
  State<_PosSection> createState() => _PosSectionState();
}

class _PosSectionState extends State<_PosSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final cs = widget.cs;
    final posLabel =
        widget.posName.isEmpty ? '(No POS)' : widget.posName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with expand toggle.
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  posLabel,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${widget.lexemes.length})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          for (final lexeme in widget.lexemes)
            _ParticleRow(
              lexeme: lexeme,
              theme: theme,
              cs: cs,
              onEdit: () => widget.onEdit(lexeme),
              onDelete: () => widget.onDelete(lexeme),
            ),
          const SizedBox(height: 8),
        ],

        const Divider(height: 16),
      ],
    );
  }
}

/// A single particle row rendered as a [ListTile].
class _ParticleRow extends StatelessWidget {
  const _ParticleRow({
    required this.lexeme,
    required this.theme,
    required this.cs,
    required this.onEdit,
    required this.onDelete,
  });

  final Lexeme lexeme;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final glossTag = lexeme.glossTag;
    final hasTag = glossTag != null && glossTag.isNotEmpty;

    return ListTile(
      dense: true,
      leading: hasTag
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 60),
              child: Chip(
                label: Text(
                  glossTag,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 12),
                ),
                backgroundColor: cs.secondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : const SizedBox(width: 60),
      title: Text(lexeme.ipa),
      subtitle: lexeme.meaning != null && lexeme.meaning!.isNotEmpty
          ? Text(
              lexeme.meaning!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        color: cs.error,
        tooltip: 'Delete particle',
        onPressed: onDelete,
      ),
      onTap: onEdit,
    );
  }
}
