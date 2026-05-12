import '../core/api_client.dart';
import '../models/project_models.dart';

class ExposerProfile {
  final String id;
  final String names;
  final String lastNames;
  final String userId;
  final String userName;

  ExposerProfile({
    required this.id,
    required this.names,
    required this.lastNames,
    required this.userId,
    required this.userName,
  });

  String get displayName => '$names $lastNames'.trim();

  factory ExposerProfile.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] is Map) ? j['user'] as Map<String, dynamic> : {};
    return ExposerProfile(
      id: (j['id'] ?? '').toString(),
      names: (j['names'] ?? '').toString(),
      lastNames: (j['lastNames'] ?? '').toString(),
      userId: (user['id'] ?? '').toString(),
      userName: (user['userName'] ?? '').toString(),
    );
  }
}

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

  /// GET /profiles/exposers/?search=X
  static Future<List<ExposerProfile>> searchExposers(String query) async {
    final q = Uri.encodeComponent(query);
    final data = await ApiClient.get('/profiles/exposers/?search=$q');
    final list = data is Map
        ? (data['data'] ?? data['results'] ?? [])
        : (data is List ? data : []);
    return (list as List)
        .map((e) => ExposerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /working-groups/<id>/members/
  static Future<WorkingGroup> addMember(String groupId, String userId) async {
    final data = await ApiClient.post(
      '/working-groups/$groupId/members/',
      {'userId': userId},
      requiresAuth: true,
    );
    return WorkingGroup.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /working-groups/<id>/members/<userId>/
  static Future<void> removeMember(String groupId, String userId) async {
    await ApiClient.delete('/working-groups/$groupId/members/$userId/');
  }
}
