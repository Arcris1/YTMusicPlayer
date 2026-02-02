import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';
import '../../config/constants.dart';
import '../../shared/models/track.dart';

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
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.volume = 100.0,
  });

  final String quality;
  final List<Track> queue;
  final List<Track> originalQueue; // Backup for un-shuffling
  final int currentIndex;
  final bool isShuffle;
  final int videoWidth;
  final int videoHeight;
  final double volume;

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
    int? videoWidth,
    int? videoHeight,
    double? volume,
    bool clearError = false,
    bool clearTrack = false,
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
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      volume: volume ?? this.volume,
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
  final Dio _dio;
  
  MediaPlayerController(this._player, this._dio) : super(const MediaPlayerState()) {
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to playing state
    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    // Listen to position
    _player.stream.position.listen((position) {
      state = state.copyWith(position: position);
    });

    // Listen to duration
    _player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    // Listen to buffering
    _player.stream.buffering.listen((buffering) {
      if (state.isLoading && !buffering) {
        state = state.copyWith(isLoading: false);
      }
    });

    // Listen to errors
    _player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        state = state.copyWith(error: error, isLoading: false);
      }
    });

    // Listen to completion
    _player.stream.completed.listen((completed) {
      if (completed) {
        // Auto-play next track
        if (state.hasNext) {
          skipToNext();
        } else {
          state = state.copyWith(isPlaying: false);
        }
      }
    });

    // Listen to video dimensions
    _player.stream.width.listen((width) {
      print('MediaPlayer: Width Changed: $width');
      if (width != null && width > 0) {
        state = state.copyWith(videoWidth: width);
      }
    });
    
    _player.stream.height.listen((height) {
      print('MediaPlayer: Height Changed: $height');
      if (height != null && height > 0) {
        state = state.copyWith(videoHeight: height);
      }
    });

    // Listen to volume
    _player.stream.volume.listen((volume) {
      state = state.copyWith(volume: volume);
    });
  }

  /// Play a track (fetches stream URL from backend)
  Future<void> playTrack(Track track, {bool videoMode = true, String quality = 'best'}) async {
    print('MediaPlayer: Playing track ${track.title} (Video: $videoMode)');
    state = state.copyWith(
      currentTrack: track,
      isLoading: true,
      isVideoMode: videoMode,
      quality: quality,
      clearError: true,
      // Don't reset dimensions to avoid desync if resolutions match
    );

    try {
      // Fetch stream URL from backend
      final endpoint = videoMode ? ApiConstants.videoStream : ApiConstants.audioStream;
      final response = await _dio.get(
        '$endpoint/${track.id}',
        queryParameters: {'quality': quality},
      );

      final streamUrl = response.data['url'] as String?;
      if (streamUrl == null || streamUrl.isEmpty) {
        state = state.copyWith(
          error: 'Could not get stream URL',
          isLoading: false,
        );
        return;
      }

      // Extract headers
      Map<String, String> headers = {};
      if (response.data['headers'] != null) {
        final headersMap = response.data['headers'] as Map;
        headersMap.forEach((key, value) {
          headers[key.toString()] = value.toString();
        });
      }

      // Open and play
      await _player.open(
        Media(streamUrl, httpHeaders: headers),
        play: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  /// Play a list of tracks (Queue)
  Future<void> playPlaylist(List<Track> tracks, {int initialIndex = 0}) async {
    // If shuffle is on, we should shuffle immediately? 
    // For now, let's respect current shuffle state or default to off?
    // Let's reset shuffle when playing a NEW playlist to be safe, or keep user preference.
    // Better: keep user preference. If shuffle IS on, shuffle the new list.
    
    List<Track> newQueue = List.from(tracks);
    List<Track> newOriginalQueue = List.from(tracks);
    int newIndex = initialIndex;

    if (state.isShuffle) {
      // Shuffle logic: Keep started track first, shuffle rest
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
    );
    
    if (newQueue.isNotEmpty) {
      await playTrack(newQueue[newIndex], videoMode: state.isVideoMode, quality: state.quality);
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (state.hasNext) {
      final nextIndex = state.currentIndex + 1;
      state = state.copyWith(currentIndex: nextIndex);
      await playTrack(state.queue[nextIndex], videoMode: state.isVideoMode, quality: state.quality);
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
      await playTrack(state.queue[prevIndex], videoMode: state.isVideoMode, quality: state.quality);
    } else {
      seek(Duration.zero);
    }
  }

  /// Toggle Shuffle
  void toggleShuffle() {
    final newMode = !state.isShuffle;
    
    if (newMode) {
      // Turn Shuffle ON
      if (state.queue.isNotEmpty) {
        final currentTrack = state.queue[state.currentIndex];
        final newQueue = List<Track>.from(state.originalQueue); // Copy original
        
        // Remove current, shuffle rest, prepend current
        newQueue.removeWhere((t) => t.id == currentTrack.id);
        newQueue.shuffle();
        newQueue.insert(0, currentTrack);
        
        state = state.copyWith(
          isShuffle: true,
          queue: newQueue,
          currentIndex: 0, // Current track is now first
        );
      } else {
        state = state.copyWith(isShuffle: true);
      }
    } else {
      // Turn Shuffle OFF
      if (state.currentTrack != null) {
        // Restore original queue
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
    final wasPlaying = state.isPlaying;

    await playTrack(state.currentTrack!, videoMode: state.isVideoMode, quality: quality);
    
    // Seek back to position
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
    // State will be updated via stream listener
  }

  /// Stop playback
  void stop() {
    _player.stop();
    state = state.copyWith(clearTrack: true, isPlaying: false);
  }

  /// Toggle video mode
  void setVideoMode(bool videoMode) {
    state = state.copyWith(isVideoMode: videoMode);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// Providers

// Player instance (singleton)
final playerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(() => player.dispose());
  return player;
});

// Dio instance for API calls
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
});

// Media player controller
final mediaPlayerControllerProvider = 
    StateNotifierProvider<MediaPlayerController, MediaPlayerState>((ref) {
  final player = ref.watch(playerProvider);
  final dio = ref.watch(dioProvider);
  return MediaPlayerController(player, dio);
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
