import '../core/api_client.dart';
import '../models/role_request_models.dart';

class RoleRequestService {
  /// GET /role-requests/exposer/ — lista todas (Secretario)
  static Future<List<RoleRequest>> getPendingRequests() async {
    final data = await ApiClient.get('/role-requests/exposer/');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => RoleRequest.fromJson(e as Map<String, dynamic>))
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .toList();
  }

  /// PATCH /role-requests/exposer/{id}/approve/
  static Future<void> approve(String id) async {
    await ApiClient.patch('/role-requests/exposer/$id/approve/');
  }

  /// PATCH /role-requests/exposer/{id}/reject/
  static Future<void> reject(String id) async {
    await ApiClient.patch('/role-requests/exposer/$id/reject/');
  }

  /// POST /role-requests/exposer/ — el Votante pide ser Expositor
  static Future<void> createRequest(Map<String, dynamic> data) async {
    await ApiClient.post(
      '/role-requests/exposer/',
      data,
      requiresAuth: true,
    );
  }

  /// GET /role-requests/exposer/me/status/ — el Votante consulta su estado
  static Future<Map<String, dynamic>?> getMyStatus() async {
    try {
      final data = await ApiClient.get('/role-requests/exposer/me/status/');
      return data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
