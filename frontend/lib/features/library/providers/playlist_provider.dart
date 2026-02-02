import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/playlist.dart';

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
  final ApiClient _apiClient;

  PlaylistNotifier(this._apiClient) : super(const PlaylistState()) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final playlists = await _apiClient.getPlaylists();
      state = state.copyWith(isLoading: false, playlists: playlists);
      
      // Attempt to load "Liked Songs" tracks to populate likedTrackIds
      try {
        if (playlists.isNotEmpty) {
          final likedPlaylist = playlists.firstWhere(
            (p) => p.name == 'Liked Songs', 
            orElse: () => playlists.first
          );
          if (likedPlaylist.name == 'Liked Songs') {
             _fetchLikedTracks(likedPlaylist.id);
          }
        }
      } catch (_) {}

    } catch (e, stack) {
      print('Error loading playlists: $e');
      print(stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _fetchLikedTracks(String playlistId) async {
    try {
      final tracks = await _apiClient.getPlaylistTracks(playlistId);
      final ids = tracks.map((t) => t.id).toSet();
      state = state.copyWith(likedTrackIds: ids);
    } catch (e) {
      print('Error loading liked tracks: $e');
    }
  }

  Future<void> toggleLike(String likedPlaylistId, String trackId) async {
    final isLiked = state.likedTrackIds.contains(trackId);
    try {
      if (isLiked) {
        // Unlike (remove)
        await _apiClient.removeTrackFromPlaylist(likedPlaylistId, trackId);
        state = state.copyWith(
          likedTrackIds: Set.from(state.likedTrackIds)..remove(trackId)
        );
      } else {
         // Like (add)
         await _apiClient.addTrackToPlaylist(likedPlaylistId, trackId);
         state = state.copyWith(
          likedTrackIds: Set.from(state.likedTrackIds)..add(trackId)
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
      print('Creating playlist: $name');
      await _apiClient.createPlaylist(name, description: description);
      print('Playlist created, reloading...');
      await loadPlaylists(); // Refresh list
      return true;
    } catch (e, stack) {
      print('Error creating playlist: $e');
      print(stack);
      state = state.copyWith(error: 'Failed to create playlist');
      return false;
    }
  }

  Future<String?> addTrackToPlaylist(String playlistId, String trackId) async {
    try {
      final message = await _apiClient.addTrackToPlaylist(playlistId, trackId);
      // We don't necessarily need to reload all playlists, but maybe update track count?
      // For now, easy way:
      await loadPlaylists();
      return message;
    } catch (e, stack) {
      print('Error adding track to playlist: $e');
      print(stack);
      // Don't update global error state for this, return handling to UI
      return null;
    }
  }
}

/// Provider for playlist notifier
final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlaylistNotifier(apiClient);
});
