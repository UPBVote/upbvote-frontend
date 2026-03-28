import '../core/api_client.dart';
import '../models/vote_models.dart';

class VoteService {
  static Future<List<EvaluationCriterion>> getPublicCriteria() => getCriteria('PUBLIC');
  static Future<List<EvaluationCriterion>> getRubricCriteria() => getCriteria('RUBRIC');

  /// GET /evaluation-criteria/?type=PUBLIC|RUBRIC
  static Future<List<EvaluationCriterion>> getCriteria(String type) async {
    final data = await ApiClient.get('/evaluation-criteria/?type=$type');
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['results'] ?? []) : []);
    return (list as List)
        .map((e) => EvaluationCriterion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Public vote ──────────────────────────────────────────────────────────

  /// GET /projects/{id}/vote/me/  → null if 404
  static Future<MyVote?> getMyVote(String projectId) async {
    try {
      final data = await ApiClient.get('/projects/$projectId/vote/me/');
      return MyVote.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /projects/{id}/vote/
  static Future<MyVote> submitVote(
      String projectId, List<VoteDetail> details) async {
    final data = await ApiClient.post(
      '/projects/$projectId/vote/',
      {'details': details.map((d) => d.toJson()).toList()},
      requiresAuth: true,
    );
    return MyVote.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /projects/{id}/vote/me/
  static Future<MyVote> editVote(
      String projectId, List<VoteDetail> details) async {
    final data = await ApiClient.patch(
      '/projects/$projectId/vote/me/',
      body: {'details': details.map((d) => d.toJson()).toList()},
    );
    return MyVote.fromJson(data as Map<String, dynamic>);
  }

  // ── Jury vote ─────────────────────────────────────────────────────────────

  /// GET /projects/{id}/jury-vote/me/  → null if 404
  static Future<MyVote?> getMyJuryVote(String projectId) async {
    try {
      final data = await ApiClient.get('/projects/$projectId/jury-vote/me/');
      return MyVote.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /projects/{id}/jury-vote/
  static Future<MyVote> submitJuryVote(
      String projectId, List<VoteDetail> details) async {
    final data = await ApiClient.post(
      '/projects/$projectId/jury-vote/',
      {'details': details.map((d) => d.toJson()).toList()},
      requiresAuth: true,
    );
    return MyVote.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /projects/{id}/jury-vote/me/
  static Future<MyVote> editJuryVote(
      String projectId, List<VoteDetail> details) async {
    final data = await ApiClient.patch(
      '/projects/$projectId/jury-vote/me/',
      body: {'details': details.map((d) => d.toJson()).toList()},
    );
    return MyVote.fromJson(data as Map<String, dynamic>);
  }
}
