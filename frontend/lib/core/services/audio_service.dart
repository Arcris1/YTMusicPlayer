import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:dio/dio.dart';
import '../../shared/models/track.dart';
import '../../config/constants.dart';

/// Loop mode enum for our player
enum LoopMode { off, one, all }

/// State for the audio player
class PlayerState {
  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final bool isShuffled;
  final LoopMode loopMode;
  final String? error;

  const PlayerState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffled = false,
    this.loopMode = LoopMode.off,
    this.error,
  });

  PlayerState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    bool? isShuffled,
    LoopMode? loopMode,
    String? error,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffled: isShuffled ?? this.isShuffled,
      loopMode: loopMode ?? this.loopMode,
      error: error,
    );
  }
}

/// Audio player service using audioplayers (cross-platform)
class AudioPlayerService extends StateNotifier<PlayerState> {
  final ap.AudioPlayer _player;
  final Dio _dio;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  AudioPlayerService() 
      : _player = ap.AudioPlayer(),
        _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )),
        super(const PlayerState()) {
    _initListeners();
  }

  void _initListeners() {
    // Position updates
    _positionSub = _player.onPositionChanged.listen((position) {
      state = state.copyWith(position: position);
    });

    // Duration updates
    _durationSub = _player.onDurationChanged.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    // Player state changes
    _player.onPlayerStateChanged.listen((audioState) {
      state = state.copyWith(
        isPlaying: audioState == ap.PlayerState.playing,
      );
    });

    // Track completion
    _completeSub = _player.onPlayerComplete.listen((_) {
      _onTrackComplete();
    });
  }

  void _onTrackComplete() {
    if (state.loopMode == LoopMode.one) {
      _playCurrentTrack();
    } else {
      next();
    }
  }

  /// Fetch the actual stream URL from the backend
  Future<String?> _fetchStreamUrl(String videoId) async {
    try {
      final response = await _dio.get('${ApiConstants.audioStream}/$videoId');
      if (response.data != null && response.data['url'] != null) {
        return response.data['url'] as String;
      }
    } catch (e) {
      debugPrint('Error fetching stream URL: $e');
    }
    return null;
  }

  Future<void> _playCurrentTrack() async {
    if (state.currentTrack == null) return;
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      final streamUrl = await _fetchStreamUrl(state.currentTrack!.id);
      if (streamUrl == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not get stream URL',
        );
        return;
      }
      
      debugPrint('Playing stream URL: $streamUrl');
      await _player.play(ap.UrlSource(streamUrl));
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Audio playback error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Play a track
  Future<void> play(Track track, {String? streamUrl}) async {
    state = state.copyWith(
      currentTrack: track,
      isLoading: true,
      position: Duration.zero,
      duration: Duration.zero,
      error: null,
    );

    try {
      // If stream URL provided, use it directly; otherwise fetch from API
      String? url = streamUrl;
      if (url == null) {
        url = await _fetchStreamUrl(track.id);
        if (url == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Could not get stream URL',
          );
          return;
        }
      }
      
      debugPrint('Playing stream URL: $url');
      await _player.play(ap.UrlSource(url));
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('Audio playback error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Play a list of tracks
  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    state = state.copyWith(
      queue: tracks,
      currentIndex: startIndex,
    );

    await play(tracks[startIndex]);
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.resume();
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Skip to next track
  Future<void> next() async {
    if (state.queue.isEmpty) return;

    int nextIndex = state.currentIndex + 1;

    if (nextIndex >= state.queue.length) {
      if (state.loopMode == LoopMode.all) {
        nextIndex = 0;
      } else {
        await stop();
        return;
      }
    }

    state = state.copyWith(currentIndex: nextIndex);
    await play(state.queue[nextIndex]);
  }

  /// Skip to previous track
  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = state.currentIndex - 1;

    if (prevIndex < 0) {
      if (state.loopMode == LoopMode.all) {
        prevIndex = state.queue.length - 1;
      } else {
        await seek(Duration.zero);
        return;
      }
    }

    state = state.copyWith(currentIndex: prevIndex);
    await play(state.queue[prevIndex]);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Toggle shuffle
  void toggleShuffle() {
    state = state.copyWith(isShuffled: !state.isShuffled);
  }

  /// Cycle loop mode
  void cycleLoopMode() {
    final modes = LoopMode.values;
    final nextIndex = (modes.indexOf(state.loopMode) + 1) % modes.length;
    final newMode = modes[nextIndex];
    
    state = state.copyWith(loopMode: newMode);
    
    if (newMode == LoopMode.one) {
      _player.setReleaseMode(ap.ReleaseMode.loop);
    } else {
      _player.setReleaseMode(ap.ReleaseMode.release);
    }
  }

  /// Add track to queue
  void addToQueue(Track track) {
    state = state.copyWith(queue: [...state.queue, track]);
  }

  /// Clear queue
  void clearQueue() {
    state = state.copyWith(queue: [], currentIndex: 0);
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    state = const PlayerState();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// Provider for audio player service
final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerService, PlayerState>((ref) {
  return AudioPlayerService();
});
