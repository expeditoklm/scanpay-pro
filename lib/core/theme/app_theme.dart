import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const List<Color> brandCardGradient = [
    Color(0xFF0F172A),
    Color(0xFF1565D8),
    Color(0xFF22C1C3),
  ];

  static const List<Color> brandShellGradient = [
    Color(0xFFF6FAFF),
    Color(0xFFEAF4FF),
    Color(0xFFEFFDFC),
  ];

  static ThemeData light() {
    const primary = Color(0xFF1565D8);
    const secondary = Color(0xFF22C1C3);
    const tertiary = Color(0xFF0F172A);
    const accent = Color(0xFF0B1220);
    const surface = Color(0xFFFFFFFF);
    const background = Color(0xFFF6FAFF);
    const border = Color(0xFFD9E4F2);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: accent,
        titleTextStyle: TextStyle(
          color: accent,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.10),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF64748B),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: accent,
          backgroundColor: Colors.white,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.11)
                : Colors.white;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: const BorderSide(color: border),
        backgroundColor: Colors.white,
        labelStyle: const TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tertiary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF1565D8),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 31,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
          color: accent,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: accent,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
          color: accent,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF334155),
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF475569),
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}
