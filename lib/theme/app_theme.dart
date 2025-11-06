import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const Color lightPrimary = Color(0xFF21808D);
  static const Color darkPrimary = Color(0xFF32B8C6);
  static const Color lightBackground = Color(0xFFFCFCF9);
  static const Color darkBackground = Color(0xFF1F2121);
  static const Color lightText = Color(0xFF13343B);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color error = Color(0xFFB3261E);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.lightPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.lightPrimary,
          onPrimary: Colors.white,
          surface: AppColors.lightBackground,
          surfaceContainerHighest: AppColors.lightBackground,
          surfaceTint: Colors.transparent,
          onSurface: AppColors.lightText,
          error: AppColors.error,
        );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(bodyColor: AppColors.lightText, displayColor: AppColors.lightText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: AppColors.lightText,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colorScheme.primary),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surface,
        ),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.darkPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.darkPrimary,
          onPrimary: Colors.black,
          surface: const Color(0xFF242626),
          surfaceContainerHighest: const Color(0xFF2B2D2D),
          surfaceTint: Colors.transparent,
          onSurface: AppColors.darkText,
          error: AppColors.error,
        );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: AppColors.darkText, displayColor: AppColors.darkText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: AppColors.darkText,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colorScheme.primary),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surface,
        ),
        checkColor: WidgetStateProperty.all(AppColors.darkBackground),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    const radius = BorderRadius.all(Radius.circular(12));
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(ColorScheme colorScheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
