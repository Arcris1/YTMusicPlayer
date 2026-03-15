import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConstants.apiBaseUrl}${AppConstants.apiPrefix}',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;
  FlutterSecureStorage get storage => _storage;

  /// Save tokens after login/register
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  /// Clear tokens on logout
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  /// Check if user has stored tokens
  Future<bool> hasTokens() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null && token.isNotEmpty;
  }
}

/// Interceptor that attaches Bearer token and handles 401 refresh
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  _AuthInterceptor(this._storage, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth header for login/register
    final path = options.path;
    if (path.contains('/auth/login') || path.contains('/auth/register')) {
      return handler.next(options);
    }

    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final response = await Dio(BaseOptions(
            baseUrl: '${AppConstants.apiBaseUrl}${AppConstants.apiPrefix}',
          )).post('/auth/refresh', data: {'refresh_token': refreshToken});

          final newAccess = response.data['access_token'] as String;
          final newRefresh = response.data['refresh_token'] as String;

          await _storage.write(key: AppConstants.accessTokenKey, value: newAccess);
          await _storage.write(key: AppConstants.refreshTokenKey, value: newRefresh);

          // Retry the original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          // Refresh failed — clear tokens
          await _storage.delete(key: AppConstants.accessTokenKey);
          await _storage.delete(key: AppConstants.refreshTokenKey);
        }
      }
    }
    handler.next(err);
  }
}
