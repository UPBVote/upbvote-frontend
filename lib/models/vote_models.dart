class EvaluationCriterion {
  final String id;
  final String name;
  final String description;
  final double weight;
  final double minScore;
  final double maxScore;

  EvaluationCriterion({
    required this.id,
    required this.name,
    required this.description,
    required this.weight,
    required this.minScore,
    required this.maxScore,
  });

  factory EvaluationCriterion.fromJson(Map<String, dynamic> j) =>
      EvaluationCriterion(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        weight: double.tryParse(j['weight']?.toString() ?? '0') ?? 0,
        minScore: double.tryParse(j['minScore']?.toString() ?? '0') ?? 0,
        maxScore: double.tryParse(j['maxScore']?.toString() ?? '10') ?? 10,
      );
}

class VoteDetail {
  final String criterionId;
  final double score;

  VoteDetail({required this.criterionId, required this.score});

  Map<String, dynamic> toJson() => {'criterionId': criterionId, 'score': score};
}

class MyVote {
  final String id;
  final List<VoteDetail> details;
  final String? comment;

  MyVote({required this.id, required this.details, this.comment});

  factory MyVote.fromJson(Map<String, dynamic> j) => MyVote(
    id: (j['id'] ?? '').toString(),
    details: (j['details'] is List)
        ? (j['details'] as List)
              .map(
                (e) => VoteDetail(
                  criterionId: (e['criterionId'] ?? '').toString(),
                  score: double.tryParse(e['score']?.toString() ?? '0') ?? 0,
                ),
              )
              .toList()
        : [],
    comment: j['comment']?.toString(),
  );
}

class JuryEvaluation {
  final String juryName;
  final double score;
  final String comment;
  final String userId; // <-- agregar

  JuryEvaluation({
    required this.juryName,
    required this.score,
    required this.comment,
    this.userId = '',
  });

  JuryEvaluation copyWith({
    String? juryName,
    double? score,
    String? comment,
    String? userId,
  }) {
    return JuryEvaluation(
      juryName: juryName ?? this.juryName,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      userId: userId ?? this.userId,
    );
  }

  factory JuryEvaluation.fromJson(Map<String, dynamic> j) {
    // El score viene en details[], promediamos
    double score = 0;
    final details = j['details'] as List? ?? [];
    if (details.isNotEmpty) {
      final sum = details.fold<double>(
        0,
        (acc, d) =>
            acc + (double.tryParse((d['score'] ?? '0').toString()) ?? 0),
      );
      score = sum / details.length;
    } else {
      final rawScore = j['averageScore'] ?? j['score'] ?? j['totalScore'] ?? 0;
      score = double.tryParse(rawScore.toString()) ?? 0;
    }

    return JuryEvaluation(
      juryName: (j['juryName'] ?? j['jury_name'] ?? 'Jurado').toString(),
      score: score,
      comment: (j['comment'] ?? '').toString(),
      userId: (j['userId'] ?? '').toString(),
    );
  }
}

class JuryFeedback {
  final double totalAverage;
  final List<JuryEvaluation> evaluations;

  JuryFeedback({required this.totalAverage, required this.evaluations});

  factory JuryFeedback.fromJson(dynamic data) {
    final map = data as Map<String, dynamic>;
    final avg = double.tryParse((map['averageJuryScore'] ?? 0).toString()) ?? 0;
    final votes = (map['juryVotes'] ?? []) as List;
    final comments = (map['comments'] ?? []) as List;

    // Sacar userId y comment directo de comments
    final firstComment = comments.isNotEmpty
        ? comments[0] as Map<String, dynamic>
        : null;
    final commentUserId = firstComment != null
        ? (firstComment['userId'] ?? '').toString()
        : '';
    final commentText = firstComment != null
        ? (firstComment['comment'] ?? '').toString()
        : '';

    final evals = votes.map((e) {
      final vm = e as Map<String, dynamic>;
      final details = (vm['details'] ?? []) as List;
      double score = 0;
      if (details.isNotEmpty) {
        final sum = details.fold<double>(
          0,
          (acc, d) =>
              acc + (double.tryParse((d['score'] ?? '0').toString()) ?? 0),
        );
        score = sum / details.length;
      }
      return JuryEvaluation(
        juryName: 'Jurado',
        userId: commentUserId, // userId real para consultar nombre
        score: score,
        comment: commentText,
      );
    }).toList();

    return JuryFeedback(totalAverage: avg, evaluations: evals);
  }
}
