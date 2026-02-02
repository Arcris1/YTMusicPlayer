/// API configuration constants
class ApiConstants {
  static const String baseUrl = 'http://localhost:8001';
  static const String apiV1 = '/api/v1';
  
  // Auth endpoints
  static const String login = '$apiV1/auth/login';
  static const String register = '$apiV1/auth/register';
  static const String refresh = '$apiV1/auth/refresh';
  static const String me = '$apiV1/auth/me';
  
  // Search endpoints
  static const String search = '$apiV1/search';
  static const String suggestions = '$apiV1/search/suggestions';
  
  // Playback endpoints
  static const String audioStream = '$apiV1/playback/audio';
  static const String videoStream = '$apiV1/playback/video';
  static const String trackInfo = '$apiV1/playback/info';
  
  // Playlist endpoints
  static const String playlists = '$apiV1/playlists';
}
