import 'package:flutter/material.dart';

/// The "海岸暖调" (coastal warm) palette, confirmed with the user against a
/// real-data mockup on 2026-07-24 — see
/// docs/superpowers/specs/2026-07-24-travelspendplus-ui-design.md section 四.
/// Light mode only in this plan (dark mode explicitly deferred).
class AppColors {
  static const coral = Color(0xFFE0693F); // primary / CTA
  static const teal = Color(0xFF2A9D8F); // secondary / "actual" status
  static const gold = Color(0xFFDDA63A); // "planned" status
  static const cream = Color(0xFFFBF6EF); // page background
  static const charcoal = Color(0xFF2B241D); // primary text
  static const mutedText = Color(0xFF8A7F70); // secondary text
  static const border = Color(0xFFEFE4D5);

  /// Fixed order, matches `kExpenseCategoryKeys` — food, transport,
  /// lodging, shopping, entertainment, other.
  static const categoryChartColors = [
    coral,
    teal,
    gold,
    Color(0xFF6D8B96), // dusty blue
    Color(0xFF8AA17E), // sage
    Color(0xFFB08968), // warm taupe
  ];
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.coral,
    brightness: Brightness.light,
    primary: AppColors.coral,
    secondary: AppColors.teal,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.cream,
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.charcoal,
          displayColor: AppColors.charcoal,
        ),
  );
}
