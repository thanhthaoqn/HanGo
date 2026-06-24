class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String token;
  final int userId;
  final String fullName;
  final String email;
  final String role;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName'] as String? ?? 'Learner',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'LEARNER',
    );
  }
}
