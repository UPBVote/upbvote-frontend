class UserProfile {
  final String id;
  final String profileId;
  final String createdAt;
  // Solo Expositor y Jurado
  final String? names;
  final String? lastNames;
  final String? gender;
  final String? birthDate;
  // Solo Expositor
  final String? studentId;

  UserProfile({
    required this.id,
    required this.profileId,
    required this.createdAt,
    this.names,
    this.lastNames,
    this.gender,
    this.birthDate,
    this.studentId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? '').toString(),
      profileId: (json['profileId'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      names: json['names']?.toString(),
      lastNames: json['lastNames']?.toString(),
      gender: json['gender']?.toString(),
      birthDate: json['birthDate']?.toString(),
      studentId: json['studentId']?.toString(),
    );
  }
}
