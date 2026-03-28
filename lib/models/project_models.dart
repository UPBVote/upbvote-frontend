class ProjectCourse {
  final String id;
  final String name;

  ProjectCourse({required this.id, required this.name});

  factory ProjectCourse.fromJson(Map<String, dynamic> json) => ProjectCourse(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

class ProjectState {
  final String id;
  final String name;

  ProjectState({required this.id, required this.name});

  factory ProjectState.fromJson(Map<String, dynamic> json) => ProjectState(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

class WorkingGroupMember {
  final String id;
  final String userName;
  final String names;
  final String lastNames;

  WorkingGroupMember({
    required this.id,
    required this.userName,
    required this.names,
    required this.lastNames,
  });

  factory WorkingGroupMember.fromJson(Map<String, dynamic> json) =>
      WorkingGroupMember(
        id: (json['id'] ?? '').toString(),
        userName: (json['userName'] ?? '').toString(),
        names: (json['names'] ?? '').toString(),
        lastNames: (json['lastNames'] ?? '').toString(),
      );

  String get displayName {
    final full = '$names $lastNames'.trim();
    return full.isNotEmpty ? full : userName;
  }
}

class WorkingGroup {
  final String id;
  final String name;
  final String? createdBy;
  final List<WorkingGroupMember> members;

  WorkingGroup({
    required this.id,
    required this.name,
    this.createdBy,
    required this.members,
  });

  factory WorkingGroup.fromJson(Map<String, dynamic> json) => WorkingGroup(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        createdBy: json['createdBy']?.toString(),
        members: (json['members'] is List)
            ? (json['members'] as List)
                .map((e) => WorkingGroupMember.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}

class ProjectSummary {
  final String id;
  final String title;
  final ProjectCourse? course;
  final ProjectState? state;
  final String publicationDate;
  final double averagePublicScore;

  ProjectSummary({
    required this.id,
    required this.title,
    this.course,
    this.state,
    required this.publicationDate,
    required this.averagePublicScore,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) => ProjectSummary(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? 'Sin título').toString(),
        course: json['course'] is Map
            ? ProjectCourse.fromJson(json['course'] as Map<String, dynamic>)
            : null,
        state: json['state'] is Map
            ? ProjectState.fromJson(json['state'] as Map<String, dynamic>)
            : null,
        publicationDate: (json['publicationDate'] ?? '').toString(),
        averagePublicScore:
            double.tryParse(json['averagePublicScore']?.toString() ?? '0') ?? 0.0,
      );
}

class ProjectDetail {
  final String id;
  final String? createdBy;
  final String title;
  final String description;
  final ProjectCourse? course;
  final ProjectState? state;
  final String publicationDate;
  final WorkingGroup? workingGroup;
  final double averagePublicScore;
  final int totalVoters;

  ProjectDetail({
    required this.id,
    this.createdBy,
    required this.title,
    required this.description,
    this.course,
    this.state,
    required this.publicationDate,
    this.workingGroup,
    required this.averagePublicScore,
    required this.totalVoters,
  });

  factory ProjectDetail.fromJson(Map<String, dynamic> json) => ProjectDetail(
        id: (json['id'] ?? '').toString(),
        createdBy: json['createdBy']?.toString(),
        title: (json['title'] ?? 'Sin título').toString(),
        description: (json['description'] ?? '').toString(),
        course: json['course'] is Map
            ? ProjectCourse.fromJson(json['course'] as Map<String, dynamic>)
            : null,
        state: json['state'] is Map
            ? ProjectState.fromJson(json['state'] as Map<String, dynamic>)
            : null,
        publicationDate: (json['publicationDate'] ?? '').toString(),
        workingGroup: json['workingGroup'] is Map
            ? WorkingGroup.fromJson(json['workingGroup'] as Map<String, dynamic>)
            : null,
        averagePublicScore:
            double.tryParse(json['averagePublicScore']?.toString() ?? '0') ?? 0.0,
        totalVoters: int.tryParse(json['totalVoters']?.toString() ?? '0') ?? 0,
      );
}

// ─── Content models ──────────────────────────────────────────────────────────

class ContentType {
  final String id;
  final String name;
  final List<String> allowedExtensions;
  final int maxSizeBytes;
  final int maxCount;

  ContentType({
    required this.id,
    required this.name,
    required this.allowedExtensions,
    required this.maxSizeBytes,
    required this.maxCount,
  });

  factory ContentType.fromJson(Map<String, dynamic> j) => ContentType(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        allowedExtensions: (j['allowed_extensions'] is List)
            ? (j['allowed_extensions'] as List).map((e) => e.toString()).toList()
            : [],
        maxSizeBytes: int.tryParse(j['max_size_bytes']?.toString() ?? '0') ?? 0,
        maxCount: int.tryParse(j['max_count']?.toString() ?? '10') ?? 10,
      );
}

class LinkType {
  final String id;
  final String name;

  LinkType({required this.id, required this.name});

  factory LinkType.fromJson(Map<String, dynamic> j) => LinkType(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

class ProjectFile {
  final String id;
  final String fileName;
  final int size;
  final ContentType contentType;
  final String createdAt;
  final String url;

  ProjectFile({
    required this.id,
    required this.fileName,
    required this.size,
    required this.contentType,
    required this.createdAt,
    required this.url,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> j) => ProjectFile(
        id: (j['id'] ?? '').toString(),
        fileName: (j['file_name'] ?? '').toString(),
        size: int.tryParse(j['size']?.toString() ?? '0') ?? 0,
        contentType: j['content_type'] is Map
            ? ContentType.fromJson(j['content_type'] as Map<String, dynamic>)
            : ContentType(id: '', name: '', allowedExtensions: [], maxSizeBytes: 0, maxCount: 0),
        createdAt: (j['created_at'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
      );

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ProjectLink {
  final String id;
  final String url;
  final String displayName;
  final LinkType linkType;
  final String createdAt;

  ProjectLink({
    required this.id,
    required this.url,
    required this.displayName,
    required this.linkType,
    required this.createdAt,
  });

  factory ProjectLink.fromJson(Map<String, dynamic> j) => ProjectLink(
        id: (j['id'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        displayName: (j['display_name'] ?? '').toString(),
        linkType: j['link_type'] is Map
            ? LinkType.fromJson(j['link_type'] as Map<String, dynamic>)
            : LinkType(id: '', name: ''),
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

class ProjectContent {
  final List<ProjectFile> files;
  final List<ProjectLink> links;

  ProjectContent({required this.files, required this.links});

  factory ProjectContent.fromJson(Map<String, dynamic> j) => ProjectContent(
        files: (j['content'] is List)
            ? (j['content'] as List)
                .map((e) => ProjectFile.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
        links: (j['related_links'] is List)
            ? (j['related_links'] as List)
                .map((e) => ProjectLink.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class PaginatedProjects {
  final List<ProjectSummary> data;
  final int totalPages;
  final int currentPage;
  final int totalItems;

  PaginatedProjects({
    required this.data,
    required this.totalPages,
    required this.currentPage,
    required this.totalItems,
  });

  factory PaginatedProjects.fromJson(Map<String, dynamic> json) => PaginatedProjects(
        data: (json['data'] is List)
            ? (json['data'] as List)
                .map((e) => ProjectSummary.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
        totalPages: int.tryParse(json['totalPages']?.toString() ?? '1') ?? 1,
        currentPage: int.tryParse(json['currentPage']?.toString() ?? '1') ?? 1,
        totalItems: int.tryParse(json['totalItems']?.toString() ?? '0') ?? 0,
      );
}
