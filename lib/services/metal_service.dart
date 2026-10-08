import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/market_models.dart';
import '../models/metal_price.dart';
import 'market_cache.dart';

class MetalService {
  MetalService({Dio? dio, MarketCache? cache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              // The upstream metals provider can take longer than ten
              // seconds, especially for the first request after it is idle.
              receiveTimeout: const Duration(seconds: 35),
              responseType: ResponseType.json,
            ),
          ),
      _cache = cache ?? MarketCache();

  final Dio _dio;
  final MarketCache _cache;

  Future<MetalLivePrice> getLivePrice({
    required String symbol,
    String currency = 'INR',
  }) async {
    final response = await _dio.get(
      '/api/v1/metals/quote',
      queryParameters: {'symbol': symbol, 'currency': currency},
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid live-price response format.');
    }

    return MetalLivePrice.fromJson(
      Map<String, dynamic>.from(data),
      fallbackSymbol: symbol,
      fallbackCurrency: currency,
    );
  }

  Future<List<MetalPrice>> getHistory({
    required String symbol,
    required String currency,
    int days = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/metals/history',
      queryParameters: {'symbol': symbol, 'currency': currency, 'days': days},
    );

    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('Invalid history response format.');
    }

    final rawData = responseData['data'];

    if (rawData == null) {
      return [];
    }

    if (rawData is! List) {
      throw Exception('Invalid history response format');
    }

    final history = rawData
        .map(
          (item) => MetalPrice.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    history.sort(
      (first, second) => first.timestamp.compareTo(second.timestamp),
    );
    return history;
  }

  /// Returns saved quotes when they are still fresh, otherwise fetches and
  /// persists a new set. A pull-to-refresh can explicitly bypass the cache.
  ///
  /// Keep this separate from history so a slow chart response does not hide
  /// otherwise valid live prices.
  Future<Map<MetalType, MetalLivePrice?>> getLiveQuotes({
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedQuotes = await _cache.readQuotes(unit);
      if (cachedQuotes != null) {
        return cachedQuotes;
      }
    }

    final quotes = await _loadForAllMetals(
      (metal) =>
          getLivePrice(symbol: metal.apiSymbol, currency: unit.apiCurrency),
    );
    if (quotes.values.any((quote) => quote != null)) {
      await _cache.writeQuotes(unit, quotes);
    }
    return quotes;
  }

  /// Returns saved chart history when available before querying the API.
  Future<Map<MetalType, List<MetalPrice>>> getHistoryForAllMetals({
    required int days,
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedHistory = await _cache.readHistory(unit: unit, days: days);
      if (cachedHistory != null) {
        return cachedHistory;
      }
    }

    final history = await _loadForAllMetals(
      (metal) => getHistory(
        symbol: metal.apiSymbol,
        currency: unit.apiCurrency,
        days: days,
      ),
    );

    final resolvedHistory = _historyOrEmpty(history);
    if (resolvedHistory.values.any((prices) => prices.isNotEmpty)) {
      await _cache.writeHistory(
        unit: unit,
        days: days,
        history: resolvedHistory,
      );
    }
    return resolvedHistory;
  }

  /// Gets only the history visible in the chart. Other metals are fetched on
  /// demand when the user selects them, avoiding unnecessary startup calls.
  Future<List<MetalPrice>> getHistoryForMetal({
    required MetalType metal,
    required int days,
    required PriceUnit unit,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedHistory = await _cache.readHistoryForMetal(
        metal: metal,
        unit: unit,
        days: days,
      );
      if (cachedHistory != null) {
        return cachedHistory;
      }
    }

    final history = await _tryRequest(
      () => getHistory(
        symbol: metal.apiSymbol,
        currency: unit.apiCurrency,
        days: days,
      ),
    );
    final resolvedHistory = history ?? const <MetalPrice>[];
    if (resolvedHistory.isNotEmpty) {
      await _cache.writeHistoryForMetal(
        metal: metal,
        unit: unit,
        days: days,
        history: resolvedHistory,
      );
    }
    return resolvedHistory;
  }

  /// Loads all dashboard data for callers that need a single snapshot.
  /// The home screen uses the granular methods above so prices can appear
  /// before history has finished loading.
  Future<MarketSnapshot> getMarketSnapshot({
    required int days,
    PriceUnit historyUnit = PriceUnit.inr,
  }) async {
    final inrQuotesRequest = getLiveQuotes(unit: PriceUnit.inr);
    final usdQuotesRequest = getLiveQuotes(unit: PriceUnit.usd);
    final historyRequest = getHistoryForAllMetals(
      days: days,
      unit: historyUnit,
    );
    final inrQuotes = await inrQuotesRequest;
    final usdQuotes = await usdQuotesRequest;
    final history = await historyRequest;

    return MarketSnapshot(
      inrQuotes: inrQuotes,
      usdQuotes: usdQuotes,
      inrHistory: historyUnit == PriceUnit.inr ? history : const {},
      usdHistory: historyUnit == PriceUnit.usd ? history : const {},
    );
  }

  Future<Map<MetalType, T?>> _loadForAllMetals<T>(
    Future<T> Function(MetalType metal) request,
  ) async {
    final entries = await Future.wait(
      MetalType.values.map(
        (metal) async =>
            MapEntry(metal, await _tryRequest(() => request(metal))),
      ),
    );

    return Map.unmodifiable(Map.fromEntries(entries));
  }

  Map<MetalType, List<MetalPrice>> _historyOrEmpty(
    Map<MetalType, List<MetalPrice>?> history,
  ) {
    return Map.unmodifiable({
      for (final metal in MetalType.values) metal: history[metal] ?? const [],
    });
  }

  Future<T?> _tryRequest<T>(Future<T> Function() request) async {
    const attempts = 2;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await request();
      } catch (error, stackTrace) {
        developer.log(
          'Market API request failed (attempt $attempt of $attempts).',
          name: 'MetalService',
          error: error,
          stackTrace: stackTrace,
        );
        debugPrint('Market API request failed: $error');
        if (attempt == attempts) {
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }

    return null;
  }
}
