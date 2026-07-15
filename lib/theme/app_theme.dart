import 'package:flutter/material.dart';

const _navy = Color(0xFF0D1B2A);
const _navyLight = Color(0xFF1B2A3D);
const _amber = Color(0xFFFFC300);
const _amberDark = Color(0xFFE6A800);
const _surface = Color(0xFF162032);
const _onSurface = Color(0xFFE0E6EF);

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _amber,
        onPrimary: _navy,
        secondary: _amberDark,
        onSecondary: _navy,
        surface: _surface,
        onSurface: _onSurface,
        surfaceContainerHighest: _navyLight,
        error: Color(0xFFCF6679),
      ),
      scaffoldBackgroundColor: _navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: _amber,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _amber,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _navyLight,
        indicatorColor: _amber.withValues(alpha: 0.2),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: _onSurface),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: _onSurface, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _navyLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _amber, width: 1.5),
        ),
        labelStyle: const TextStyle(color: _onSurface),
        hintStyle: TextStyle(color: _onSurface.withValues(alpha: 0.4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _amber,
          foregroundColor: _navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _amber,
          side: const BorderSide(color: _amber),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dividerTheme: DividerThemeData(color: _onSurface.withValues(alpha: 0.1)),
      chipTheme: ChipThemeData(
        backgroundColor: _navyLight,
        labelStyle: const TextStyle(color: _onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
