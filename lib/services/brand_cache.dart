import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/car_brand.dart';

/// Persists the comparatively static brand catalogue for fast app launches.
class BrandCache {
  static const cacheTtl = Duration(hours: 24);
  static const _cacheKey = 'catalog.external_brands.v1';

  Future<SharedPreferences>? _preferences;

  Future<List<CarBrand>?> read({bool allowExpired = false}) async {
    final preferences = await _store;
    final serialized = preferences.getString(_cacheKey);
    if (serialized == null) {
      return null;
    }

    try {
      final payload = Map<String, dynamic>.from(jsonDecode(serialized) as Map);
      final storedAt = DateTime.tryParse(payload['storedAt'] as String? ?? '');
      final rawBrands = payload['brands'];
      if (storedAt == null || rawBrands is! List) {
        await preferences.remove(_cacheKey);
        return null;
      }
      if (!allowExpired && DateTime.now().difference(storedAt) > cacheTtl) {
        return null;
      }

      final brands = rawBrands
          .map(
            (brand) =>
                CarBrand.fromJson(Map<String, dynamic>.from(brand as Map)),
          )
          .toList();
      return brands.isEmpty ? null : brands;
    } on Object {
      await preferences.remove(_cacheKey);
      return null;
    }
  }

  Future<void> write(List<CarBrand> brands) async {
    final preferences = await _store;
    await preferences.setString(
      _cacheKey,
      jsonEncode({
        'storedAt': DateTime.now().toIso8601String(),
        'brands': [for (final brand in brands) brand.toJson()],
      }),
    );
  }

  Future<SharedPreferences> get _store {
    return _preferences ??= SharedPreferences.getInstance();
  }
}
