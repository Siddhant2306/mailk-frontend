import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/market_models.dart';
import '../models/metal_price.dart';

/// Small persistent cache for market data.
///
/// Quotes are reused for ten minutes and history for thirty minutes. The
/// cache is intentionally independent per unit and time window so a chart
/// switch never replaces data that is still useful elsewhere in the app.
class MarketCache {
  static const quoteTtl = Duration(minutes: 10);
  static const historyTtl = Duration(minutes: 30);
  static const maxStaleAge = Duration(days: 7);

  Future<SharedPreferences>? _preferences;

  Future<Map<MetalType, MetalLivePrice?>?> readQuotes(PriceUnit unit) async {
    final cached = await readCachedQuotes(unit, allowStale: false);
    return cached?.value;
  }

  /// Reads saved quotes for immediate display, including stale values.
  Future<CachedMarketValue<Map<MetalType, MetalLivePrice?>>?> readCachedQuotes(
    PriceUnit unit, {
    bool allowStale = true,
  }) async {
    final cached = await _read(
      _quoteKey(unit),
      quoteTtl,
      allowStale: allowStale,
    );
    if (cached == null) {
      return null;
    }

    try {
      final quotes = <MetalType, MetalLivePrice?>{};
      for (final metal in MetalType.values) {
        final rawQuote = cached.data[metal.name];
        quotes[metal] = rawQuote is Map
            ? MetalLivePrice.fromJson(
                Map<String, dynamic>.from(rawQuote),
                fallbackSymbol: metal.apiSymbol,
                fallbackCurrency: unit.apiCurrency,
              )
            : null;
      }
      return CachedMarketValue(
        value: Map.unmodifiable(quotes),
        cachedAt: cached.cachedAt,
        isFresh: cached.isFresh,
      );
    } on Object {
      await _remove(_quoteKey(unit));
      return null;
    }
  }

  Future<void> writeQuotes(
    PriceUnit unit,
    Map<MetalType, MetalLivePrice?> quotes,
  ) {
    return _write(_quoteKey(unit), {
      for (final metal in MetalType.values) metal.name: quotes[metal]?.toJson(),
    });
  }

  Future<Map<MetalType, List<MetalPrice>>?> readHistory({
    required PriceUnit unit,
    required int days,
  }) async {
    final cached = await readCachedHistory(
      unit: unit,
      days: days,
      allowStale: false,
    );
    return cached?.value;
  }

  Future<CachedMarketValue<Map<MetalType, List<MetalPrice>>>?>
  readCachedHistory({
    required PriceUnit unit,
    required int days,
    bool allowStale = true,
  }) async {
    final key = _historyKey(unit, days);
    final cached = await _read(key, historyTtl, allowStale: allowStale);
    if (cached == null) {
      return null;
    }

    try {
      final history = {
        for (final metal in MetalType.values)
          metal: _pricesFrom(cached.data[metal.name]),
      };
      return CachedMarketValue(
        value: Map.unmodifiable(history),
        cachedAt: cached.cachedAt,
        isFresh: cached.isFresh,
      );
    } on Object {
      await _remove(key);
      return null;
    }
  }

  Future<void> writeHistory({
    required PriceUnit unit,
    required int days,
    required Map<MetalType, List<MetalPrice>> history,
  }) {
    return _write(_historyKey(unit, days), {
      for (final metal in MetalType.values)
        metal.name: [
          for (final price in history[metal] ?? const []) price.toJson(),
        ],
    });
  }

  Future<List<MetalPrice>?> readHistoryForMetal({
    required MetalType metal,
    required PriceUnit unit,
    required int days,
  }) async {
    final cached = await readCachedHistoryForMetal(
      metal: metal,
      unit: unit,
      days: days,
      allowStale: false,
    );
    return cached?.value;
  }

  Future<CachedMarketValue<List<MetalPrice>>?> readCachedHistoryForMetal({
    required MetalType metal,
    required PriceUnit unit,
    required int days,
    bool allowStale = true,
  }) async {
    final cached = await _read(
      _historyKey(unit, days),
      historyTtl,
      allowStale: allowStale,
    );
    final rawHistory = cached?.data[metal.name];
    if (rawHistory == null) {
      return null;
    }

    try {
      return CachedMarketValue(
        value: List.unmodifiable(_pricesFrom(rawHistory)),
        cachedAt: cached!.cachedAt,
        isFresh: cached.isFresh,
      );
    } on Object {
      return null;
    }
  }

  Future<void> writeHistoryForMetal({
    required MetalType metal,
    required PriceUnit unit,
    required int days,
    required List<MetalPrice> history,
  }) async {
    final key = _historyKey(unit, days);
    final existing =
        (await _read(key, historyTtl, allowStale: true))?.data ??
        <String, dynamic>{};
    await _write(key, {
      ...existing,
      metal.name: [for (final price in history) price.toJson()],
    });
  }

  Future<_MarketCacheEntry?> _read(
    String key,
    Duration ttl, {
    required bool allowStale,
  }) async {
    final preferences = await _store;
    final serialized = preferences.getString(key);
    if (serialized == null) {
      return null;
    }

    try {
      final entry = Map<String, dynamic>.from(jsonDecode(serialized) as Map);
      final storedAt = DateTime.tryParse(entry['storedAt'] as String? ?? '');
      final data = entry['data'];
      if (storedAt == null || data is! Map) {
        await preferences.remove(key);
        return null;
      }
      final age = DateTime.now().difference(storedAt);
      if (age > maxStaleAge) {
        await preferences.remove(key);
        return null;
      }
      final isFresh = age <= ttl;
      if (!isFresh && !allowStale) {
        return null;
      }
      return _MarketCacheEntry(
        data: Map<String, dynamic>.from(data),
        cachedAt: storedAt,
        isFresh: isFresh,
      );
    } on Object {
      await preferences.remove(key);
      return null;
    }
  }

  Future<void> _write(String key, Map<String, dynamic> data) async {
    final preferences = await _store;
    await preferences.setString(
      key,
      jsonEncode({'storedAt': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  Future<void> _remove(String key) async {
    final preferences = await _store;
    await preferences.remove(key);
  }

  Future<SharedPreferences> get _store {
    return _preferences ??= SharedPreferences.getInstance();
  }

  List<MetalPrice> _pricesFrom(dynamic value) {
    if (value is! List) {
      throw const FormatException('Invalid cached history.');
    }
    return value
        .map(
          (entry) =>
              MetalPrice.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  String _quoteKey(PriceUnit unit) => 'market.quotes.${unit.apiCurrency}';

  String _historyKey(PriceUnit unit, int days) {
    return 'market.history.${unit.apiCurrency}.$days';
  }
}

class CachedMarketValue<T> {
  const CachedMarketValue({
    required this.value,
    required this.cachedAt,
    required this.isFresh,
  });

  final T value;
  final DateTime cachedAt;
  final bool isFresh;
}

class _MarketCacheEntry {
  const _MarketCacheEntry({
    required this.data,
    required this.cachedAt,
    required this.isFresh,
  });

  final Map<String, dynamic> data;
  final DateTime cachedAt;
  final bool isFresh;
}
