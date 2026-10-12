import 'package:dio/dio.dart';

import '../core/constants/constants.dart';
import '../models/converter_record.dart';
import '../models/converter_draft.dart';
import 'authenticated_api_client.dart';
import 'converter_catalog_cache.dart';

class ConverterService {
  ConverterService({
    AuthenticatedApiClient? apiClient,
    ConverterCatalogCache? catalogCache,
  }) : _apiClient = apiClient ?? AuthenticatedApiClient(),
       _catalogCache = catalogCache ?? ConverterCatalogCache.shared;

  final AuthenticatedApiClient _apiClient;
  final ConverterCatalogCache _catalogCache;

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
    final response = await _apiClient.post(
      ApiConstants.converters,
      data: draft.toJson(),
    );
    final data = response.data;
    if (data is! Map || data['converter_id'] is! int) {
      throw const FormatException('Invalid converter creation response.');
    }
    return data['converter_id'] as int;
  }

  Future<ConverterCatalogPage> getConverters({
    required int page,
    int pageSize = 20,
    String? search,
    int? brandId,
    Map<int, String> brandsById = const {},
    bool forceRefresh = false,
  }) async {
    final normalizedSearch = search?.trim();
    final cacheSearch = normalizedSearch ?? '';
    if (forceRefresh && page == 1) {
      _catalogCache.invalidate(
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
        page: page,
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
    final query = <String, dynamic>{'page': page, 'page_size': pageSize};
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
      requestedPage: page,
      requestedPageSize: pageSize,
      brandsById: brandsById,
    );
    _catalogCache.write(
      search: cacheSearch,
      brandId: brandId,
      pageSize: pageSize,
      revision: cacheRevision,
      page: result,
    );
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
      total: page.total,
      page: page.page,
      pageSize: page.pageSize,
      totalPages: page.totalPages,
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
    if (error is FormatException) {
      return 'The image service returned an invalid response. Please retry.';
    }
    if (error is AuthenticationRequiredException) {
      return 'Please sign in again before saving a converter.';
    }
    if (error is DioException) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        return 'Admin permission is required to add converters.';
      }
      if (error.response?.statusCode == 422) {
        return 'Please correct the converter fields and try again.';
      }
      return 'Could not upload the image or save the converter. Check your connection and retry.';
    }
    return 'Could not upload the image or save the converter. Please try again.';
  }
}
