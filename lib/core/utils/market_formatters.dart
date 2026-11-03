import '../../models/market_models.dart';
import '../../models/metal_price.dart';

abstract final class MarketFormatters {
  static String cardInrPrice(MetalLivePrice? quote) {
    if (!_hasValidPrice(quote)) {
      return 'Unavailable';
    }

    return '₹${quote!.priceInLakhsPerKilo.toStringAsFixed(2)} L';
  }

  static String cardUsdPrice(MetalLivePrice? quote) {
    if (!_hasValidPrice(quote)) {
      return 'USD unavailable';
    }

    return r'$'
        '${quote!.price.toStringAsFixed(0)} / oz';
  }

  static String chartValue(double value, PriceUnit unit) {
    if (!value.isFinite) {
      return '--';
    }

    if (unit == PriceUnit.inr) {
      final lakhs = value / 100000;
      return '₹${lakhs.toStringAsFixed(lakhs.abs() >= 10 ? 1 : 2)}L';
    }

    if (value.abs() >= 1000) {
      return r'$'
          '${(value / 1000).toStringAsFixed(1)}k';
    }
    return r'$'
        '${value.toStringAsFixed(0)}';
  }

  static String date(MetalPrice? price) {
    if (price == null) {
      return '--';
    }

    final date = price.recordedAt;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  static bool _hasValidPrice(MetalLivePrice? quote) {
    return quote != null && quote.price.isFinite && quote.price >= 0;
  }
}
