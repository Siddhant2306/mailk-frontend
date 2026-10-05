import 'package:dio/dio.dart';

import '../core/constants/constants.dart';
import '../models/metal_price.dart';

class MetalService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<MetalLivePrice> getLivePrice({
    required String symbol,
    String currency = 'INR',
  }) async {
    final response = await _dio.get(
      '/api/v1/metals/quote',
      queryParameters: {
        'symbol': symbol,
        'currency': currency,
      },
    );

    return MetalLivePrice.fromJson(response.data);
  }

  Future<List<MetalPrice>> getHistory({
    required String symbol,
    String currency = 'EUR',
    int days = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/metals/history',
      queryParameters: {
        'symbol': symbol,
        'currency': currency,
        'days': days,
      },
    );

    final dynamic rawData = response.data['data'];

    if (rawData == null) {
      return [];
    }

    if (rawData is! List) {
      throw Exception('Invalid history response format');
    }

    return rawData
        .map(
          (item) => MetalPrice.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}