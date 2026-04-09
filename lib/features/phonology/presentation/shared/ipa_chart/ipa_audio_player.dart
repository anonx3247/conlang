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
  IpaAudioPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  /// Plays the audio recording at [assetPath].
  ///
  /// If [assetPath] is null, this is a no-op (the symbol has no recording).
  /// Any currently-playing sound is stopped before the new one starts.
  Future<void> playSound(String? assetPath) async {
    if (assetPath == null) return;
    try {
      await _player.stop();
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      // Audio asset may be missing or corrupt — fail silently so the UI is not broken.
    }
  }

  /// Releases the underlying [AudioPlayer].
  void dispose() {
    _player.dispose();
  }
}
