import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/converter_record.dart';

/// Persistent first-page cache used to make a real app cold launch instant.
/// Pagination remains network-backed after the first page to keep storage small.
class PersistentConverterCatalogCache {
  PersistentConverterCatalogCache({
    SharedPreferences? preferences,
    this.ttl = const Duration(minutes: 5),
  }) : _providedPreferences = preferences;

  static final shared = PersistentConverterCatalogCache();
  static const _keyPrefix = 'catalog.first_page.v1.';
  static const maxStaleAge = Duration(days: 7);

  final SharedPreferences? _providedPreferences;
  final Duration ttl;
  Future<SharedPreferences>? _preferences;

  Future<CachedConverterCatalogPage?> read({
    required String search,
    required int? brandId,
    required int pageSize,
    required Map<int, String> brandsById,
    bool allowStale = true,
  }) async {
    final preferences = await _store;
    final key = _key(search, brandId, pageSize);
    final serialized = preferences.getString(key);
    if (serialized == null) {
      return null;
    }

    try {
      final payload = Map<String, dynamic>.from(jsonDecode(serialized) as Map);
      final cachedAt = DateTime.tryParse(payload['cached_at'] as String? ?? '');
      final pageData = payload['page'];
      if (cachedAt == null || pageData is! Map) {
        await preferences.remove(key);
        return null;
      }
      final age = DateTime.now().difference(cachedAt);
      if (age > maxStaleAge) {
        await preferences.remove(key);
        return null;
      }
      final isFresh = age <= ttl;
      if (!isFresh && !allowStale) {
        return null;
      }
      return CachedConverterCatalogPage(
        page: ConverterCatalogPage.fromJson(
          Map<String, dynamic>.from(pageData),
          brandsById: brandsById,
        ),
        cachedAt: cachedAt,
        isFresh: isFresh,
      );
    } on Object {
      await preferences.remove(key);
      return null;
    }
  }

  Future<void> write({
    required String search,
    required int? brandId,
    required int pageSize,
    required ConverterCatalogPage page,
  }) async {
    final preferences = await _store;
    await preferences.setString(
      _key(search, brandId, pageSize),
      jsonEncode({
        'cached_at': DateTime.now().toIso8601String(),
        'page': page.toJson(),
      }),
    );
  }

  Future<void> invalidate({
    required String search,
    required int? brandId,
    required int pageSize,
  }) async {
    final preferences = await _store;
    await preferences.remove(_key(search, brandId, pageSize));
  }

  Future<void> invalidateAll() async {
    final preferences = await _store;
    for (final key in preferences.getKeys()) {
      if (key.startsWith(_keyPrefix)) {
        await preferences.remove(key);
      }
    }
  }

  Future<SharedPreferences> get _store {
    return _providedPreferences != null
        ? Future.value(_providedPreferences)
        : _preferences ??= SharedPreferences.getInstance();
  }

  String _key(String search, int? brandId, int pageSize) {
    final encodedSearch = base64Url.encode(utf8.encode(search.trim()));
    return '$_keyPrefix$encodedSearch.${brandId ?? 'all'}.$pageSize';
  }
}

class CachedConverterCatalogPage {
  const CachedConverterCatalogPage({
    required this.page,
    required this.cachedAt,
    required this.isFresh,
  });

  final ConverterCatalogPage page;
  final DateTime cachedAt;
  final bool isFresh;
}
