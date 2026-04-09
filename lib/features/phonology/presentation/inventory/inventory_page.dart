import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../features/project/data/project_providers.dart';
import '../../data/phoneme_providers.dart';
import 'natural_class_editor.dart';
import 'phoneme_edit_dialog.dart';
import 'romanization_section.dart';

// ---------------------------------------------------------------------------
// IPA grid ordering constants
// ---------------------------------------------------------------------------

const _mannerOrder = [
  'plosive',
  'nasal',
  'trill',
  'tap/flap',
  'fricative',
  'lateral fricative',
  'approximant',
  'lateral approximant',
];

const _placeOrder = [
  'bilabial',
  'labiodental',
  'dental',
  'alveolar',
  'postalveolar',
  'retroflex',
  'palatal',
  'velar',
  'uvular',
  'pharyngeal',
  'glottal',
];

const _heightOrder = [
  'close',
  'near-close',
  'close-mid',
  'mid',
  'open-mid',
  'near-open',
  'open',
];

const _backnessOrder = ['front', 'near-front', 'central', 'near-back', 'back'];

String _shortPlace(String p) {
  const m = {
    'bilabial': 'Bi',
    'labiodental': 'Ld',
    'dental': 'De',
    'alveolar': 'Al',
    'postalveolar': 'Pa',
    'retroflex': 'Rf',
    'palatal': 'Pl',
    'velar': 'Ve',
    'uvular': 'Uv',
    'pharyngeal': 'Ph',
    'glottal': 'Gl',
  };
  return m[p] ?? p.substring(0, 2);
}

String _shortManner(String manner) {
  const m = {
    'plosive': 'Plosive',
    'nasal': 'Nasal',
    'trill': 'Trill',
    'tap/flap': 'Tap/Flap',
    'fricative': 'Fricative',
    'lateral fricative': 'Lat. Fric.',
    'approximant': 'Approx.',
    'lateral approximant': 'Lat. Approx.',
  };
  return m[manner] ?? manner;
}

// ---------------------------------------------------------------------------
// InventoryPage
// ---------------------------------------------------------------------------

/// Phoneme inventory editor page.
///
/// Shows:
/// - Romanization mapping editor
/// - Consonant grid (manner x place)
/// - Vowel chart (height x backness)
/// - Natural classes section
///
/// When no project is open, shows a placeholder message.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(currentDatabaseProvider);
    final theme = Theme.of(context);

    if (db == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No project open',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or open a project to start defining phonemes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Romanization mapping editor (IPA -> Latin).
          RomanizationSection(),
          SizedBox(height: 32),

          // Phoneme inventory.
          _ConsonantSection(),
          SizedBox(height: 32),
          _VowelSection(),
          SizedBox(height: 32),
          _NaturalClassesSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consonant grid (manner x place)
// ---------------------------------------------------------------------------

class _ConsonantSection extends ConsumerWidget {
  const _ConsonantSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncConsonants = ref.watch(consonantListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Consonants', style: theme.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PhonemeEditDialog(),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        asyncConsonants.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (consonants) {
            if (consonants.isEmpty) {
              return _EmptyHint(
                'No consonants yet. Tap "Add" to define your first consonant.',
              );
            }
            return _ConsonantGrid(consonants: consonants);
          },
        ),
      ],
    );
  }
}

class _ConsonantGrid extends ConsumerWidget {
  const _ConsonantGrid({required this.consonants});

  final List<Phoneme> consonants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const cellW = 56.0;
    const cellH = 40.0;
    const labelW = 110.0;
    const headerH = 28.0;

    // Build (manner, place) -> [phonemes] lookup
    final Map<String, Map<String, List<Phoneme>>> grid = {};
    for (final c in consonants) {
      final m = c.manner ?? '';
      final p = c.place ?? '';
      (grid[m] ??= {})[p] = [...((grid[m] ?? {})[p] ?? []), c];
    }

    final usedManners = _mannerOrder.where(grid.containsKey).toList();
    final usedPlaces = {
      for (final r in grid.values) ...r.keys,
    };
    final cols = _placeOrder.where(usedPlaces.contains).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: place abbreviations
          Row(
            children: [
              const SizedBox(width: labelW),
              ...cols.map(
                (p) => SizedBox(
                  width: cellW,
                  height: headerH,
                  child: Center(
                    child: Text(
                      _shortPlace(p),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Rows: one per manner
          ...usedManners.map((manner) => Row(
                children: [
                  SizedBox(
                    width: labelW,
                    height: cellH,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _shortManner(manner),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  ...cols.map((place) {
                    final phonemesHere = (grid[manner] ?? {})[place] ?? [];
                    return _PhonemeCell(
                      phonemes: phonemesHere,
                      width: cellW,
                      height: cellH,
                    );
                  }),
                ],
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vowel chart (height x backness)
// ---------------------------------------------------------------------------

class _VowelSection extends ConsumerWidget {
  const _VowelSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncVowels = ref.watch(vowelListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Vowels', style: theme.textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PhonemeEditDialog(),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        asyncVowels.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (vowels) {
            if (vowels.isEmpty) {
              return _EmptyHint(
                'No vowels yet. Tap "Add" to define your first vowel.',
              );
            }
            return _VowelChart(vowels: vowels);
          },
        ),
      ],
    );
  }
}

class _VowelChart extends ConsumerWidget {
  const _VowelChart({required this.vowels});

  final List<Phoneme> vowels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const cellW = 88.0;
    const cellH = 40.0;
    const labelW = 90.0;
    const headerH = 28.0;

    final Map<String, Map<String, List<Phoneme>>> grid = {};
    for (final v in vowels) {
      final h = v.height ?? '';
      final b = v.backness ?? '';
      (grid[h] ??= {})[b] = [...((grid[h] ?? {})[b] ?? []), v];
    }

    final usedHeights = _heightOrder.where(grid.containsKey).toList();
    final usedBackness = {for (final r in grid.values) ...r.keys};
    final cols = _backnessOrder.where(usedBackness.contains).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: labelW),
              ...cols.map(
                (b) => SizedBox(
                  width: cellW,
                  height: headerH,
                  child: Center(
                    child: Text(
                      b[0].toUpperCase() + b.substring(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...usedHeights.map((height) => Row(
                children: [
                  SizedBox(
                    width: labelW,
                    height: cellH,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        height[0].toUpperCase() + height.substring(1),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  ...cols.map((backness) {
                    final phonemesHere = (grid[height] ?? {})[backness] ?? [];
                    return _PhonemeCell(
                      phonemes: phonemesHere,
                      width: cellW,
                      height: cellH,
                      sortByRoundedness: true,
                    );
                  }),
                ],
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared cell widget
// ---------------------------------------------------------------------------

class _PhonemeCell extends ConsumerWidget {
  const _PhonemeCell({
    required this.phonemes,
    required this.width,
    required this.height,
    this.sortByRoundedness = false,
  });

  final List<Phoneme> phonemes;
  final double width;
  final double height;
  final bool sortByRoundedness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (phonemes.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    final sorted = List<Phoneme>.from(phonemes);
    if (sortByRoundedness) {
      sorted.sort(
        (a, b) => ((a.rounded ?? false) ? 1 : 0).compareTo(
          (b.rounded ?? false) ? 1 : 0,
        ),
      );
    } else {
      sorted.sort(
        (a, b) => (a.voicing == 'voiceless' ? 0 : 1).compareTo(
          b.voicing == 'voiceless' ? 0 : 1,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: sorted
            .map(
              (p) => _PhonemeChip(
                phoneme: p,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => PhonemeEditDialog(phoneme: p),
                ),
                onLongPress: () => confirmDeletePhoneme(context, ref, p),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PhonemeChip extends StatelessWidget {
  const _PhonemeChip({
    required this.phoneme,
    required this.onTap,
    required this.onLongPress,
  });

  final Phoneme phoneme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Tooltip(
        message: _tooltip(),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            phoneme.symbol,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _tooltip() {
    if (phoneme.type == 'consonant') {
      return [
        if (phoneme.voicing != null) phoneme.voicing!,
        if (phoneme.place != null) phoneme.place!,
        if (phoneme.manner != null) phoneme.manner!,
      ].join(' ');
    } else {
      return [
        if (phoneme.rounded == true) 'rounded',
        if (phoneme.height != null) phoneme.height!,
        if (phoneme.backness != null) phoneme.backness!,
        'vowel',
      ].join(' ');
    }
  }
}

// ---------------------------------------------------------------------------
// Natural classes section
// ---------------------------------------------------------------------------

class _NaturalClassesSection extends ConsumerWidget {
  const _NaturalClassesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncClasses = ref.watch(naturalClassListProvider);
    final asyncAll = ref.watch(allPhonemesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Natural Classes', style: theme.textTheme.titleLarge),
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
          'C and V are built-in system classes. '
          'Custom classes are referenced in phonotactic patterns as [name].',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),

        // System classes (always shown, read-only)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _SystemClassChip(label: 'C', description: 'all consonants'),
            _SystemClassChip(label: 'V', description: 'all vowels'),
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
              error: (_, __) => const SizedBox.shrink(),
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
    );
  }
}

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

    // Decode phoneme IDs from JSON and resolve to symbols
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

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
