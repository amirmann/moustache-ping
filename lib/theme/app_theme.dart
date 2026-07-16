import 'package:flutter/material.dart';

const _amber = Color(0xFFFFC300);
const _amberDark = Color(0xFFE6A800);
const _navy = Color(0xFF0D1B2A);
const _navyLight = Color(0xFF1B2A3D);
const _darkSurface = Color(0xFF162032);
const _darkOnSurface = Color(0xFFE0E6EF);

const _lightScaffold = Color(0xFFF4F6F9);
const _lightSurface = Color(0xFFFFFFFF);
const _lightOnSurface = Color(0xFF0D1B2A);
const _lightMuted = Color(0xFFE8ECF2);
const _amberDeep = Color(0xFFC99700);

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _amberDeep,
        onPrimary: Colors.white,
        secondary: _amberDark,
        onSecondary: _navy,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        surfaceContainerHighest: _lightMuted,
        error: Color(0xFFB3261E),
      ),
      scaffoldBackgroundColor: _lightScaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightScaffold,
        foregroundColor: _navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: _amberDeep),
        actionsIconTheme: IconThemeData(color: _amberDeep),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _amberDeep.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _amberDeep);
          }
          return const IconThemeData(color: _lightOnSurface);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _amberDeep : _lightOnSurface,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _navy.withValues(alpha: 0.08)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _amberDeep, width: 1.5),
        ),
        labelStyle: const TextStyle(color: _lightOnSurface),
        hintStyle: TextStyle(color: _lightOnSurface.withValues(alpha: 0.4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _amberDeep,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _amberDeep,
          side: const BorderSide(color: _amberDeep),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _amberDeep;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _amberDeep.withValues(alpha: 0.35);
          }
          return Colors.grey.shade300;
        }),
      ),
      dividerTheme: DividerThemeData(color: _navy.withValues(alpha: 0.1)),
      chipTheme: ChipThemeData(
        backgroundColor: _lightMuted,
        labelStyle: const TextStyle(color: _lightOnSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _amber,
        onPrimary: _navy,
        secondary: _amberDark,
        onSecondary: _navy,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
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
          IconThemeData(color: _darkOnSurface),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: _darkOnSurface, fontSize: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
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
        labelStyle: const TextStyle(color: _darkOnSurface),
        hintStyle: TextStyle(color: _darkOnSurface.withValues(alpha: 0.4)),
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _amber;
          return Colors.grey.shade600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _amber.withValues(alpha: 0.35);
          }
          return Colors.grey.shade800;
        }),
      ),
      dividerTheme: DividerThemeData(color: _darkOnSurface.withValues(alpha: 0.1)),
      chipTheme: ChipThemeData(
        backgroundColor: _navyLight,
        labelStyle: const TextStyle(color: _darkOnSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
