import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/car_brand.dart';

/// Persists the comparatively static brand catalogue for fast app launches.
class BrandCache {
  static const cacheTtl = Duration(hours: 24);
  static const maxStaleAge = Duration(days: 30);
  static const _cacheKey = 'catalog.external_brands.v1';
  static const _converterBrandsCacheKey = 'catalog.converter_brands.v1';

  Future<SharedPreferences>? _preferences;

  Future<List<CarBrand>?> read({bool allowExpired = false}) async {
    return _read(_cacheKey, allowExpired: allowExpired);
  }

  Future<List<CarBrand>?> readConverterBrands({bool allowExpired = false}) {
    return _read(_converterBrandsCacheKey, allowExpired: allowExpired);
  }

  Future<List<CarBrand>?> _read(
    String key, {
    required bool allowExpired,
  }) async {
    final preferences = await _store;
    final serialized = preferences.getString(key);
    if (serialized == null) {
      return null;
    }

    try {
      final payload = Map<String, dynamic>.from(jsonDecode(serialized) as Map);
      final storedAt = DateTime.tryParse(payload['storedAt'] as String? ?? '');
      final rawBrands = payload['brands'];
      if (storedAt == null || rawBrands is! List) {
        await preferences.remove(key);
        return null;
      }
      final age = DateTime.now().difference(storedAt);
      if (age > maxStaleAge) {
        await preferences.remove(key);
        return null;
      }
      if (!allowExpired && age > cacheTtl) {
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
      await preferences.remove(key);
      return null;
    }
  }

  Future<void> write(List<CarBrand> brands) async {
    return _write(_cacheKey, brands);
  }

  Future<void> writeConverterBrands(List<CarBrand> brands) {
    return _write(_converterBrandsCacheKey, brands);
  }

  Future<void> _write(String key, List<CarBrand> brands) async {
    final preferences = await _store;
    await preferences.setString(
      key,
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
