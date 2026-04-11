import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ipa_audio_player.g.dart';

/// Riverpod provider for the shared IPA audio player.
///
/// Wraps a single [AudioPlayer] instance that is reused for all IPA sounds.
/// Previous playback is stopped before each new sound is played.
@riverpod
IpaAudioPlayer ipaAudioPlayer(Ref ref) {
  final player = IpaAudioPlayer();
  ref.onDispose(player.dispose);
  return player;
}

/// Service that manages playback of IPA sound OGG recordings.
class IpaAudioPlayer {
  IpaAudioPlayer();

  /// Lazily instantiated so that widget tests which mount an IpaTextField
  /// (or any other consumer) do not construct a real just_audio AudioPlayer
  /// they can never tear down cleanly. Real users still pay the one-time
  /// construction cost on their first playSound() call.
  AudioPlayer? _player;

  /// Plays the audio recording at [assetPath].
  ///
  /// If [assetPath] is null, this is a no-op (the symbol has no recording).
  /// Any currently-playing sound is stopped before the new one starts.
  Future<void> playSound(String? assetPath) async {
    if (assetPath == null) return;
    final player = _player ??= AudioPlayer();
    try {
      await player.stop();
      await player.setAsset(assetPath);
      await player.play();
    } catch (e) {
      // Audio asset may be missing or corrupt — fail silently so the UI is not broken.
    }
  }

  /// Releases the underlying [AudioPlayer], if one was created.
  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
