import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../data/phoneme_providers.dart';
import '../../domain/default_natural_classes.dart';
import 'natural_class_editor.dart';

/// Dedicated page for natural phonological classes.
///
/// Displays system classes (C, V), predefined natural classes (stop, nasal, …),
/// and user-defined classes with CRUD controls.
class NaturalClassesPage extends ConsumerWidget {
  const NaturalClassesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncClasses = ref.watch(naturalClassListProvider);
    final asyncAll = ref.watch(allPhonemesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Natural Classes', style: theme.textTheme.headlineSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const NaturalClassEditor(),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Class'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'C, V, and the predefined phonological classes below are built-in. '
            'Single-letter aliases (S, N, F, L, R) resolve to Stop/Nasal/Fricative/Liquid/Rhotic. '
            'Custom classes are referenced in phonotactic patterns as [name].',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),

          // Built-in system classes (always shown, read-only).
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _SystemClassChip(label: 'C', description: 'all consonants'),
              const _SystemClassChip(label: 'V', description: 'all vowels'),
              for (final entry in defaultNaturalClasses.entries)
                _DefaultClassChip(
                  name: entry.key,
                  members: entry.value,
                  alias: _aliasFor(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // User-defined classes
          asyncClasses.when(
            loading: () => const SizedBox(
              height: 32,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (classes) {
              if (classes.isEmpty) {
                return Text(
                  'No custom natural classes yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                );
              }
              return asyncAll.when(
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
                data: (allPhonemes) {
                  final phonemeMap = {for (final p in allPhonemes) p.id: p};
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: classes
                        .map(
                          (nc) => _UserClassChip(
                            nc: nc,
                            phonemeMap: phonemeMap,
                            onEdit: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  NaturalClassEditor(naturalClass: nc),
                            ),
                            onDelete: () =>
                                confirmDeleteNaturalClass(context, ref, nc),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alias lookup
// ---------------------------------------------------------------------------

/// Reverse lookup from default class name to single-letter alias, if any.
String? _aliasFor(String className) {
  final members = defaultNaturalClasses[className];
  if (members == null) return null;
  for (final entry in defaultNaturalClassAliases.entries) {
    if (identical(entry.value, members)) return entry.key;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Chip widgets
// ---------------------------------------------------------------------------

class _SystemClassChip extends StatelessWidget {
  const _SystemClassChip({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '[$label]',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            TextSpan(
              text: ' = $description',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.4,
      ),
    );
  }
}

class _DefaultClassChip extends StatelessWidget {
  const _DefaultClassChip({
    required this.name,
    required this.members,
    this.alias,
  });

  final String name;
  final List<String> members;
  final String? alias;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbols = members.join(' ');
    final labelText = alias != null ? '[$name] / $alias' : '[$name]';

    return Chip(
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: labelText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            TextSpan(
              text: ' = $symbols',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.4,
      ),
    );
  }
}

class _UserClassChip extends ConsumerWidget {
  const _UserClassChip({
    required this.nc,
    required this.phonemeMap,
    required this.onEdit,
    required this.onDelete,
  });

  final NaturalClassesData nc;
  final Map<int, Phoneme> phonemeMap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    List<int> ids = [];
    try {
      final decoded = jsonDecode(nc.phonemeIds);
      if (decoded is List) {
        ids = decoded.whereType<int>().toList();
      }
    } catch (_) {}

    final symbols =
        ids.map((id) => phonemeMap[id]?.symbol).whereType<String>().join(' ');

    return InputChip(
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '[${nc.name}]',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (symbols.isNotEmpty)
              TextSpan(
                text: ' = $symbols',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      onPressed: onEdit,
      onDeleted: onDelete,
      deleteIcon: const Icon(Icons.close, size: 14),
    );
  }
}
