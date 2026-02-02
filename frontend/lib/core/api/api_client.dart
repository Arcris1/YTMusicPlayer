import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../config/constants.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';

/// Dio API client with authentication interceptor
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 - try refresh token
          if (error.response?.statusCode == 401) {
            final refreshToken = await _storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              try {
                final response = await _dio.post(
                  ApiConstants.refresh,
                  data: {'refresh_token': refreshToken},
                );
                
                // Save new tokens
                await _storage.write(
                  key: 'access_token',
                  value: response.data['access_token'],
                );
                await _storage.write(
                  key: 'refresh_token',
                  value: response.data['refresh_token'],
                );
                
                // Retry the original request
                error.requestOptions.headers['Authorization'] =
                    'Bearer ${response.data['access_token']}';
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                // Clear tokens on refresh failure
                await _storage.deleteAll();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (const bool.fromEnvironment('dart.vm.product') == false) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Dio get dio => _dio;

  // Auth methods
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // Auth methods
  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {
        'username': email,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    
    await saveTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );
  }

  Future<void> register(String username, String email, String password) async {
    await _dio.post(
      ApiConstants.register,
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
  }

  // Playlist methods
  Future<List<Playlist>> getPlaylists() async {
    final response = await _dio.get(ApiConstants.playlists);
    return (response.data as List)
        .map((json) => Playlist.fromJson(json))
        .toList();
  }

  Future<Playlist> createPlaylist(String name, {String? description, bool isPublic = false}) async {
    final response = await _dio.post(
      ApiConstants.playlists,
      data: {
        'name': name,
        'description': description,
        'is_public': isPublic,
      },
    );
    return Playlist.fromJson(response.data);
  }

  Future<Playlist> getPlaylistDetails(String id) async {
    final response = await _dio.get('${ApiConstants.playlists}/$id');
    final data = response.data;
    // Backend returns detail response with tracks
    return Playlist.fromJson(data);
  }

  Future<List<Track>> getPlaylistTracks(String id) async {
    final response = await _dio.get('${ApiConstants.playlists}/$id');
    final data = response.data;
    if (data['tracks'] != null) {
      return (data['tracks'] as List)
          .map((json) => Track.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<String> addTrackToPlaylist(String playlistId, String trackId) async {
    final response = await _dio.post(
      '${ApiConstants.playlists}/$playlistId/tracks',
      data: {'track_id': trackId},
    );
    return response.data['message']?.toString() ?? 'Track added to playlist';
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _dio.delete(
      '${ApiConstants.playlists}/$playlistId/tracks/$trackId',
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _dio.delete('${ApiConstants.playlists}/$playlistId');
  }
}

// Provider for API client
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
