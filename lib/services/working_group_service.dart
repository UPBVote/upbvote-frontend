import '../core/api_client.dart';
import '../models/project_models.dart';

class WorkingGroupService {
  /// GET /working-groups/me/
  static Future<List<WorkingGroup>> getMyGroups() async {
    final data = await ApiClient.get('/working-groups/me/');
    final list = data is Map
        ? (data['data'] ?? data['results'] ?? [])
        : (data is List ? data : []);
    return (list as List)
        .map((e) => WorkingGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /working-groups/
  static Future<WorkingGroup> createGroup(String name) async {
    final data = await ApiClient.post(
      '/working-groups/',
      {'name': name},
      requiresAuth: true,
    );
    return WorkingGroup.fromJson(data as Map<String, dynamic>);
  }
}
