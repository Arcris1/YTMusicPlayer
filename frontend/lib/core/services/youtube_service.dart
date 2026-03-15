import '../api/api_client.dart';
import '../../shared/models/track.dart';
import '../../shared/models/youtube_playlist.dart';

/// Result from getting a stream URL
class StreamResult {
  final String url;
  final String title;
  final int duration;
  final String? thumbnail;
  final Map<String, String>? headers;

  const StreamResult({
    required this.url,
    required this.title,
    required this.duration,
    this.thumbnail,
    this.headers,
  });
}

/// Singleton service that calls the Python backend for YouTube data.
class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  final _api = ApiClient();

  /// Search for videos (calls GET /search)
  Future<List<Track>> searchVideos(String query, {int limit = 30}) async {
    final response = await _api.dio.get('/search', queryParameters: {
      'query': query,
      'limit': limit,
    });

    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List;
    return results.map((r) => Track.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Search for playlists (calls GET /search/playlists)
  Future<List<YouTubePlaylist>> searchPlaylists(String query, {int limit = 20}) async {
    final response = await _api.dio.get('/search/playlists', queryParameters: {
      'query': query,
      'limit': limit,
    });

    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List;
    return results.map((r) => YouTubePlaylist.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Get playlist tracks (calls GET /search/playlists/{id})
  Future<Map<String, dynamic>> getPlaylistTracks(String playlistId) async {
    final response = await _api.dio.get('/search/playlists/$playlistId');
    final data = response.data as Map<String, dynamic>;

    final tracksList = data['tracks'] as List;
    final tracks = tracksList.map((t) => Track.fromJson(t as Map<String, dynamic>)).toList();

    return {
      'playlist_id': data['playlist_id'],
      'title': data['title'],
      'channel': data['channel'],
      'thumbnail': data['thumbnail'],
      'video_count': data['video_count'],
      'tracks': tracks,
    };
  }

  /// Get audio stream URL (calls GET /playback/audio/{id})
  Future<StreamResult> getAudioStreamUrl(String videoId) async {
    final response = await _api.dio.get('/playback/audio/$videoId');
    final data = response.data as Map<String, dynamic>;

    return StreamResult(
      url: data['url'] as String,
      title: data['title'] as String,
      duration: data['duration'] as int? ?? 0,
      thumbnail: data['thumbnail'] as String?,
      headers: data['headers'] != null
          ? Map<String, String>.from(data['headers'] as Map)
          : null,
    );
  }

  /// Get video stream URL (calls GET /playback/video/{id})
  Future<StreamResult> getVideoStreamUrl(String videoId, {String quality = 'best'}) async {
    final response = await _api.dio.get('/playback/video/$videoId', queryParameters: {
      'quality': quality,
    });
    final data = response.data as Map<String, dynamic>;

    return StreamResult(
      url: data['url'] as String,
      title: data['title'] as String,
      duration: data['duration'] as int? ?? 0,
      thumbnail: data['thumbnail'] as String?,
      headers: data['headers'] != null
          ? Map<String, String>.from(data['headers'] as Map)
          : null,
    );
  }

  /// Get video info (calls GET /playback/info/{id})
  Future<Track> getVideoInfo(String videoId) async {
    final response = await _api.dio.get('/playback/info/$videoId');
    final data = response.data as Map<String, dynamic>;
    return Track.fromJson(data);
  }

  /// Get related videos (calls GET /playback/related/{id})
  Future<List<Track>> getRelatedVideos(String videoId, {int limit = 20}) async {
    final response = await _api.dio.get('/playback/related/$videoId', queryParameters: {
      'limit': limit,
    });
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List;
    return results.map((r) => Track.fromJson(r as Map<String, dynamic>)).toList();
  }

  void dispose() {
    // No-op — Dio manages its own lifecycle
  }
}
