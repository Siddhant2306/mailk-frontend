import 'package:dio/dio.dart';

import '../core/constants/constants.dart';
import '../models/converter_record.dart';
import '../models/converter_draft.dart';
import 'authenticated_api_client.dart';
import 'brand_service.dart';
import 'converter_catalog_cache.dart';
import 'persistent_converter_catalog_cache.dart';

class ConverterService {
  ConverterService({
    AuthenticatedApiClient? apiClient,
    ConverterCatalogCache? catalogCache,
    PersistentConverterCatalogCache? persistentCatalogCache,
  }) : _apiClient = apiClient ?? AuthenticatedApiClient(),
       _catalogCache = catalogCache ?? ConverterCatalogCache.shared,
       _persistentCatalogCache =
           persistentCatalogCache ?? PersistentConverterCatalogCache.shared;

  final AuthenticatedApiClient _apiClient;
  final ConverterCatalogCache _catalogCache;
  final PersistentConverterCatalogCache _persistentCatalogCache;

  /// Reads the saved first catalogue page without making a network request.
  ///
  /// This is intentionally limited to the first page: it gives a cold launch
  /// useful content immediately without persisting an unbounded result set.
  Future<CachedConverterCatalogPage?> getCachedFirstPage({
    int pageSize = 20,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
  }) {
    return _persistentCatalogCache.read(
      search: search?.trim() ?? '',
      brandId: brandId,
      pageSize: pageSize,
      brandsById: brandsById,
    );
  }

  Future<String> uploadConverterImage({
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.converterImageUpload,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    final data = response.data;
    final imageUrl = data is Map ? data['image_url'] : null;
    if (imageUrl is! String || imageUrl.trim().isEmpty) {
      throw const FormatException('Invalid converter image upload response.');
    }
    return imageUrl.trim();
  }

  Future<int> createConverter(ConverterDraft draft) async {
    _validateImageCount(draft);
    final response = await _apiClient.post(
      ApiConstants.converters,
      data: draft.toJson(),
    );
    final data = response.data;
    if (data is! Map || data['converter_id'] is! int) {
      throw const FormatException('Invalid converter creation response.');
    }
    _catalogCache.invalidateAll();
    await _persistentCatalogCache.invalidateAll();
    BrandService.invalidateConverterBrandsCache();
    return data['converter_id'] as int;
  }

  Future<void> updateConverter(int converterId, ConverterDraft draft) async {
    _validateImageCount(draft);
    await _apiClient.patch(
      ApiConstants.adminConverterDetail(converterId),
      data: draft.toJson(includeNulls: true),
    );
    _catalogCache.invalidateAll();
    await _persistentCatalogCache.invalidateAll();
    BrandService.invalidateConverterBrandsCache();
  }

  Future<void> deleteConverter(int converterId) async {
    await _apiClient.delete(ApiConstants.adminConverterDetail(converterId));
    _catalogCache.invalidateAll();
    await _persistentCatalogCache.invalidateAll();
    BrandService.invalidateConverterBrandsCache();
  }

  Future<ConverterCatalogPage> getConverters({
    int pageSize = 20,
    String? cursor,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
    bool forceRefresh = false,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and 100.',
      );
    }
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      if (normalizedSearch.length < 3) {
        throw ArgumentError.value(
          search,
          'search',
          'Enter at least 3 characters to search.',
        );
      }
      if (normalizedSearch.length > 100) {
        throw ArgumentError.value(
          search,
          'search',
          'Search terms can be at most 100 characters.',
        );
      }
    }
    final cacheSearch = normalizedSearch ?? '';
    if (forceRefresh && cursor == null) {
      _catalogCache.invalidate(
        search: cacheSearch,
        brandId: brandId,
        pageSize: pageSize,
      );
      await _persistentCatalogCache.invalidate(
        search: cacheSearch,
        brandId: brandId,
        pageSize: pageSize,
      );
    }
    if (!forceRefresh) {
      final cachedPage = _catalogCache.read(
        search: cacheSearch,
        brandId: brandId,
        pageSize: pageSize,
        cursor: cursor,
      );
      if (cachedPage != null) {
        return _withBrandNames(cachedPage, brandsById);
      }
    }

    final cacheRevision = _catalogCache.revision(
      search: cacheSearch,
      brandId: brandId,
      pageSize: pageSize,
    );
    final query = <String, dynamic>{'page_size': pageSize};
    if (cursor != null) {
      query['cursor'] = cursor;
    }
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    }
    if (brandId != null) {
      query['brand_id'] = brandId;
    }

    final response = await _apiClient.get(
      ApiConstants.converterCatalog,
      queryParameters: query,
    );
    final result = ConverterCatalogPage.fromJson(
      response.data,
      brandsById: brandsById,
    );
    _catalogCache.write(
      search: cacheSearch,
      brandId: brandId,
      pageSize: pageSize,
      cursor: cursor,
      revision: cacheRevision,
      page: result,
    );
    if (cursor == null) {
      await _persistentCatalogCache.write(
        search: cacheSearch,
        brandId: brandId,
        pageSize: pageSize,
        page: result,
      );
    }
    return result;
  }

  ConverterCatalogPage _withBrandNames(
    ConverterCatalogPage page,
    Map<int, String> brandsById,
  ) {
    if (brandsById.isEmpty) {
      return page;
    }
    return ConverterCatalogPage(
      converters: List.unmodifiable(
        page.converters.map((converter) {
          if (converter.brandName != null || converter.brandId == null) {
            return converter;
          }
          final brandName = brandsById[converter.brandId];
          if (brandName == null) {
            return converter;
          }
          return ConverterRecord(
            id: converter.id,
            codeReference: converter.codeReference,
            converterCode: converter.converterCode,
            brandId: converter.brandId,
            brandName: brandName,
            model: converter.model,
            country: converter.country,
            converterType: converter.converterType,
            category: converter.category,
            localLingo: converter.localLingo,
            monolithWeightGrams: converter.monolithWeightGrams,
            markings: converter.markings,
            images: converter.images,
            ptPpm: converter.ptPpm,
            pdPpm: converter.pdPpm,
            rhPpm: converter.rhPpm,
            remarks: converter.remarks,
            notes: converter.notes,
          );
        }),
      ),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      pageSize: page.pageSize,
    );
  }

  Future<ConverterRecord> getConverter(
    int converterId, {
    Map<int, String> brandsById = const {},
  }) async {
    final response = await _apiClient.get(
      ApiConstants.converterDetail(converterId),
    );
    final data = response.data;
    final rawConverter = data is Map
        ? data['converter'] ?? data['data'] ?? data
        : null;
    if (rawConverter is! Map) {
      throw const FormatException('Invalid converter detail response.');
    }
    return ConverterRecord.fromJson(
      Map<String, dynamic>.from(rawConverter),
      brandsById: brandsById,
    );
  }

  String messageFor(Object error) {
    if (error is ConverterImageLimitException) {
      return 'A converter can have at most 4 images.';
    }
    if (error is FormatException) {
      return 'The image service returned an invalid response. Please retry.';
    }
    if (error is AuthenticationRequiredException) {
      return 'Please sign in again before saving or modifying a converter.';
    }
    if (error is DioException) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return 'Admin permission is required for converter changes.';
      }
      if (error.response?.statusCode == 422) {
        return 'Please correct the converter fields and try again.';
      }
      return 'Could not upload the image or save the converter. Check your connection and retry.';
    }
    return 'Could not upload the image or save the converter. Please try again.';
  }

  void _validateImageCount(ConverterDraft draft) {
    if (draft.images.length > 4) {
      throw const ConverterImageLimitException();
    }
  }
}

class ConverterImageLimitException implements Exception {
  const ConverterImageLimitException();
}
