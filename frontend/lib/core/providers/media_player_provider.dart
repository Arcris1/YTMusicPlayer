import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';
import '../services/audio_handler.dart';
import '../services/youtube_service.dart';
import '../../shared/models/track.dart';
import 'service_providers.dart';

/// Info about the playlist/source the current queue came from.
class PlaylistSource {
  final String id;
  final String title;
  final String? thumbnail;
  final String? channel;

  const PlaylistSource({
    required this.id,
    required this.title,
    this.thumbnail,
    this.channel,
  });
}

/// Global media player state
class MediaPlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String? error;
  final bool isVideoMode;

  const MediaPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.isVideoMode = true,
    this.quality = 'best',
    this.queue = const [],
    this.originalQueue = const [],
    this.currentIndex = -1,
    this.isShuffle = false,
    this.isAutoplayEnabled = true,
    this.isFetchingRelated = false,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.volume = 100.0,
    this.playlistSource,
  });

  final String quality;
  final List<Track> queue;
  final List<Track> originalQueue;
  final int currentIndex;
  final bool isShuffle;
  final bool isAutoplayEnabled;
  final bool isFetchingRelated;
  final int videoWidth;
  final int videoHeight;
  final double volume;
  final PlaylistSource? playlistSource;

  MediaPlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    String? error,
    bool? isVideoMode,
    String? quality,
    List<Track>? queue,
    List<Track>? originalQueue,
    int? currentIndex,
    bool? isShuffle,
    bool? isAutoplayEnabled,
    bool? isFetchingRelated,
    int? videoWidth,
    int? videoHeight,
    double? volume,
    PlaylistSource? playlistSource,
    bool clearError = false,
    bool clearTrack = false,
    bool clearPlaylistSource = false,
  }) {
    return MediaPlayerState(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
      isVideoMode: isVideoMode ?? this.isVideoMode,
      quality: quality ?? this.quality,
      queue: queue ?? this.queue,
      originalQueue: originalQueue ?? this.originalQueue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      isAutoplayEnabled: isAutoplayEnabled ?? this.isAutoplayEnabled,
      isFetchingRelated: isFetchingRelated ?? this.isFetchingRelated,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      volume: volume ?? this.volume,
      playlistSource: clearPlaylistSource ? null : (playlistSource ?? this.playlistSource),
    );
  }

  bool get hasTrack => currentTrack != null;
  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  bool get hasNext => queue.isNotEmpty && currentIndex < queue.length - 1;
  bool get hasPrevious => queue.isNotEmpty && currentIndex > 0;
}

/// Global media player controller using MediaKit
class MediaPlayerController extends StateNotifier<MediaPlayerState> {
  final Player _player;
  final YouTubeService _youtubeService;
  final AppAudioHandler _audioHandler;
  StreamSubscription<dynamic>? _customEventSub;

  /// Incremented on every playTrack call so stale requests are discarded.
  int _playGeneration = 0;

  /// Tracks consecutive playback errors to prevent infinite skip loops.
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  /// Whether a failure was already handled for the current track attempt.
  /// Prevents double-counting when both error + completed fire for the same failure.
  bool _failureHandledForCurrent = false;

  MediaPlayerController(this._player, this._youtubeService, this._audioHandler)
      : super(const MediaPlayerState()) {
    _setupListeners();
    _setupAudioServiceListeners();
  }

  void _setupListeners() {
    // Listen to playing state
    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
      _syncAudioServiceState();
    });

    // Listen to position
    _player.stream.position.listen((position) {
      state = state.copyWith(position: position);
      // Throttle position updates to notification (every ~1 second)
      if (position.inMilliseconds % 1000 < 200) {
        _syncAudioServiceState();
      }
    });

    // Listen to duration
    _player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    // Listen to buffering
    _player.stream.buffering.listen((buffering) {
      if (state.isLoading && !buffering) {
        state = state.copyWith(isLoading: false);
        _syncAudioServiceState();
      }
    });

    // Listen to errors — treat as playback failure
    _player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        debugPrint('[Player] Stream error: $error');
        state = state.copyWith(error: error, isLoading: false);
        _handlePlaybackFailure();
      }
    });

    // Listen to completion
    _player.stream.completed.listen((completed) {
      if (completed) {
        // Check if meaningful playback happened:
        // If position is near zero or duration was never set, the stream
        // failed to load — don't treat this as real completion.
        final playedSomething = state.position.inSeconds > 3 &&
            state.duration.inSeconds > 0;

        if (!playedSomething) {
          debugPrint(
            '[Player] Completed with no real playback '
            '(pos=${state.position.inSeconds}s, dur=${state.duration.inSeconds}s) '
            '— treating as failure',
          );
          _handlePlaybackFailure();
          return;
        }

        // Real completion — reset error counter and advance
        _consecutiveErrors = 0;

        if (state.hasNext) {
          skipToNext();
        } else if (state.isAutoplayEnabled && state.currentTrack != null) {
          _fetchAndPlayRelated(state.currentTrack!.id);
        } else {
          state = state.copyWith(isPlaying: false);
          _syncAudioServiceState();
        }
      }
    });

    // Listen to video dimensions
    _player.stream.width.listen((width) {
      if (width != null && width > 0) {
        state = state.copyWith(videoWidth: width);
      }
    });

    _player.stream.height.listen((height) {
      if (height != null && height > 0) {
        state = state.copyWith(videoHeight: height);
      }
    });

    // Listen to volume
    _player.stream.volume.listen((volume) {
      state = state.copyWith(volume: volume);
    });
  }

  /// Listen for skip commands from the notification / lock screen controls.
  void _setupAudioServiceListeners() {
    _customEventSub = _audioHandler.customEvent.listen((event) {
      if (event == 'skipToNext') {
        skipToNext();
      } else if (event == 'skipToPrevious') {
        skipToPrevious();
      }
    });
  }

  /// Push current playback state to the audio service notification.
  void _syncAudioServiceState() {
    _audioHandler.updatePlaybackState(
      playing: state.isPlaying,
      position: state.position,
      processingState: state.isLoading
          ? AudioProcessingState.loading
          : AudioProcessingState.ready,
    );
  }

  /// Push the current track's metadata to the audio service notification.
  void _pushMediaItem(Track track) {
    _audioHandler.updateMediaItem(MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist ?? 'Unknown artist',
      artUri: Uri.parse(track.thumbnailUrl),
      duration: track.duration != null
          ? Duration(seconds: track.duration!)
          : null,
    ));
  }

  /// Play a track (fetches stream URL from YouTubeService).
  /// [videoMode] defaults to the current state's isVideoMode if not specified.
  ///
  /// Uses a generation counter so that if the user taps a new track while a
  /// previous one is still loading, the stale request is discarded.
  Future<void> playTrack(Track track, {bool? videoMode, String? quality}) async {
    final effectiveVideoMode = videoMode ?? state.isVideoMode;
    final effectiveQuality = quality ?? state.quality;

    // Cancel any in-flight request by bumping the generation
    final thisGeneration = ++_playGeneration;
    _failureHandledForCurrent = false;

    state = state.copyWith(
      currentTrack: track,
      isLoading: true,
      isVideoMode: effectiveVideoMode,
      quality: effectiveQuality,
      clearError: true,
    );

    // Push metadata to notification immediately
    _pushMediaItem(track);
    _audioHandler.updatePlaybackState(
      playing: false,
      position: Duration.zero,
      processingState: AudioProcessingState.loading,
    );

    try {
      debugPrint('[Player] Fetching stream for ${track.id} (video=$effectiveVideoMode)...');

      final streamResult = await (effectiveVideoMode
              ? _youtubeService.getVideoStreamUrl(track.id, quality: effectiveQuality)
              : _youtubeService.getAudioStreamUrl(track.id))
          .timeout(const Duration(seconds: 30));

      // Discard if user already started a newer playTrack call
      if (_playGeneration != thisGeneration) return;

      debugPrint('[Player] Got stream URL: ${streamResult.url}');
      debugPrint('[Player] Headers: ${streamResult.headers?.keys.toList()}');

      if (streamResult.url.isEmpty) {
        debugPrint('[Player] Stream URL is empty!');
        state = state.copyWith(
          error: 'Could not get stream URL',
          isLoading: false,
        );
        _handlePlaybackFailure();
        return;
      }

      // Pass HTTP headers (includes auth token for proxy endpoints)
      final media = Media(
        streamResult.url,
        httpHeaders: streamResult.headers,
      );

      debugPrint('[Player] Opening media in player...');
      await _player.open(media, play: true);
      debugPrint('[Player] Player.open() completed');
    } on TimeoutException {
      if (_playGeneration != thisGeneration) return;
      debugPrint('[Player] TIMEOUT fetching stream for ${track.id}');
      state = state.copyWith(
        error: 'Loading timed out — tap to retry',
        isLoading: false,
      );
      _handlePlaybackFailure();
    } catch (e, stackTrace) {
      if (_playGeneration != thisGeneration) return;
      debugPrint('[Player] ERROR for ${track.id}: $e');
      debugPrint('[Player] Stack: $stackTrace');
      state = state.copyWith(
        error: 'Failed to load: ${e.toString()}',
        isLoading: false,
      );
      _handlePlaybackFailure();
    }
  }

  /// Auto-advance to the next track after an error, with a short delay.
  /// Stops advancing after [_maxConsecutiveErrors] failures in a row.
  void _handlePlaybackFailure() {
    // Prevent double-counting (error + completed can both fire for one failure)
    if (_failureHandledForCurrent) return;
    _failureHandledForCurrent = true;

    _consecutiveErrors++;
    debugPrint('[Player] Consecutive errors: $_consecutiveErrors / $_maxConsecutiveErrors');

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('[Player] Too many consecutive errors — stopping auto-advance');
      state = state.copyWith(
        error: 'Playback failed. Tap a track to try again.',
        isPlaying: false,
        isLoading: false,
      );
      _consecutiveErrors = 0;
      return;
    }

    if (state.hasNext) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) skipToNext();
      });
    }
  }

  /// Play a list of tracks (Queue)
  Future<void> playPlaylist(List<Track> tracks, {int initialIndex = 0, PlaylistSource? source}) async {
    debugPrint('[playPlaylist] source=${source?.title}, tracks=${tracks.length}');
    List<Track> newQueue = List.from(tracks);
    List<Track> newOriginalQueue = List.from(tracks);
    int newIndex = initialIndex;

    if (state.isShuffle) {
      if (newQueue.isNotEmpty) {
        final firstTrack = newQueue[initialIndex];
        newQueue.removeAt(initialIndex);
        newQueue.shuffle();
        newQueue.insert(0, firstTrack);
        newIndex = 0;
      }
    }

    state = state.copyWith(
      queue: newQueue,
      originalQueue: newOriginalQueue,
      currentIndex: newIndex,
      playlistSource: source,
      clearPlaylistSource: source == null,
    );

    if (newQueue.isNotEmpty) {
      await playTrack(newQueue[newIndex]);
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (state.hasNext) {
      final nextIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: nextIndex);
      await playTrack(state.queue[nextIndex]);
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    // If played > 3s, restart current
    if (state.position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }

    if (state.hasPrevious) {
      final prevIndex = state.currentIndex - 1;
      state = state.copyWith(currentIndex: prevIndex);
      await playTrack(state.queue[prevIndex]);
    } else {
      seek(Duration.zero);
    }
  }

  /// Toggle Shuffle
  void toggleShuffle() {
    final newMode = !state.isShuffle;

    if (newMode) {
      if (state.queue.isNotEmpty) {
        final currentTrack = state.queue[state.currentIndex];
        final newQueue = List<Track>.from(state.originalQueue);

        newQueue.removeWhere((t) => t.id == currentTrack.id);
        newQueue.shuffle();
        newQueue.insert(0, currentTrack);

        state = state.copyWith(
          isShuffle: true,
          queue: newQueue,
          currentIndex: 0,
        );
      } else {
        state = state.copyWith(isShuffle: true);
      }
    } else {
      if (state.currentTrack != null) {
        final currentId = state.currentTrack!.id;
        final originalIndex = state.originalQueue.indexWhere((t) => t.id == currentId);

        state = state.copyWith(
          isShuffle: false,
          queue: state.originalQueue,
          currentIndex: originalIndex != -1 ? originalIndex : 0,
        );
      } else {
        state = state.copyWith(isShuffle: false, queue: state.originalQueue);
      }
    }
  }

  /// Change video quality
  Future<void> changeQuality(String quality) async {
    if (state.currentTrack == null || state.quality == quality) return;

    final currentPosition = state.position;

    await playTrack(state.currentTrack!, quality: quality);

    if (currentPosition > Duration.zero) {
      await _player.seek(currentPosition);
    }
  }

  /// Toggle play/pause
  void togglePlayPause() {
    _player.playOrPause();
  }

  /// Play
  void play() {
    _player.play();
  }

  /// Pause
  void pause() {
    _player.pause();
  }

  /// Seek to position
  void seek(Duration position) {
    _player.seek(position);
  }

  /// Seek by percentage (0.0 - 1.0)
  void seekToPercent(double percent) {
    final newPosition = Duration(
      milliseconds: (state.duration.inMilliseconds * percent).round(),
    );
    _player.seek(newPosition);
  }

  /// Set volume (0.0 to 100.0)
  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  /// Stop playback
  void stop() {
    _player.stop();
    state = state.copyWith(clearTrack: true, isPlaying: false, clearPlaylistSource: true);
    _audioHandler.updatePlaybackState(
      playing: false,
      position: Duration.zero,
      processingState: AudioProcessingState.idle,
    );
  }

  /// Toggle video mode
  void setVideoMode(bool videoMode) {
    state = state.copyWith(isVideoMode: videoMode);
  }

  /// Toggle autoplay
  void toggleAutoplay() {
    state = state.copyWith(isAutoplayEnabled: !state.isAutoplayEnabled);
  }

  /// Fetch and play related tracks when queue ends (with timeout).
  Future<void> _fetchAndPlayRelated(String videoId) async {
    if (state.isFetchingRelated) return;

    state = state.copyWith(isFetchingRelated: true);

    try {
      final results = await _youtubeService
          .getRelatedVideos(videoId)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (results.isNotEmpty) {
        state = state.copyWith(
          queue: results,
          originalQueue: results,
          currentIndex: 0,
          isFetchingRelated: false,
        );
        await playTrack(results[0]);
      } else {
        state = state.copyWith(isFetchingRelated: false, isPlaying: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isFetchingRelated: false, isPlaying: false);
    }
  }

  @override
  void dispose() {
    _customEventSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// Providers

// Player instance — must be overridden in main.dart ProviderScope
final playerProvider = Provider<Player>((ref) {
  throw UnimplementedError('playerProvider must be overridden in ProviderScope');
});

// Audio handler — must be overridden in main.dart ProviderScope
final audioHandlerProvider = Provider<AppAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in ProviderScope');
});

// Media player controller
final mediaPlayerControllerProvider =
    StateNotifierProvider<MediaPlayerController, MediaPlayerState>((ref) {
  final player = ref.watch(playerProvider);
  final youtubeService = ref.watch(youtubeServiceProvider);
  final audioHandler = ref.watch(audioHandlerProvider);
  return MediaPlayerController(player, youtubeService, audioHandler);
});

// Convenience providers for specific state
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(mediaPlayerControllerProvider).isPlaying;
});

final currentTrackProvider = Provider<Track?>((ref) {
  return ref.watch(mediaPlayerControllerProvider).currentTrack;
});

final videoControllerProvider = Provider<VideoController>((ref) {
  final player = ref.watch(playerProvider);
  return VideoController(
    player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: false,
    ),
  );
});

final playerProgressProvider = Provider<double>((ref) {
  return ref.watch(mediaPlayerControllerProvider).progress;
});
