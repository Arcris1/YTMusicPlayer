import '../api/api_client.dart';
import '../../shared/models/track.dart';
import '../../shared/models/playlist.dart';

/// Service that calls the Python backend for playlist/library operations.
/// Replaces the local SQLite DatabaseService.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// The liked songs playlist ID from the backend (resolved at runtime).
  String? _likedSongsId;
  String get likedSongsId => _likedSongsId ?? '';

  final _api = ApiClient();

  // --- Playlists (calls backend /playlists endpoints) ---

  Future<List<Playlist>> getPlaylists() async {
    final response = await _api.dio.get('/playlists');
    final list = response.data as List;
    final playlists = list.map((r) => Playlist.fromJson(r as Map<String, dynamic>)).toList();

    // Identify or create the "Liked Songs" playlist
    await _ensureLikedSongsPlaylist(playlists);

    return playlists;
  }

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final response = await _api.dio.post('/playlists', data: {
      'name': name,
      if (description != null) 'description': description,
    });
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Playlist> getPlaylistDetails(String playlistId) async {
    final response = await _api.dio.get('/playlists/$playlistId');
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _api.dio.delete('/playlists/$playlistId');
  }

  Future<String> addTrackToPlaylist(String playlistId, Track track) async {
    final response = await _api.dio.post('/playlists/$playlistId/tracks', data: {
      'track_id': track.id,
    });
    return response.data['message'] as String? ?? 'Added to playlist';
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _api.dio.delete('/playlists/$playlistId/tracks/$trackId');
  }

  // --- Liked tracks ---

  final Set<String> _likedIds = {};
  bool _likedLoaded = false;

  /// Ensure a "Liked Songs" playlist exists on the backend.
  Future<void> _ensureLikedSongsPlaylist(List<Playlist> playlists) async {
    // Look for existing "Liked Songs" playlist
    final existing = playlists.where((p) => p.name == 'Liked Songs').firstOrNull;
    if (existing != null) {
      _likedSongsId = existing.id;
      return;
    }

    // Create it
    try {
      final created = await createPlaylist('Liked Songs', description: 'Your liked songs');
      _likedSongsId = created.id;
      playlists.add(created);
    } catch (_) {
      // Best effort
    }
  }

  Future<void> toggleLike(Track track) async {
    if (_likedSongsId == null || _likedSongsId!.isEmpty) return;

    await _ensureLikedLoaded();
    if (_likedIds.contains(track.id)) {
      try {
        await removeTrackFromPlaylist(_likedSongsId!, track.id);
        _likedIds.remove(track.id);
      } catch (_) {}
    } else {
      try {
        await addTrackToPlaylist(_likedSongsId!, track);
        _likedIds.add(track.id);
      } catch (_) {}
    }
  }

  Future<Set<String>> getLikedTrackIds() async {
    await _ensureLikedLoaded();
    return Set.from(_likedIds);
  }

  Future<void> _ensureLikedLoaded() async {
    if (_likedLoaded || _likedSongsId == null || _likedSongsId!.isEmpty) return;
    try {
      final playlist = await getPlaylistDetails(_likedSongsId!);
      _likedIds.clear();
      for (final track in playlist.tracks ?? []) {
        _likedIds.add(track.id);
      }
    } catch (_) {}
    _likedLoaded = true;
  }

  /// Reset cached state (call on logout)
  void reset() {
    _likedIds.clear();
    _likedLoaded = false;
    _likedSongsId = null;
  }
}
