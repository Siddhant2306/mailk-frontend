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

  Future<SharedPreferences>? _preferences;

  Future<Map<MetalType, MetalLivePrice?>?> readQuotes(PriceUnit unit) async {
    final value = await _read(_quoteKey(unit), quoteTtl);
    if (value == null) {
      return null;
    }

    try {
      final quotes = <MetalType, MetalLivePrice?>{};
      for (final metal in MetalType.values) {
        final rawQuote = value[metal.name];
        quotes[metal] = rawQuote is Map
            ? MetalLivePrice.fromJson(
                Map<String, dynamic>.from(rawQuote),
                fallbackSymbol: metal.apiSymbol,
                fallbackCurrency: unit.apiCurrency,
              )
            : null;
      }
      return quotes;
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
    final key = _historyKey(unit, days);
    final value = await _read(key, historyTtl);
    if (value == null) {
      return null;
    }

    try {
      return {
        for (final metal in MetalType.values)
          metal: _pricesFrom(value[metal.name]),
      };
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
    final value = await _read(_historyKey(unit, days), historyTtl);
    final rawHistory = value?[metal.name];
    if (rawHistory == null) {
      return null;
    }

    try {
      return _pricesFrom(rawHistory);
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
    final existing = await _read(key, historyTtl) ?? <String, dynamic>{};
    await _write(key, {
      ...existing,
      metal.name: [for (final price in history) price.toJson()],
    });
  }

  Future<Map<String, dynamic>?> _read(String key, Duration ttl) async {
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
      if (DateTime.now().difference(storedAt) > ttl) {
        await preferences.remove(key);
        return null;
      }
      return Map<String, dynamic>.from(data);
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
