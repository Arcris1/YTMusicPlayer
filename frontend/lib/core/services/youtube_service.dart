import '../api/api_client.dart';
import '../../config/constants.dart';
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

  /// Build a proxy stream URL that pipes audio/video through the backend.
  /// This avoids YouTube's IP-lock on direct stream URLs.
  String _proxyStreamUrl(String type, String videoId, {String? quality}) {
    final base =
        '${AppConstants.apiBaseUrl}${AppConstants.apiPrefix}/playback/stream/$type/$videoId';
    if (quality != null && quality != 'best') {
      return '$base?quality=$quality';
    }
    return base;
  }

  /// Get the current auth token for passing to MediaKit as an HTTP header.
  Future<String?> _getAccessToken() async {
    return await _api.storage.read(key: AppConstants.accessTokenKey);
  }

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

  /// Get audio stream — returns a proxy URL through our backend.
  /// The backend fetches from YouTube and pipes the bytes to the client,
  /// avoiding YouTube's IP-lock on direct stream URLs.
  Future<StreamResult> getAudioStreamUrl(String videoId) async {
    // First fetch metadata (title, duration, thumbnail) from the info endpoint
    final info = await getVideoInfo(videoId);
    final token = await _getAccessToken();

    return StreamResult(
      url: _proxyStreamUrl('audio', videoId),
      title: info.title,
      duration: info.duration ?? 0,
      thumbnail: info.thumbnailUrl,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Get video stream — returns a proxy URL through our backend.
  Future<StreamResult> getVideoStreamUrl(String videoId, {String quality = 'best'}) async {
    final info = await getVideoInfo(videoId);
    final token = await _getAccessToken();

    return StreamResult(
      url: _proxyStreamUrl('video', videoId, quality: quality),
      title: info.title,
      duration: info.duration ?? 0,
      thumbnail: info.thumbnailUrl,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
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
