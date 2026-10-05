class MetalPrice {
  final int timestamp;
  final double price;

  MetalPrice({
    required this.timestamp,
    required this.price,
  });

  factory MetalPrice.fromJson(Map<String, dynamic> json) {
    return MetalPrice(
      timestamp: json['timestamp'] as int,
      price: (json['price'] as num).toDouble(),
    );
  }

  // Metal Sentinel gives the price per troy ounce.
  static const double gramsPerTroyOunce = 31.1034768;

  // Convert OZT price -> price per kilogram.
  double get pricePerKilo {
    return (price / gramsPerTroyOunce) * 1000;
  }
}


class MetalLivePrice {
  final String symbol;
  final String currency;

  // Raw API price.
  // INR -> ₹/OZT
  // USD -> $/OZT
  final double price;

  final double? change;
  final double? changePercentage;

  MetalLivePrice({
    required this.symbol,
    required this.currency,
    required this.price,
    this.change,
    this.changePercentage,
  });

  factory MetalLivePrice.fromJson(Map<String, dynamic> json) {
    return MetalLivePrice(
      symbol: json['symbol'],
      currency: json['currency'],
      price: (json['price'] as num).toDouble(),
      change: json['change'] != null
          ? (json['change'] as num).toDouble()
          : null,
      changePercentage: json['changePercentage'] != null
          ? (json['changePercentage'] as num).toDouble()
          : null,
    );
  }

  static const double gramsPerTroyOunce = 31.1034768;

  // Raw API price converted from OZT -> gram.
  double get pricePerGram {
    return price / gramsPerTroyOunce;
  }

  // Raw API price converted from OZT -> kilogram.
  double get pricePerKilo {
    return pricePerGram * 1000;
  }

  // ₹/kg -> lakh/kg.
  double get priceInLakhsPerKilo {
    return pricePerKilo / 100000;
  }
}