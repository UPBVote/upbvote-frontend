import '../core/api_client.dart';
import '../models/role_request_models.dart';

class RoleRequestService {
  /// GET /role-requests/?status=PENDING
  static Future<List<RoleRequest>> getPendingRequests() async {
    final data = await ApiClient.get('/role-requests/?status=PENDING');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => RoleRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /role-requests/{id}/  — status: APPROVED | REJECTED
  static Future<void> updateStatus(String id, String status) async {
    await ApiClient.patch('/role-requests/$id/', body: {'status': status});
  }

  static Future<void> approve(String id) => updateStatus(id, 'APPROVED');
  static Future<void> reject(String id) => updateStatus(id, 'REJECTED');
}
