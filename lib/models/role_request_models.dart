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
    final snapshot = json['profileSnapshot'] is Map
        ? json['profileSnapshot'] as Map<String, dynamic>
        : <String, dynamic>{};
    final status = json['status'] is Map
        ? (json['status'] as Map<String, dynamic>)['name'] ?? ''
        : (json['status'] ?? '').toString();
    return RoleRequest(
      id: (json['id'] ?? '').toString(),
      userEmail: (snapshot['email'] ?? json['email'] ?? '').toString(),
      userName: [
        (snapshot['names'] ?? '').toString(),
        (snapshot['lastNames'] ?? '').toString(),
      ].where((s) => s.isNotEmpty).join(' '),
      requestedRole: 'Expositor',
      status: status.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }
}
