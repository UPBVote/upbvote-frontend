class LoginResponse {
  final String token;
  final String userId;
  final String profileId;
  final String email;
  final String userName;
  // Rol tal como viene del backend: 'voter', 'exposer', 'jury', 'secretary', 'admin'
  final String role;

  LoginResponse({
    required this.token,
    required this.userId,
    required this.profileId,
    required this.email,
    required this.userName,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? '').toString();
    final user = (json['user'] is Map)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    // El rol viene en user.type.name (ej: 'VOTER', 'EXPOSER', 'JURY', 'SECRETARY', 'ADMIN')
    final type = (user['type'] is Map)
        ? user['type'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LoginResponse(
      token: token,
      userId: (user['id'] ?? '').toString(),
      profileId: (user['profileId'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      userName: (user['userName'] ?? '').toString(),
      role: (type['name'] ?? '').toString(),
    );
  }
}
