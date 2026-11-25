import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF1769E0);
  static const Color darkBlue = Color(0xFF0B4DB0);
  static const Color deepNavy = Color(0xFF0B3C91);
  static const Color tealPrimary = Color(0xFF087F8C);
  static const Color greenPrimary = Color(0xFF176B65);
  static const Color scaffoldBg = Color(0xFFEAF1FA);
  static const Color lightBg = Color(0xFFF5F8FA);
  static const Color softPageBg = Color(0xFFF3F6FB);
  static const Color textDark = Color(0xFF263746);
  static const Color hintGrey = Color(0xFF82909C);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
        ),
      );
}
