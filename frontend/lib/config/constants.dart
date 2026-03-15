/// App configuration constants
class AppConstants {
  static const String appName = 'SpoTube';
  static const String likedSongsPlaylistId = 'liked_songs';

  // Backend API
  static const String apiBaseUrl = 'http://localhost:8001';
  static const String apiPrefix = '/api/v1';

  // Search limits
  static const int searchVideoLimit = 30;
  static const int searchPlaylistLimit = 20;
  static const int relatedVideoLimit = 20;

  // Secure storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
