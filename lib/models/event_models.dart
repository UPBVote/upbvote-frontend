class EventStatus {
  final String id;
  final String description;

  EventStatus({required this.id, required this.description});

  factory EventStatus.fromJson(Map<String, dynamic> json) => EventStatus(
        id: (json['id'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
      );
}

class EventSummary {
  final String id;
  final String name;
  final EventStatus status;

  EventSummary({required this.id, required this.name, required this.status});

  factory EventSummary.fromJson(Map<String, dynamic> json) => EventSummary(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        status: EventStatus.fromJson(
            (json['status'] is Map) ? json['status'] as Map<String, dynamic> : {}),
      );
}

class Schedule {
  final String id;
  final String name;
  final String openDate;
  final String closeDate;
  final String typeName;

  Schedule({
    required this.id,
    required this.name,
    required this.openDate,
    required this.closeDate,
    required this.typeName,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] is Map) ? json['type'] as Map<String, dynamic> : {};
    return Schedule(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      openDate: (json['openDate'] ?? '').toString(),
      closeDate: (json['closeDate'] ?? '').toString(),
      typeName: (type['name'] ?? '').toString(),
    );
  }
}

class EventJury {
  final String id;
  final String names;
  final String lastNames;

  EventJury({required this.id, required this.names, required this.lastNames});

  factory EventJury.fromJson(Map<String, dynamic> json) => EventJury(
        id: (json['id'] ?? '').toString(),
        names: (json['names'] ?? '').toString(),
        lastNames: (json['lastNames'] ?? '').toString(),
      );
}

class EventProjectItem {
  final String id;
  final String projectId;
  final String title;
  final double averageScore;

  EventProjectItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.averageScore,
  });

  factory EventProjectItem.fromJson(Map<String, dynamic> json) {
    final project = (json['project'] is Map)
        ? json['project'] as Map<String, dynamic>
        : <String, dynamic>{};
    final score = (json['score'] is Map)
        ? json['score'] as Map<String, dynamic>
        : <String, dynamic>{};
    return EventProjectItem(
      id: (json['id'] ?? '').toString(),
      projectId: (project['id'] ?? '').toString(),
      title: (project['title'] ?? 'Sin título').toString(),
      averageScore: double.tryParse(score['averageScore']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class EventDetail {
  final String id;
  final String name;
  final EventStatus status;
  final Schedule? uploadSchedule;
  final Schedule? juryVoteSchedule;
  final List<EventProjectItem> projects;
  final List<EventJury> juries;

  EventDetail({
    required this.id,
    required this.name,
    required this.status,
    this.uploadSchedule,
    this.juryVoteSchedule,
    required this.projects,
    required this.juries,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) => EventDetail(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        status: EventStatus.fromJson(
            (json['status'] is Map) ? json['status'] as Map<String, dynamic> : {}),
        uploadSchedule: json['uploadSchedule'] is Map
            ? Schedule.fromJson(json['uploadSchedule'] as Map<String, dynamic>)
            : null,
        juryVoteSchedule: json['juryVoteSchedule'] is Map
            ? Schedule.fromJson(json['juryVoteSchedule'] as Map<String, dynamic>)
            : null,
        projects: (json['projects'] is List)
            ? (json['projects'] as List)
                .map((e) => EventProjectItem.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
        juries: (json['juries'] is List)
            ? (json['juries'] as List)
                .map((e) => EventJury.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}
