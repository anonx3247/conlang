import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../db/app_database.dart';
import '../../../../features/project/data/project_providers.dart';
import '../../data/ipa_data.dart';
import '../../data/phoneme_providers.dart';
import '../../data/romanization_providers.dart';
import '../shared/vowel_trapezoid_painter.dart';
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
  if (m.containsKey(p)) return m[p]!;
  // Guard against empty or single-character strings from malformed DB rows:
  // p.substring(0, 2) would throw RangeError if p.length < 2.
  if (p.length < 2) return p;
  return p.substring(0, 2);
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
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  bool _isAltHeld = false;

  bool _handleKeyEvent(KeyEvent event) {
    final altPressed = HardwareKeyboard.instance.isAltPressed;
    if (altPressed != _isAltHeld) {
      setState(() => _isAltHeld = altPressed);
    }
    return false; // Don't consume the event
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Romanization mapping editor (IPA -> Latin).
          const RomanizationSection(),
          const SizedBox(height: 32),

          // Unified Add Phoneme button + section title.
          Row(
            children: [
              Text(
                'Phoneme Inventory',
                style: theme.textTheme.headlineSmall,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const PhonemeEditDialog(),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Phoneme'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // All phonemes as chips (nothing can hide)
          _AllPhonemesRow(isAltHeld: _isAltHeld),
          const SizedBox(height: 24),

          // Phoneme inventory sections.
          _ConsonantSection(isAltHeld: _isAltHeld),
          const SizedBox(height: 32),
          _VowelSection(isAltHeld: _isAltHeld),
          const SizedBox(height: 32),
          const _NaturalClassesSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All phonemes row (flat chip list — ensures nothing is hidden)
// ---------------------------------------------------------------------------

class _AllPhonemesRow extends ConsumerWidget {
  const _AllPhonemesRow({required this.isAltHeld});

  final bool isAltHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAll = ref.watch(allPhonemesProvider);

    return asyncAll.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (phonemes) {
        if (phonemes.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: phonemes
              .map((p) => _PhonemeChip(
                    phoneme: p,
                    isAltHeld: isAltHeld,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => PhonemeEditDialog(phoneme: p),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Consonant grid (manner x place)
// ---------------------------------------------------------------------------

class _ConsonantSection extends ConsumerWidget {
  const _ConsonantSection({required this.isAltHeld});

  final bool isAltHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncConsonants = ref.watch(consonantListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Consonants', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        asyncConsonants.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (consonants) {
            if (consonants.isEmpty) {
              return const _EmptyHint(
                'No consonants yet. Tap "Add Phoneme" to define your first consonant.',
              );
            }
            return _ConsonantGrid(consonants: consonants, isAltHeld: isAltHeld);
          },
        ),
      ],
    );
  }
}

class _ConsonantGrid extends ConsumerWidget {
  const _ConsonantGrid({required this.consonants, required this.isAltHeld});

  final List<Phoneme> consonants;
  final bool isAltHeld;

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
                      isAltHeld: isAltHeld,
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
  const _VowelSection({required this.isAltHeld});

  final bool isAltHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncVowels = ref.watch(vowelListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vowels', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        asyncVowels.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (vowels) {
            if (vowels.isEmpty) {
              return const _EmptyHint(
                'No vowels yet. Tap "Add Phoneme" to define your first vowel.',
              );
            }
            return _VowelChart(vowels: vowels, isAltHeld: isAltHeld);
          },
        ),
      ],
    );
  }
}

/// Maps a height string (from DB) to [VowelHeight] enum.
VowelHeight? _heightFromString(String? h) {
  switch (h) {
    case 'close':
      return VowelHeight.close;
    case 'near-close':
      return VowelHeight.nearClose;
    case 'close-mid':
      return VowelHeight.closeMid;
    case 'mid':
      return VowelHeight.mid;
    case 'open-mid':
      return VowelHeight.openMid;
    case 'near-open':
      return VowelHeight.nearOpen;
    case 'open':
      return VowelHeight.open;
    default:
      return null;
  }
}

/// Maps a backness string (from DB) to [VowelBackness] enum.
VowelBackness? _backnessFromString(String? b) {
  switch (b) {
    case 'front':
      return VowelBackness.front;
    case 'near-front':
      return VowelBackness.nearFront;
    case 'central':
      return VowelBackness.central;
    case 'near-back':
      return VowelBackness.nearBack;
    case 'back':
      return VowelBackness.back;
    default:
      return null;
  }
}

class _VowelChart extends StatelessWidget {
  const _VowelChart({required this.vowels, required this.isAltHeld});

  final List<Phoneme> vowels;
  final bool isAltHeld;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group vowels by (height, backness)
    final Map<VowelHeight, Map<VowelBackness, List<Phoneme>>> grid = {};
    for (final v in vowels) {
      final height = _heightFromString(v.height);
      final backness = _backnessFromString(v.backness);
      if (height == null || backness == null) {
        debugPrint(
          '_VowelChart: skipping vowel "${v.symbol}" — '
          'unknown height="${v.height}" backness="${v.backness}"',
        );
        continue;
      }
      ((grid[height] ??= {})[backness] ??= []).add(v);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale trapezoid to available width; maintain ~2.2:1 aspect ratio
        final width = constraints.maxWidth.clamp(200.0, double.infinity);
        final height = (width / 2.2).clamp(0.0, 200.0);
        final size = Size(width, height);

        // Build positioned phoneme chip widgets
        final positionedChips = <Widget>[];

        for (final heightEntry in grid.entries) {
          for (final backnessEntry in heightEntry.value.entries) {
            final phonemesHere = backnessEntry.value;
            if (phonemesHere.isEmpty) continue;

            // Sort: unrounded first, then rounded (IPA convention)
            final sorted = List<Phoneme>.from(phonemesHere)
              ..sort((a, b) =>
                  ((a.rounded ?? false) ? 1 : 0)
                      .compareTo((b.rounded ?? false) ? 1 : 0));

            final anchor = vowelPosition(
              heightEntry.key,
              backnessEntry.key,
              size,
            );

            // Estimate total width: each chip ~34px (6px h-pad * 2 + symbol + margin)
            const chipW = 34.0;
            const chipH = 28.0;
            final totalW = sorted.length * chipW;

            final left = (anchor.dx - totalW / 2).clamp(0.0, width - totalW);
            final top = (anchor.dy - chipH / 2).clamp(0.0, height - chipH);

            positionedChips.add(
              Positioned(
                left: left,
                top: top,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: sorted
                      .map((p) => _PhonemeChip(
                            phoneme: p,
                            isAltHeld: isAltHeld,
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => PhonemeEditDialog(phoneme: p),
                            ),
                          ))
                      .toList(),
                ),
              ),
            );
          }
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: size,
                painter: VowelTrapezoidPainter(
                  outlineColor: colorScheme.outline.withValues(alpha: 0.5),
                  guideColor: colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              ...positionedChips,
            ],
          ),
        );
      },
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
    required this.isAltHeld,
  });

  final List<Phoneme> phonemes;
  final double width;
  final double height;
  final bool isAltHeld;

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

    final sorted = List<Phoneme>.from(phonemes)
      ..sort(
        (a, b) => (a.voicing == 'voiceless' ? 0 : 1).compareTo(
          b.voicing == 'voiceless' ? 0 : 1,
        ),
      );

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
                isAltHeld: isAltHeld,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => PhonemeEditDialog(phoneme: p),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PhonemeChip extends ConsumerWidget {
  const _PhonemeChip({
    required this.phoneme,
    required this.onTap,
    required this.isAltHeld,
  });

  final Phoneme phoneme;
  final VoidCallback onTap;
  final bool isAltHeld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final romanize = ref.watch(romanizeProvider);
    final romanized = romanize(phoneme.symbol);

    final String displayText;
    if (isAltHeld) {
      // Alt held: show /IPA/ in slashes (phonemic notation)
      displayText = '/${phoneme.symbol}/';
    } else {
      // Default: show romanization (plain text)
      // If romanization equals IPA (no mapping), show IPA without slashes as fallback
      displayText = romanized;
    }

    return GestureDetector(
      onTap: onTap,
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
            displayText,
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
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
