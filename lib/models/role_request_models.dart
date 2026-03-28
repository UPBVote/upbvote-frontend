class RoleRequest {
  final String id;
  final String userEmail;
  final String userName;
  final String requestedRole;
  final String status;
  final String createdAt;

  RoleRequest({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.requestedRole,
    required this.status,
    required this.createdAt,
  });

  factory RoleRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final profile = json['profile'] is Map
        ? json['profile'] as Map<String, dynamic>
        : <String, dynamic>{};
    final role = json['requestedRole'] is Map
        ? json['requestedRole'] as Map<String, dynamic>
        : <String, dynamic>{};
    return RoleRequest(
      id: (json['id'] ?? '').toString(),
      userEmail: (user['email'] ?? json['email'] ?? '').toString(),
      userName: [
        (profile['names'] ?? user['names'] ?? '').toString(),
        (profile['lastNames'] ?? user['lastNames'] ?? '').toString(),
      ].where((s) => s.isNotEmpty).join(' '),
      requestedRole: (role['name'] ?? role['description'] ?? json['requestedRole'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }
}
