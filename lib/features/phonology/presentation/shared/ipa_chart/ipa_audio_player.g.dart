// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ipa_audio_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for the shared IPA audio player.
///
/// Wraps a single [AudioPlayer] instance that is reused for all IPA sounds.
/// Previous playback is stopped before each new sound is played.

@ProviderFor(ipaAudioPlayer)
const ipaAudioPlayerProvider = IpaAudioPlayerProvider._();

/// Riverpod provider for the shared IPA audio player.
///
/// Wraps a single [AudioPlayer] instance that is reused for all IPA sounds.
/// Previous playback is stopped before each new sound is played.

final class IpaAudioPlayerProvider
    extends $FunctionalProvider<IpaAudioPlayer, IpaAudioPlayer, IpaAudioPlayer>
    with $Provider<IpaAudioPlayer> {
  /// Riverpod provider for the shared IPA audio player.
  ///
  /// Wraps a single [AudioPlayer] instance that is reused for all IPA sounds.
  /// Previous playback is stopped before each new sound is played.
  const IpaAudioPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ipaAudioPlayerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ipaAudioPlayerHash();

  @$internal
  @override
  $ProviderElement<IpaAudioPlayer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IpaAudioPlayer create(Ref ref) {
    return ipaAudioPlayer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IpaAudioPlayer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IpaAudioPlayer>(value),
    );
  }
}

String _$ipaAudioPlayerHash() => r'8c9572cce634482916fe224f41bc4971070822c5';
