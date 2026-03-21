import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';

/// Provider for app theme (Dark Mode - like Stitch design)
final themeProvider = Provider<ThemeData>((ref) {
  final isDark = ref.watch(isDarkModeProvider);
  
  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    
    // Colors
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      onSurface: isDark ? Colors.white : AppColors.textPrimary,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
    
    // App Bar
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
    ),
    
    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Decoration Theme (like Stitch inputs)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
        fontFamily: 'Inter',
      ),
      labelStyle: TextStyle(
        color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
        fontFamily: 'Inter',
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    
    // Divider
    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.borderDark : AppColors.borderLight,
      thickness: 1,
    ),
    
    // Font
    fontFamily: 'Inter',
    
    // Text Theme
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontFamily: 'Inter',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
        fontFamily: 'Inter',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
        fontFamily: 'Inter',
      ),
    ),
  );
});

/// State provider for dark mode toggle (default: true - like Stitch design)
final isDarkModeProvider = StateProvider<bool>((ref) => true);

