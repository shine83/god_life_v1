// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static TextTheme _buildTextTheme(Brightness b, ColorScheme scheme) {
    final isDark = b == Brightness.dark;
    final base = (b == Brightness.dark
            ? Typography.whiteMountainView
            : Typography.blackMountainView)
        .copyWith(
      displayLarge: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
      displayMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      displaySmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      headlineLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      headlineMedium:
          const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.1,
        fontWeight: isDark ? FontWeight.w600 : FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.5,
        letterSpacing: 0.1,
        fontWeight: isDark ? FontWeight.w600 : FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        letterSpacing: 0.1,
        fontWeight: isDark ? FontWeight.w600 : FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
      ),
    );

    final color = isDark
        ? scheme.onSurface.withOpacity(0.97)
        : scheme.onSurface.withOpacity(0.92);

    return base.apply(
      bodyColor: color,
      displayColor: color,
      decorationColor: color,
    );
  }

  static final ThemeData light = (() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C4CE8),
      brightness: Brightness.light,
    );
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      textTheme: _buildTextTheme(Brightness.light, scheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(space: 0, thickness: 0.7),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  })();

  static final ThemeData dark = (() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF007F5F),
      brightness: Brightness.dark,
    );
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0E0E0E),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0E0E0E),
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        centerTitle: true,
        titleTextStyle: _buildTextTheme(Brightness.dark, scheme)
            .titleLarge
            ?.copyWith(color: scheme.onSurface),
      ),
      textTheme: _buildTextTheme(Brightness.dark, scheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface.withOpacity(0.95)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.65)),
        labelStyle: TextStyle(
          color: scheme.onSurface.withOpacity(0.90),
          fontWeight: FontWeight.w600,
        ),
      ),

      // ✨ --- CardTheme -> CardThemeData 로 수정 ---
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(
            color: scheme.primary.withOpacity(0.7),
            width: 1.5,
          ),
        ),
        elevation: 0.5,
        surfaceTintColor: const Color(0xFF121212),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(
        space: 0,
        thickness: 0.8,
        color: scheme.onSurface.withOpacity(0.14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  })();
}
