class MetalPrice {
  final int timestamp;
  final double price;

  MetalPrice({required this.timestamp, required this.price});

  factory MetalPrice.fromJson(Map<String, dynamic> json) {
    final timestamp = _numberFromJson(json['timestamp'])?.toInt();
    final price = _numberFromJson(json['price']);

    if (timestamp == null || price == null) {
      throw const FormatException(
        'A price history entry is missing a timestamp or price.',
      );
    }

    return MetalPrice(timestamp: timestamp, price: price);
  }

  Map<String, dynamic> toJson() => {'timestamp': timestamp, 'price': price};

  // Metal Sentinel gives the price per troy ounce.
  static const double gramsPerTroyOunce = 31.1034768;

  // Convert OZT price -> price per kilogram.
  double get pricePerKilo {
    return (price / gramsPerTroyOunce) * 1000;
  }

  DateTime get recordedAt {
    final milliseconds = timestamp.abs() >= 100000000000
        ? timestamp
        : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
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

  factory MetalLivePrice.fromJson(
    Map<String, dynamic> json, {
    required String fallbackSymbol,
    required String fallbackCurrency,
  }) {
    final symbol = json['symbol'] as String?;
    final currency = json['currency'] as String?;
    final price = _numberFromJson(json['price']);

    if (price == null) {
      throw const FormatException('A live metal quote is missing its price.');
    }

    return MetalLivePrice(
      symbol: symbol ?? fallbackSymbol,
      currency: currency ?? fallbackCurrency,
      price: price,
      change: _numberFromJson(json['change']),
      changePercentage: _numberFromJson(json['changePercentage']),
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'currency': currency,
    'price': price,
    'change': change,
    'changePercentage': changePercentage,
  };

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

double? _numberFromJson(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
