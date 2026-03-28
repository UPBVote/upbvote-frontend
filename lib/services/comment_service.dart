import '../core/api_client.dart';
import '../models/comment_models.dart';

class CommentService {
  /// GET /comment-types/
  static Future<List<CommentType>> getCommentTypes() async {
    final data = await ApiClient.get('/comment-types/');
    final list = data is Map
        ? (data['data'] ?? data['results'] ?? [])
        : (data is List ? data : []);
    return (list as List)
        .map((e) => CommentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /projects/{id}/comments/
  static Future<List<Comment>> getComments(String projectId) async {
    final data = await ApiClient.get('/projects/$projectId/comments/');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /projects/{id}/comments/
  static Future<Comment> createComment({
    required String projectId,
    required String comment,
    required String commentTypeId,
  }) async {
    final data = await ApiClient.post(
      '/projects/$projectId/comments/',
      {'comment': comment, 'commentTypeId': commentTypeId},
      requiresAuth: true,
    );
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /projects/{id}/comments/{commentId}/
  static Future<void> deleteComment(
      String projectId, String commentId) async {
    await ApiClient.delete('/projects/$projectId/comments/$commentId/');
  }
}
