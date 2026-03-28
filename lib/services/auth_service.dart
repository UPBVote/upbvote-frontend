import '../core/api_client.dart';
import '../core/app_state.dart';
import '../models/auth_models.dart';

class AuthService {
  /// POST /auth/register/
  static Future<void> register({
    required String userName,
    required String email,
    required String password,
  }) async {
    await ApiClient.post('/auth/register/', {
      'userName': userName,
      'email': email,
      'password': password,
    });
  }

  /// POST /auth/verify-email/
  static Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await ApiClient.post('/auth/verify-email/', {
      'email': email,
      'code': code,
    });
  }

  /// POST /auth/resend-verification/
  static Future<void> resendVerification({required String email}) async {
    await ApiClient.post('/auth/resend-verification/', {'email': email});
  }

  /// POST /auth/login/
  /// Guarda el token y el rol en AppState.
  static Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.post('/auth/login/', {
      'email': email,
      'password': password,
    });

    final response = LoginResponse.fromJson(data as Map<String, dynamic>);

    AppState.token = response.token;
    AppState.userId = response.userId;
    AppState.email = response.email;
    AppState.userName = response.userName;
    AppState.role = _mapRole(response.role);

    return response;
  }

  /// Convierte el rol del backend al texto usado en la UI.
  static String _mapRole(String apiRole) {
    switch (apiRole.toLowerCase()) {
      case 'voter':
        return 'Votante';
      case 'exposer':
        return 'Expositor';
      case 'jury':
        return 'Jurado';
      case 'secretary':
        return 'Secretario';
      default:
        return 'Votante';
    }
  }
}
