import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/models/playlist.dart';
import '../../../shared/models/track.dart';

/// Playlist state
class PlaylistState {
  final bool isLoading;
  final List<Playlist> playlists;
  final Set<String> likedTrackIds;
  final String? error;

  const PlaylistState({
    this.isLoading = false,
    this.playlists = const [],
    this.likedTrackIds = const {},
    this.error,
  });

  PlaylistState copyWith({
    bool? isLoading,
    List<Playlist>? playlists,
    Set<String>? likedTrackIds,
    String? error,
  }) {
    return PlaylistState(
      isLoading: isLoading ?? this.isLoading,
      playlists: playlists ?? this.playlists,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      error: error,
    );
  }
}

/// Playlist notifier
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final DatabaseService _dbService;

  PlaylistNotifier(this._dbService) : super(const PlaylistState()) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final playlists = await _dbService.getPlaylists();
      final likedIds = await _dbService.getLikedTrackIds();
      state = state.copyWith(
        isLoading: false,
        playlists: playlists,
        likedTrackIds: likedIds,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleLike(Track track) async {
    final isLiked = state.likedTrackIds.contains(track.id);
    try {
      await _dbService.toggleLike(track);
      if (isLiked) {
        state = state.copyWith(
          likedTrackIds: Set.from(state.likedTrackIds)..remove(track.id),
        );
      } else {
        state = state.copyWith(
          likedTrackIds: Set.from(state.likedTrackIds)..add(track.id),
        );
      }
      // Refresh playlists to update counts
      loadPlaylists();
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<bool> createPlaylist(String name, {String? description}) async {
    try {
      await _dbService.createPlaylist(name, description: description);
      await loadPlaylists();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create playlist');
      return false;
    }
  }

  Future<String?> addTrackToPlaylist(String playlistId, Track track) async {
    try {
      final message = await _dbService.addTrackToPlaylist(playlistId, track);
      await loadPlaylists();
      return message;
    } catch (e) {
      return null;
    }
  }
}

/// Provider for playlist notifier
final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return PlaylistNotifier(dbService);
});
