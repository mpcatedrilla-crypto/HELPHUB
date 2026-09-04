import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Blue
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color sosRed = Color(0xFFDC2626); // Red for SOS
  static const Color sosRedLight = Color(0xFFEF4444);
  
  // Surface and Background Colors
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color onSurfaceColor = Color(0xFF0F172A);
  static const Color backgroundColor = Color(0xFFF1F5F9);

  // Status Colors
  static const Color statusCritical = Color(0xFFDC2626); // Red
  static const Color statusHigh = Color(0xFFF97316);     // Orange
  static const Color statusMedium = Color(0xFFEAB308);   // Yellow
  static const Color statusLow = Color(0xFF10B981);      // Green
  static const Color statusResolved = Color(0xFF6B7280); // Grey

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: primaryBlueLight,
        error: sosRed,
        surface: surfaceColor,
        background: backgroundColor,
        onSurface: onSurfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        labelStyle: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryBlue.withOpacity(0.2)),
        ),
      ),
    );
  }
}
