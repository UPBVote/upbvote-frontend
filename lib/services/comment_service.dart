import '../core/api_client.dart';
import '../models/comment_models.dart';

class CommentService {
  static Future<List<CommentType>> getCommentTypes() async {
    return [
      CommentType.fromJson({'id': '7607f630-2cc7-4abc-8e00-e4a3e1ba8420', 'name': 'PUBLIC'}),
      CommentType.fromJson({'id': 'a78ca5c7-6ac5-47d1-a568-9e2af0647fe8', 'name': 'ANONYMOUS'}),
      CommentType.fromJson({'id': '36c23cda-d251-4c14-b8ce-fab78aec3247', 'name': 'JURY'}),
    ];
  }

  /// GET /projects/{id}/comments/
  static Future<List<Comment>> getComments(String projectId) async {
    print('PROJECT ID: $projectId');
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
    final data = await ApiClient.post('/projects/$projectId/comments/', {
      'comment': comment,
      'commentTypeId': commentTypeId,
    }, requiresAuth: true);
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /projects/{id}/comments/{commentId}/
  static Future<void> deleteComment(String projectId, String commentId) async {
    await ApiClient.delete('/projects/$projectId/comments/$commentId/');
  }
}
