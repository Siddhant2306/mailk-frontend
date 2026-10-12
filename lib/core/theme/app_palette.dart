import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.input,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color input;
  final Color shadow;

  static const dark = AppPalette(
    background: Color(0xFF070A0F),
    surface: Color(0xFF10161F),
    surfaceElevated: Color(0xFF141C27),
    surfaceSubtle: Color(0xFF1B2530),
    border: Color(0xFF263241),
    textPrimary: Color(0xFFF1F4F8),
    textSecondary: Color(0xFFD2D9E2),
    textMuted: Color(0xFF8993A1),
    accent: Color(0xFFFFB21A),
    accentSoft: Color(0xFF2B210C),
    input: Color(0xFF10111B),
    shadow: Color(0x18000000),
  );

  static const light = AppPalette(
    background: Color(0xFFF3F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF2F4F7),
    border: Color(0xFFE1E5EB),
    textPrimary: Color(0xFF17212B),
    textSecondary: Color(0xFF344054),
    textMuted: Color(0xFF667085),
    accent: Color(0xFF9A5B00),
    accentSoft: Color(0xFFFFF3D6),
    input: Color(0xFFFFFFFF),
    shadow: Color(0x100F172A),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? input,
    Color? shadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      input: input ?? this.input,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      input: Color.lerp(input, other.input, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
