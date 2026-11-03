import 'package:flutter/material.dart';

import '../../models/market_models.dart';

abstract final class AppColors {
  static const background = Color(0xFF070A0F);
  static const surface = Color(0xFF10161F);
  static const surfaceElevated = Color(0xFF111821);
  static const border = Color(0xFF202A36);
  static const accent = Color(0xFFFFB21A);
  static const accentLight = Color(0xFFFFC34A);
  static const muted = Color(0xFF8993A1);
  static const positive = Color(0xFF48C78E);
  static const negative = Color(0xFFE75A7D);

  static Color metal(MetalType metal) {
    switch (metal) {
      case MetalType.platinum:
        return const Color(0xFFB9D5FF);
      case MetalType.palladium:
        return const Color(0xFFE4B94C);
      case MetalType.rhodium:
        return const Color(0xFFE75A7D);
    }
  }
}
