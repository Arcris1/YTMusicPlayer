import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart' hide Track;

/// Audio handler for background playback and lock screen / notification controls.
///
/// Delegates transport commands directly to the MediaKit [Player].
/// For skip next/previous the handler emits custom events so that
/// [MediaPlayerController] (which owns queue logic) can respond without
/// creating a circular dependency.
class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;

  /// Attach the MediaKit player after construction.
  /// This allows AudioService.init() to complete before the Player is wired up.
  void attachPlayer(Player player) {
    _player = player;
  }

  // ---------------------------------------------------------------------------
  // Transport controls → delegate to MediaKit Player
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() async {
    _player?.play();
  }

  @override
  Future<void> pause() async {
    _player?.pause();
  }

  @override
  Future<void> stop() async {
    _player?.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _player?.seek(position);
  }

  // ---------------------------------------------------------------------------
  // Skip commands → emit custom events for MediaPlayerController to handle
  // ---------------------------------------------------------------------------

  @override
  Future<void> skipToNext() async {
    customEvent.add('skipToNext');
  }

  @override
  Future<void> skipToPrevious() async {
    customEvent.add('skipToPrevious');
  }

  // ---------------------------------------------------------------------------
  // Helpers called by MediaPlayerController to keep notification in sync
  // ---------------------------------------------------------------------------

  /// Push the current track's metadata to the notification.
  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  /// Push the current playback state to the notification.
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      speed: 1.0,
    ));
  }
}
