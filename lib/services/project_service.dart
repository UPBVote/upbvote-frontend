import '../core/api_client.dart';
import '../models/project_models.dart';

class ProjectService {
  /// GET /courses/
  static Future<List<ProjectCourse>> getCourses() async {
    final data = await ApiClient.get('/courses/');
    final list = data is Map
        ? (data['data'] ?? data['results'] ?? [])
        : (data is List ? data : []);
    return (list as List)
        .map((e) => ProjectCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /projects/
  static Future<ProjectDetail> createProject({
    required String title,
    required String description,
    required String courseId,
    required String workingGroupId,
    required String eventId,
  }) async {
    final data = await ApiClient.post(
      '/projects/',
      {
        'title': title,
        'description': description,
        'courseId': courseId,
        'workingGroupId': workingGroupId,
        'eventId': eventId,
      },
      requiresAuth: true,
    );
    return ProjectDetail.fromJson(data as Map<String, dynamic>);
  }

  /// GET /content-types/
  static Future<List<ContentType>> getContentTypes() async {
    final data = await ApiClient.get('/content-types/');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => ContentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /link-types/
  static Future<List<LinkType>> getLinkTypes() async {
    final data = await ApiClient.get('/link-types/');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => LinkType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /projects/{id}/content/
  static Future<ProjectContent> getProjectContent(String projectId) async {
    final data = await ApiClient.get('/projects/$projectId/content/');
    return ProjectContent.fromJson(data as Map<String, dynamic>);
  }

  /// POST /projects/{id}/content/files/  (multipart)
  static Future<void> uploadFile({
    required String projectId,
    required String filePath,
    required String mimeType,
    required String contentTypeId,
  }) async {
    await ApiClient.postMultipart(
      '/projects/$projectId/content/files/',
      fields: {'contentTypeId': contentTypeId},
      fileField: 'file',
      filePath: filePath,
      mimeType: mimeType,
    );
  }

  /// POST /projects/{id}/content/links/
  static Future<void> addLink({
    required String projectId,
    required String url,
    required String displayName,
    required String linkTypeId,
  }) async {
    await ApiClient.post(
      '/projects/$projectId/content/links/',
      {'url': url, 'displayName': displayName, 'linkTypeId': linkTypeId},
      requiresAuth: true,
    );
  }

  /// DELETE /projects/{id}/content/files/{contentId}/
  static Future<void> deleteFile(String projectId, String contentId) async {
    await ApiClient.delete('/projects/$projectId/content/files/$contentId/');
  }

  /// DELETE /projects/{id}/content/links/{linkId}/
  static Future<void> deleteLink(String projectId, String linkId) async {
    await ApiClient.delete('/projects/$projectId/content/links/$linkId/');
  }

  /// GET /projects/?page=N&search=X&order=Y&event=ID
  static Future<PaginatedProjects> getProjects({
    int page = 1,
    String? search,
    String? order,
    String? eventId,
  }) async {
    final params = <String>['page=$page'];
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (order != null && order.isNotEmpty) params.add('order=$order');
    if (eventId != null && eventId.isNotEmpty) params.add('event=$eventId');

    final data = await ApiClient.get('/projects/?${params.join('&')}');
    return PaginatedProjects.fromJson(data as Map<String, dynamic>);
  }

  /// GET /projects/{id}/
  static Future<ProjectDetail> getProjectDetail(String id) async {
    final data = await ApiClient.get('/projects/$id/');
    return ProjectDetail.fromJson(data as Map<String, dynamic>);
  }

  /// GET /projects/me/
  static Future<List<ProjectSummary>> getMyProjects() async {
    final data = await ApiClient.get('/projects/me/');
    final list = (data is Map && data['data'] is List)
        ? data['data'] as List
        : (data is List ? data : []);
    return list
        .map((e) => ProjectSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
