import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:travelspendplus/ui/theme.dart';

void main() {
  test('buildAppTheme uses the coastal-warm primary color', () {
    final theme = buildAppTheme();
    expect(theme.colorScheme.primary, const Color(0xFFE0693F));
    expect(theme.colorScheme.secondary, const Color(0xFF2A9D8F));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFBF6EF));
  });

  test('AppColors exposes exactly 6 category chart colors', () {
    expect(AppColors.categoryChartColors.length, 6);
  });
}
