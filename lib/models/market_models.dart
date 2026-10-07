import 'metal_price.dart';

/// The precious metals supported by the market dashboard.
enum MetalType {
  platinum('PT', 'Pt', 'Platinum'),
  palladium('PD', 'Pd', 'Palladium'),
  rhodium('RH', 'Rh', 'Rhodium');

  const MetalType(this.apiSymbol, this.symbol, this.displayName);

  final String apiSymbol;
  final String symbol;
  final String displayName;
}

/// The supported price units returned by the market API.
enum PriceUnit {
  inr('INR', '₹ / kg'),
  usd('USD', r'$ / oz');

  const PriceUnit(this.apiCurrency, this.chartLabel);

  final String apiCurrency;
  final String chartLabel;
}

/// The selectable history windows on the market dashboard.
enum MarketPeriod {
  tenDays('10 Days', 10),
  oneMonth('1 Month', 30),
  sixMonths('6 Months', 180),
  oneYear('1 Year', 365);

  const MarketPeriod(this.label, this.days);

  final String label;
  final int days;
}

/// A complete dashboard response. Individual values may be missing when a
/// specific API request fails; the rest of the dashboard remains usable.
class MarketSnapshot {
  const MarketSnapshot({
    required this.inrQuotes,
    required this.usdQuotes,
    required this.inrHistory,
    required this.usdHistory,
  });

  factory MarketSnapshot.empty() {
    return const MarketSnapshot(
      inrQuotes: {},
      usdQuotes: {},
      inrHistory: {},
      usdHistory: {},
    );
  }

  final Map<MetalType, MetalLivePrice?> inrQuotes;
  final Map<MetalType, MetalLivePrice?> usdQuotes;
  final Map<MetalType, List<MetalPrice>> inrHistory;
  final Map<MetalType, List<MetalPrice>> usdHistory;

  MetalLivePrice? quoteFor(MetalType metal, PriceUnit unit) {
    return unit == PriceUnit.inr ? inrQuotes[metal] : usdQuotes[metal];
  }

  List<MetalPrice> historyFor(MetalType metal, PriceUnit unit) {
    final history = unit == PriceUnit.inr
        ? inrHistory[metal]
        : usdHistory[metal];
    return history ?? const [];
  }

  /// Produces a new snapshot while retaining data that is still valid on
  /// screen. This lets live prices and chart history arrive independently.
  MarketSnapshot copyWith({
    Map<MetalType, MetalLivePrice?>? inrQuotes,
    Map<MetalType, MetalLivePrice?>? usdQuotes,
    Map<MetalType, List<MetalPrice>>? inrHistory,
    Map<MetalType, List<MetalPrice>>? usdHistory,
  }) {
    return MarketSnapshot(
      inrQuotes: inrQuotes ?? this.inrQuotes,
      usdQuotes: usdQuotes ?? this.usdQuotes,
      inrHistory: inrHistory ?? this.inrHistory,
      usdHistory: usdHistory ?? this.usdHistory,
    );
  }
}
