import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../core/constants/constants.dart';
import '../models/car_brand.dart';
import 'brand_cache.dart';

class BrandService {
  BrandService({Dio? dio, BrandCache? cache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 25),
              responseType: ResponseType.json,
            ),
          ),
      _cache = cache ?? BrandCache();

  final Dio _dio;
  final BrandCache _cache;

  /// Returns a fresh cached catalogue when possible. If refreshing fails, an
  /// older saved result is returned so users can still browse offline.
  Future<List<CarBrand>> getBrands({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedBrands = await _cache.read();
      if (cachedBrands != null) {
        return _brandsWithLogos(cachedBrands);
      }
    }

    try {
      final response = await _dio.get(ApiConstants.externalBrands);
      final brands = _parseBrands(response.data);
      await _cache.write(brands);
      return brands;
    } on Object {
      final savedBrands = await _cache.read(allowExpired: true);
      if (savedBrands != null) {
        return _brandsWithLogos(savedBrands);
      }
      rethrow;
    }
  }

  List<CarBrand> _parseBrands(dynamic responseData) {
    final rawBrands = responseData is Map ? responseData['data'] : responseData;
    if (rawBrands is! List) {
      throw const FormatException('Invalid brand response format.');
    }

    final brands = <CarBrand>[];
    for (final rawBrand in rawBrands) {
      if (rawBrand is! Map) {
        continue;
      }
      try {
        final brand = CarBrand.fromJson(Map<String, dynamic>.from(rawBrand));
        if (brand.logoUrl != null) {
          brands.add(brand);
        }
      } on FormatException {
        // Ignore a malformed record rather than hiding the entire catalogue.
      }
    }
    if (brands.isEmpty) {
      throw const FormatException('No valid brands were returned.');
    }
    brands.sort((first, second) => first.name.compareTo(second.name));
    return List.unmodifiable(brands);
  }

  List<CarBrand> _brandsWithLogos(List<CarBrand> brands) {
    return List.unmodifiable(brands.where((brand) => brand.logoUrl != null));
  }
}
