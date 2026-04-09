import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/ipa_data.dart';
import 'ipa_audio_player.dart';

/// Persistent IPA reference chart panel (~280px wide).
///
/// Shows the standard pulmonic consonant chart, vowel chart, and
/// non-pulmonic consonants. Each symbol is clickable to play the
/// bundled OGG audio recording. Symbols without recordings are shown
/// in a muted style.
class IpaChartPanel extends ConsumerWidget {
  const IpaChartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final audioPlayer = ref.watch(ipaAudioPlayerProvider);

    return SizedBox(
      width: 280,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Text(
                'IPA REFERENCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Chart content — scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(label: 'Pulmonic Consonants'),
                    const SizedBox(height: 4),
                    _PulmonicConsonantChart(audioPlayer: audioPlayer),
                    const SizedBox(height: 12),
                    const _SectionLabel(label: 'Vowels'),
                    const SizedBox(height: 4),
                    _VowelChart(audioPlayer: audioPlayer),
                    const SizedBox(height: 12),
                    const _SectionLabel(label: 'Non-Pulmonic'),
                    const SizedBox(height: 4),
                    _NonPulmonicChart(audioPlayer: audioPlayer),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.primary.withValues(alpha: 0.8),
          fontSize: 9,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulmonic consonant chart
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the standard IPA pulmonic consonant table.
///
/// Rows = manners, columns = places.
/// Each cell holds up to two symbols (voiceless left, voiced right).
class _PulmonicConsonantChart extends StatelessWidget {
  const _PulmonicConsonantChart({required this.audioPlayer});
  final IpaAudioPlayer audioPlayer;

  static const _manners = [
    Manner.plosive,
    Manner.nasal,
    Manner.trill,
    Manner.tapOrFlap,
    Manner.fricative,
    Manner.lateralFricative,
    Manner.approximant,
    Manner.lateralApproximant,
  ];

  static const _mannerLabels = {
    Manner.plosive: 'Plosive',
    Manner.nasal: 'Nasal',
    Manner.trill: 'Trill',
    Manner.tapOrFlap: 'Tap/Flap',
    Manner.fricative: 'Fricative',
    Manner.lateralFricative: 'Lat. Fric.',
    Manner.approximant: 'Approx.',
    Manner.lateralApproximant: 'Lat. Approx.',
  };

  static const _places = [
    Place.bilabial,
    Place.labiodental,
    Place.dental,
    Place.alveolar,
    Place.postalveolar,
    Place.retroflex,
    Place.palatal,
    Place.velar,
    Place.uvular,
    Place.pharyngeal,
    Place.glottal,
  ];

  static const _placeLabels = {
    Place.bilabial: 'Bi',
    Place.labiodental: 'Ld',
    Place.dental: 'De',
    Place.alveolar: 'Al',
    Place.postalveolar: 'Pa',
    Place.retroflex: 'Rf',
    Place.palatal: 'Pl',
    Place.velar: 'Ve',
    Place.uvular: 'Uv',
    Place.pharyngeal: 'Ph',
    Place.glottal: 'Gl',
  };

  @override
  Widget build(BuildContext context) {
    final byMannerPlace = IpaSound.pulmonicByMannerAndPlace;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Place column headers
        Row(
          children: [
            const SizedBox(width: 44), // row label space
            ..._places.map((p) => Expanded(
                  child: Center(
                    child: Text(
                      _placeLabels[p] ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 7,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )),
          ],
        ),
        const SizedBox(height: 1),
        ..._manners.map((manner) {
          final placeMap = byMannerPlace[manner] ?? {};
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Manner row label
                SizedBox(
                  width: 44,
                  child: Text(
                    _mannerLabels[manner] ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 7,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Place cells
                ..._places.map((place) {
                  final sounds = placeMap[place] ?? [];
                  final voiceless = sounds.where((s) => s.voiced == false).firstOrNull;
                  final voiced = sounds.where((s) => s.voiced == true).firstOrNull;
                  return Expanded(
                    child: _ConsonantCell(
                      voiceless: voiceless,
                      voiced: voiced,
                      audioPlayer: audioPlayer,
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ConsonantCell extends StatelessWidget {
  const _ConsonantCell({
    required this.voiceless,
    required this.voiced,
    required this.audioPlayer,
  });

  final IpaSound? voiceless;
  final IpaSound? voiced;
  final IpaAudioPlayer audioPlayer;

  @override
  Widget build(BuildContext context) {
    if (voiceless == null && voiced == null) {
      // Impossible cell — grey out
      return Container(
        height: 18,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (voiceless != null)
          _IpaSymbolButton(sound: voiceless!, audioPlayer: audioPlayer)
        else
          const SizedBox(width: 9),
        if (voiced != null)
          _IpaSymbolButton(sound: voiced!, audioPlayer: audioPlayer)
        else
          const SizedBox(width: 9),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vowel chart
// ─────────────────────────────────────────────────────────────────────────────

class _VowelChart extends StatelessWidget {
  const _VowelChart({required this.audioPlayer});
  final IpaAudioPlayer audioPlayer;

  static const _heights = [
    VowelHeight.close,
    VowelHeight.nearClose,
    VowelHeight.closeMid,
    VowelHeight.mid,
    VowelHeight.openMid,
    VowelHeight.nearOpen,
    VowelHeight.open,
  ];

  static const _heightLabels = {
    VowelHeight.close: 'Close',
    VowelHeight.nearClose: 'N-Close',
    VowelHeight.closeMid: 'C-Mid',
    VowelHeight.mid: 'Mid',
    VowelHeight.openMid: 'O-Mid',
    VowelHeight.nearOpen: 'N-Open',
    VowelHeight.open: 'Open',
  };

  static const _backnesses = [
    VowelBackness.front,
    VowelBackness.nearFront,
    VowelBackness.central,
    VowelBackness.nearBack,
    VowelBackness.back,
  ];

  static const _backnessLabels = {
    VowelBackness.front: 'Fr',
    VowelBackness.nearFront: 'NF',
    VowelBackness.central: 'Ce',
    VowelBackness.nearBack: 'NB',
    VowelBackness.back: 'Ba',
  };

  @override
  Widget build(BuildContext context) {
    final byHeightBackness = IpaSound.vowelsByHeightAndBackness;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Backness column headers
        Row(
          children: [
            const SizedBox(width: 44),
            ..._backnesses.map((b) => Expanded(
                  child: Center(
                    child: Text(
                      _backnessLabels[b] ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 7,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )),
          ],
        ),
        const SizedBox(height: 1),
        ..._heights.map((height) {
          final backnessMap = byHeightBackness[height] ?? {};
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _heightLabels[height] ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 7,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._backnesses.map((backness) {
                  final sounds = backnessMap[backness] ?? [];
                  if (sounds.isEmpty) {
                    return const Expanded(child: SizedBox(height: 18));
                  }
                  // Show unrounded on left, rounded on right (IPA convention)
                  final unrounded = sounds.where((s) => s.rounded == false).firstOrNull;
                  final rounded = sounds.where((s) => s.rounded == true).firstOrNull;
                  return Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (unrounded != null)
                          _IpaSymbolButton(sound: unrounded, audioPlayer: audioPlayer)
                        else
                          const SizedBox(width: 9),
                        if (rounded != null)
                          _IpaSymbolButton(sound: rounded, audioPlayer: audioPlayer)
                        else if (unrounded != null)
                          const SizedBox(width: 9),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Non-pulmonic consonants
// ─────────────────────────────────────────────────────────────────────────────

class _NonPulmonicChart extends StatelessWidget {
  const _NonPulmonicChart({required this.audioPlayer});
  final IpaAudioPlayer audioPlayer;

  static const _mannerOrder = [Manner.click, Manner.implosive, Manner.ejective];
  static const _mannerLabels = {
    Manner.click: 'Clicks',
    Manner.implosive: 'Implosives',
    Manner.ejective: 'Ejectives',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final byManner = <Manner, List<IpaSound>>{};
    for (final sound in IpaSound.nonPulmonicConsonants) {
      (byManner[sound.manner!] ??= []).add(sound);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _mannerOrder.map((manner) {
        final sounds = byManner[manner] ?? [];
        if (sounds.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                _mannerLabels[manner] ?? '',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: sounds.map((s) => _IpaSymbolButton(sound: s, audioPlayer: audioPlayer)).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual IPA symbol button
// ─────────────────────────────────────────────────────────────────────────────

class _IpaSymbolButton extends StatelessWidget {
  const _IpaSymbolButton({
    required this.sound,
    required this.audioPlayer,
  });

  final IpaSound sound;
  final IpaAudioPlayer audioPlayer;

  bool get hasAudio => sound.audioAssetPath != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final textColor = hasAudio
        ? colorScheme.onSurface.withValues(alpha: 0.9)
        : colorScheme.onSurface.withValues(alpha: 0.28);

    final hoverColor = hasAudio
        ? colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    final tooltip = hasAudio
        ? sound.name
        : '${sound.name}\n(no audio available)';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: hasAudio
            ? () => audioPlayer.playSound(sound.audioAssetPath)
            : null,
        borderRadius: BorderRadius.circular(3),
        hoverColor: hoverColor,
        child: Container(
          constraints: const BoxConstraints(minWidth: 9, minHeight: 16),
          padding: EdgeInsets.zero,
          child: Center(
            child: Text(
              sound.symbol,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
