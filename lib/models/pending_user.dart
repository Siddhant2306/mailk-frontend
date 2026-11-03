class PendingUser {
  const PendingUser({
    required this.id,
    required this.email,
    required this.name,
  });

  factory PendingUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! int || email is! String || email.trim().isEmpty) {
      throw const FormatException('Invalid admin user record.');
    }

    return PendingUser(
      id: id,
      email: email.trim(),
      name: (json['name'] as String?)?.trim() ?? '',
    );
  }

  final int id;
  final String email;
  final String name;

  String get displayName => name.isEmpty ? email.split('@').first : name;

  static List<PendingUser> pendingFromResponse(Object? data) {
    final rawUsers = data is List
        ? data
        : data is Map && data['users'] is List
        ? data['users'] as List
        : null;
    if (rawUsers == null) {
      throw const FormatException('Invalid admin users response.');
    }

    final pendingUsers = <PendingUser>[];
    for (final rawUser in rawUsers) {
      if (rawUser is! Map) {
        throw const FormatException('Invalid admin user record.');
      }
      final status = rawUser['status'];
      if (status is! String) {
        throw const FormatException('Invalid admin user status.');
      }
      if (status.trim().toLowerCase() == 'pending') {
        pendingUsers.add(
          PendingUser.fromJson(Map<String, dynamic>.from(rawUser)),
        );
      }
    }
    return pendingUsers;
  }
}
