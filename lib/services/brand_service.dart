import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../core/constants/constants.dart';
import '../models/car_brand.dart';
import 'authenticated_api_client.dart';
import 'brand_cache.dart';

class BrandService {
  static const _converterBrandsCacheTtl = Duration(minutes: 5);
  static List<CarBrand>? _converterBrandsCache;
  static DateTime? _converterBrandsCachedAt;

  factory BrandService({
    Dio? dio,
    BrandCache? cache,
    AuthenticatedApiClient? apiClient,
  }) {
    final clientDio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 25),
            responseType: ResponseType.json,
          ),
        );
    return BrandService._(
      dio: clientDio,
      apiClient: apiClient ?? AuthenticatedApiClient(dio: clientDio),
      cache: cache ?? BrandCache(),
    );
  }

  BrandService._({
    required this._dio,
    required this._apiClient,
    required this._cache,
  });

  final Dio _dio;
  final AuthenticatedApiClient _apiClient;
  final BrandCache _cache;

  static void invalidateConverterBrandsCache() {
    _converterBrandsCache = null;
    _converterBrandsCachedAt = null;
  }

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

  Future<List<CarBrand>> getConverterBrands({bool forceRefresh = false}) async {
    final cachedBrands = _converterBrandsCache;
    final cachedAt = _converterBrandsCachedAt;
    if (!forceRefresh &&
        cachedBrands != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _converterBrandsCacheTtl) {
      return cachedBrands;
    }

    final response = await _apiClient.get(ApiConstants.brands);
    final brands = _parseBrands(response.data, requireLogo: false);
    _converterBrandsCache = brands;
    _converterBrandsCachedAt = DateTime.now();
    return brands;
  }

  List<CarBrand> _parseBrands(dynamic responseData, {bool requireLogo = true}) {
    final rawBrands = responseData is Map ? responseData['data'] : responseData;
    if (rawBrands is! List) {
      throw const FormatException('Invalid brand response format.');
    }

    final brands = <CarBrand>[];
    CarBrand? unknownBrand;
    for (final rawBrand in rawBrands) {
      if (rawBrand is! Map) {
        continue;
      }
      try {
        final brand = CarBrand.fromJson(Map<String, dynamic>.from(rawBrand));
        if (!requireLogo || brand.logoUrl != null) {
          if (brand.name.toLowerCase() == 'unknown') {
            if (unknownBrand == null ||
                (unknownBrand.id == null && brand.id != null)) {
              unknownBrand = brand;
            }
          } else {
            brands.add(brand);
          }
        }
      } on FormatException {
        // Ignore a malformed record rather than hiding the entire catalogue.
      }
    }
    if (unknownBrand != null) {
      brands.add(unknownBrand);
    }
    if (brands.isEmpty && requireLogo) {
      throw const FormatException('No valid brands were returned.');
    }
    brands.sort((first, second) => first.name.compareTo(second.name));
    return List.unmodifiable(brands);
  }

  List<CarBrand> _brandsWithLogos(List<CarBrand> brands) {
    return List.unmodifiable(brands.where((brand) => brand.logoUrl != null));
  }
}
