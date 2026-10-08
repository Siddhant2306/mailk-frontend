class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'] as String?;
    final role = json['role'] as String?;
    final status = json['status'] as String?;
    if (id is! int || email == null || role == null || status == null) {
      throw const FormatException('Invalid signed-in user response.');
    }

    return AppUser(
      id: id,
      email: email,
      name: (json['name'] as String?)?.trim() ?? '',
      role: role.trim().toLowerCase(),
      status: status.trim().toLowerCase(),
      isActive: json['is_active'] == true,
    );
  }

  final int id;
  final String email;
  final String name;
  final String role;
  final String status;
  final bool isActive;

  bool get isAdmin => role == 'admin' && isActive && status == 'approved';

  String get displayName => name.isEmpty ? email.split('@').first : name;
}
