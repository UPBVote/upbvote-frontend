import '../core/api_client.dart';
import '../models/profile_models.dart';

class ProfileService {
  /// Retorna el endpoint según el rol del usuario
  static String _endpointForRole(String role) {
    switch (role) {
      case 'Expositor':
        return '/profiles/me/exposer-profile/';
      case 'Jurado':
        return '/profiles/me/jury-profile/';
      case 'Secretario':
        return '/profiles/me/secretary-profile/';
      default: // Votante
        return '/profiles/me/voter-profile/';
    }
  }

  /// GET /profiles/me/{rol}-profile/
  static Future<UserProfile> getMyProfile(String role) async {
    final data = await ApiClient.get(_endpointForRole(role));
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }
}
