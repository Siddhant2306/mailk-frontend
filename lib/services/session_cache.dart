import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Stores a non-secret account snapshot for a cache-first returning launch.
/// Firebase owns token storage; this cache deliberately never stores a token.
class SessionCache {
  SessionCache({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  static const _key = 'session.snapshot.v1';
  static const maxAge = Duration(days: 7);

  final SharedPreferences? _providedPreferences;
  Future<SharedPreferences>? _preferences;

  Future<CachedSession?> readForFirebaseUid(String firebaseUid) async {
    final preferences = await _store;
    final serialized = preferences.getString(_key);
    if (serialized == null) {
      return null;
    }

    try {
      final payload = Map<String, dynamic>.from(jsonDecode(serialized) as Map);
      final cachedAt = DateTime.tryParse(payload['cached_at'] as String? ?? '');
      final cachedUid = payload['firebase_uid'] as String?;
      final rawUser = payload['user'];
      if (cachedAt == null ||
          cachedUid == null ||
          cachedUid != firebaseUid ||
          rawUser is! Map ||
          DateTime.now().difference(cachedAt) > maxAge) {
        await clear();
        return null;
      }
      return CachedSession(
        firebaseUid: cachedUid,
        user: AppUser.fromJson(Map<String, dynamic>.from(rawUser)),
        cachedAt: cachedAt,
      );
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write({
    required String firebaseUid,
    required AppUser user,
  }) async {
    final preferences = await _store;
    await preferences.setString(
      _key,
      jsonEncode({
        'firebase_uid': firebaseUid,
        'cached_at': DateTime.now().toIso8601String(),
        'user': user.toJson(),
      }),
    );
  }

  Future<void> clear() async {
    final preferences = await _store;
    await preferences.remove(_key);
  }

  Future<SharedPreferences> get _store {
    return _providedPreferences != null
        ? Future.value(_providedPreferences)
        : _preferences ??= SharedPreferences.getInstance();
  }
}

class CachedSession {
  const CachedSession({
    required this.firebaseUid,
    required this.user,
    required this.cachedAt,
  });

  final String firebaseUid;
  final AppUser user;
  final DateTime cachedAt;
}
