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

  MyVote({required this.id, required this.details});

  factory MyVote.fromJson(Map<String, dynamic> j) => MyVote(
        id: (j['id'] ?? '').toString(),
        details: (j['details'] is List)
            ? (j['details'] as List)
                .map((e) => VoteDetail(
                      criterionId: (e['criterionId'] ?? '').toString(),
                      score: double.tryParse(e['score']?.toString() ?? '0') ?? 0,
                    ))
                .toList()
            : [],
      );
}
