import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../project/data/project_providers.dart';
import '../../data/typology_providers.dart';

/// Typology form — Phase 4 plan 04-04 Task 3 (D-35).
///
/// Three labeled sections (Alignment, Basic Word Order, Modality Strategy),
/// each with an info tooltip and a `DropdownButtonFormField`. Selection
/// auto-saves via `writeTypologyKey` — no explicit save button.
class TypologyPage extends ConsumerWidget {
  const TypologyPage({super.key});

  // Enum-constrained option lists (stored key, display label).
  static const _alignmentOptions = <(String, String)>[
    ('nom_acc', 'Nominative-Accusative'),
    ('erg_abs', 'Ergative-Absolutive'),
    ('split', 'Split'),
  ];
  static const _wordOrderOptions = <(String, String)>[
    ('SVO', 'SVO'),
    ('SOV', 'SOV'),
    ('VSO', 'VSO'),
    ('VOS', 'VOS'),
    ('OVS', 'OVS'),
    ('OSV', 'OSV'),
    ('free', 'Free / Topic-prominent'),
  ];
  static const _modalityOptions = <(String, String)>[
    ('synthetic', 'Synthetic'),
    ('analytic', 'Analytic'),
    ('mixed', 'Mixed'),
  ];

  static const _alignmentTooltip =
      'Nominative-accusative: subjects of intransitive and transitive verbs '
      'share marking. Ergative-absolutive: intransitive subjects and direct '
      'objects share marking. Split: varies by tense, aspect, or animacy.';
  static const _wordOrderTooltip =
      'The default order of Subject (S), Verb (V), and Object (O) in '
      'declarative sentences.';
  static const _modalityTooltip =
      'Synthetic: modality expressed by inflectional morphology. Analytic: '
      'modality expressed by auxiliary verbs or particles. Mixed: both.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(typologySettingsProvider);
    final settings = settingsAsync.asData?.value ?? const TypologySettings();

    // `writeTypologyKey` takes AppDatabase directly (per 04-03 API). We
    // look it up from currentDatabaseProvider on every selection.
    Future<void> write(String key, String value) async {
      final db = ref.read(currentDatabaseProvider);
      if (db == null) return;
      await writeTypologyKey(db, key, value);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Typology', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          _section(
            context,
            label: 'Alignment',
            tooltip: _alignmentTooltip,
            current: settings.alignment,
            options: _alignmentOptions,
            onChanged: (v) => write('typology.alignment', v),
          ),
          const SizedBox(height: 24),
          _section(
            context,
            label: 'Basic Word Order',
            tooltip: _wordOrderTooltip,
            current: settings.wordOrder,
            options: _wordOrderOptions,
            onChanged: (v) => write('typology.word_order', v),
          ),
          const SizedBox(height: 24),
          _section(
            context,
            label: 'Modality Strategy',
            tooltip: _modalityTooltip,
            current: settings.modality,
            options: _modalityOptions,
            onChanged: (v) => write('typology.modality', v),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String label,
    required String tooltip,
    required String? current,
    required List<(String, String)> options,
    required Future<void> Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 500),
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // Flutter 3.38 deprecated `value:` in favour of `initialValue:`
          // on DropdownButtonFormField. We rebuild on every settings stream
          // update so passing this as `initialValue` is equivalent for our
          // auto-save use case.
          initialValue: current,
          items: [
            for (final o in options)
              DropdownMenuItem<String>(value: o.$1, child: Text(o.$2)),
          ],
          onChanged: (v) async {
            if (v != null) await onChanged(v);
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
