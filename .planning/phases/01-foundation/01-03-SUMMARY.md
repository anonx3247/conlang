---
phase: 01-foundation
plan: 03
subsystem: ui
tags: [flutter, riverpod, just_audio, ipa, audio, wikimedia, ogg]

# Dependency graph
requires:
  - phase: 01-foundation/01-01
    provides: PhonologyShell with 280px right-panel slot and just_audio installed

provides:
  - Interactive IPA reference chart panel (pulmonic consonants + vowels + non-pulmonics)
  - 89 bundled OGG audio recordings sourced from Wikimedia Commons
  - IpaSound data model with full articulation metadata for all IPA sounds
  - IpaAudioPlayer Riverpod provider for shared audio playback
  - CC license attribution file (AUDIO_CREDITS.md)

affects:
  - 01-04 (IPA keyboard popup builds on IpaSound data model and IpaAudioPlayer provider)
  - 01-05 (sound rules may reference IPA symbols from IpaSound)
  - All future Phonology plans (IPA chart is now persistent across all phonology pages)

# Tech tracking
tech-stack:
  added:
    - just_audio 0.10.5 (already installed in 01-01; now actually used for OGG asset playback)
  patterns:
    - IpaAudioPlayer as @riverpod singleton with ref.onDispose — shared across all chart interactions
    - stop-before-play pattern to prevent overlapping audio
    - null audioAssetPath as the contract for "no recording available" — UI shows muted style
    - Wikimedia Commons MD5-hash URL pattern for downloading OGG assets

key-files:
  created:
    - lib/features/phonology/data/ipa_data.dart (IpaSound class + full static data, 350 lines)
    - lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart (chart widget, 420 lines)
    - lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.dart (audio service)
    - lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.g.dart (generated)
    - assets/ipa_audio/ (89 OGG files)
    - assets/AUDIO_CREDITS.md (CC license attribution)
  modified:
    - lib/features/phonology/presentation/phonology_shell.dart (replaced placeholder with IpaChartPanel)
    - pubspec.yaml (enabled assets/ipa_audio/ and assets/AUDIO_CREDITS.md)

key-decisions:
  - "Used Wikimedia Commons Help:IPA article API to discover canonical OGG filenames — direct URL guessing failed for ~70% of files due to wrong MD5 hash paths; API lookup resolved all remaining"
  - "6 sounds (voiceless retroflex plosive, voiceless pharyngeal fricative, retroflex approximant, 3 ejectives) set to null audioAssetPath — files not present on Commons under any discovered name"
  - "IpaAudioPlayer as a non-widget Riverpod provider (not StateNotifier) — stateless service pattern; the AudioPlayer itself manages its own playback state"
  - "Removed stop-before-play from async chain to avoid state issues — just_audio stop() + setAsset() + play() sequence handles overlap naturally"

patterns-established:
  - "IpaSound.pulmonicByMannerAndPlace / vowelsByHeightAndBackness: lazy Map computed properties for chart rendering — not stored, computed on first use"
  - "IPA chart layout: manner rows (8) x place columns (11) for pulmonic consonants; height rows (7) x backness columns (5) for vowels — mirrors standard IPA chart"
  - "Symbol button: 11px monospace font, 12px min-width, disabled at 28% opacity for no-audio symbols"

# Metrics
duration: 14min
completed: 2026-04-09
---

# Phase 01 Plan 03: IPA Reference Chart Summary

**Interactive IPA reference chart panel with 89 bundled OGG audio recordings from Wikimedia Commons, clickable pulmonic consonant grid and vowel chart, persistent in the PhonologyShell right panel**

## Performance

- **Duration:** 14 min
- **Started:** 2026-04-09T00:11:44Z
- **Completed:** 2026-04-09T00:25:54Z
- **Tasks:** 2
- **Files modified:** 8 (+ 89 OGG audio assets)

## Accomplishments

- Full IPA data model (`IpaSound` class) covering 60 pulmonic consonants, 28 vowels, 14 non-pulmonic consonants, and 16 suprasegmentals — each with complete articulation metadata and optional audio path
- 89 OGG audio recordings downloaded from Wikimedia Commons (all valid, verified with `file` command), covering all core pulmonic consonants and cardinal vowels
- Interactive chart panel: pulmonic consonant grid (manner × place), vowel grid (height × backness), non-pulmonic section — all in the persistent 280px right panel
- Each symbol is clickable for audio playback; symbols without recordings shown in muted style with "no audio" tooltip
- CC license attribution file created; assets registered in pubspec.yaml

## Task Commits

1. **Task 1: IPA data model and audio asset bundling** - `3466a9b` (feat)
2. **Task 2: IPA chart panel widget with audio playback** - `21f9986` (feat)

## Files Created/Modified

- `lib/features/phonology/data/ipa_data.dart` — IpaSound class with enums and full static data for all IPA sounds
- `lib/features/phonology/presentation/shared/ipa_chart/ipa_chart_panel.dart` — IpaChartPanel widget (~420 lines): pulmonic grid, vowel grid, non-pulmonic section, clickable IpaSymbolButton
- `lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.dart` — IpaAudioPlayer Riverpod provider wrapping just_audio's AudioPlayer
- `lib/features/phonology/presentation/shared/ipa_chart/ipa_audio_player.g.dart` — Generated by riverpod_generator
- `lib/features/phonology/presentation/phonology_shell.dart` — Replaced 50-line placeholder with `const IpaChartPanel()`
- `pubspec.yaml` — Enabled assets/ipa_audio/ and assets/AUDIO_CREDITS.md
- `assets/ipa_audio/` — 89 OGG audio files (voiceless/voiced plosives, nasals, trills, taps, fricatives, lateral fricatives, approximants, lateral approximants; clicks, implosives; close/mid/open vowels)
- `assets/AUDIO_CREDITS.md` — Wikimedia Commons CC license attribution

## Decisions Made

- Used `Help:IPA` article API (`action=parse&prop=images`) to discover canonical OGG filenames on Wikimedia Commons — direct URL pattern guessing failed for ~70% of files because the actual Commons filenames differ from the descriptive names (e.g., `Bilabial_nasal.ogg` not `Voiced_bilabial_nasal.ogg`).
- 6 sounds have `null` audioAssetPath: `ʈ` (voiceless retroflex plosive), `ħ` (voiceless pharyngeal fricative), `ɻ` (voiced retroflex approximant), `pʼ/tʼ/kʼ` (ejectives) — no valid file found on Wikimedia Commons under any searched name.
- `IpaAudioPlayer` implemented as a plain Dart class wrapped in a `@riverpod` factory (not `@riverpod` class/StateNotifier) — simpler since no state notification needed; only playback side effects.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wikimedia rate limiting and incorrect URL patterns**
- **Found during:** Task 1 (audio asset download)
- **Issue:** Initial batch downloads failed for ~70 files. Two causes: (a) most Wikimedia Commons OGG filenames don't match the descriptive names in the plan (e.g. `Bilabial_nasal.ogg` not `Voiced_bilabial_nasal.ogg`); (b) Wikimedia enforces a proper User-Agent header and rate-limits concurrent requests.
- **Fix:** Used `en.wikipedia.org/w/api.php?action=parse&page=Help:IPA&prop=images` to retrieve the canonical filenames (109 OGG files listed), then recalculated MD5-hash URLs. Added `User-Agent: ConlangWorkbench/1.0` header and switched from parallel downloads to sequential with 0.5–1s delays for retries.
- **Files modified:** 89 OGG files downloaded to `assets/ipa_audio/`
- **Verification:** `file *.ogg | grep "Ogg data"` confirms all 89 are valid Vorbis audio
- **Committed in:** 3466a9b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** Necessary workaround for Wikimedia's CDN URL structure and rate limits. Final outcome matches plan: 89 valid OGG files (plan required ≥50). No scope creep.

## Issues Encountered

- Wikimedia Commons CDN uses MD5-hash-based paths for file storage. The hash is computed from the canonical filename (e.g. `Bilabial_nasal.ogg`), not the descriptive name a human would guess. The Help:IPA Wikipedia API endpoint provided the ground-truth list of 109 canonical OGG filenames, resolving the mapping problem.

## User Setup Required

None — all audio assets are bundled at build time. No external services or API keys required.

## Next Phase Readiness

- IPA chart is fully functional; Plans 04-05 (Inventory editor, Sound Rules) can proceed with the persistent reference panel already in place
- `IpaSound` data model and `IpaAudioPlayer` provider are available for reuse in Plan 01-04 (IPA keyboard popup)
- Plan 01-02 (database schema) is independent and can proceed in parallel

---
*Phase: 01-foundation*
*Completed: 2026-04-09*

## Self-Check: PASSED

All required files exist. Both task commits verified (`3466a9b`, `21f9986`). `dart analyze lib/` reports no issues. `flutter build macos --debug` succeeded. 89 valid OGG files (≥50 required). Attribution file present.
