import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/database_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? username;
  final String? email;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.username,
    this.email,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? username,
    String? email,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      email: email ?? this.email,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkExistingSession();
  }

  final _api = ApiClient();

  Future<void> _checkExistingSession() async {
    final hasTokens = await _api.hasTokens();
    if (hasTokens) {
      // Verify token by calling /auth/me
      try {
        final response = await _api.dio.get('/auth/me');
        final data = response.data as Map<String, dynamic>;
        state = AuthState(
          isAuthenticated: true,
          username: data['username'] as String?,
          email: data['email'] as String?,
        );
      } catch (_) {
        // Token expired or invalid
        await _api.clearTokens();
        state = const AuthState(isAuthenticated: false);
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Backend uses OAuth2PasswordRequestForm which expects form data
      final response = await _api.dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': email, // Backend maps email to username field
          'password': password,
        }),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      final data = response.data as Map<String, dynamic>;
      await _api.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      // Fetch user info
      final meResponse = await _api.dio.get('/auth/me');
      final me = meResponse.data as Map<String, dynamic>;

      state = AuthState(
        isAuthenticated: true,
        username: me['username'] as String?,
        email: me['email'] as String?,
      );
      return true;
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail'] ?? 'Login failed'
          : 'Login failed';
      state = state.copyWith(isLoading: false, error: detail.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.dio.post('/auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
      });

      // Auto-login after registration
      return await login(email, password);
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail'] ?? 'Registration failed'
          : 'Registration failed';
      state = state.copyWith(isLoading: false, error: detail.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    DatabaseService().reset();
    state = const AuthState(isAuthenticated: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
