import 'package:flutter/material.dart';

/// Spacing constants based on 8px grid system.
class Insets {
  const Insets._();

  static const double base = 8;
  static const double xs = base;
  static const double sm = base * 2;
  static const double md = base * 3;
  static const double lg = base * 4;
  static const double xl = base * 6;
  static const double xxl = base * 8;
}

/// Corner radius presets.
class CornerRadius {
  const CornerRadius._();

  static const BorderRadius button = BorderRadius.all(Radius.circular(8));
  static const BorderRadius card = BorderRadius.all(Radius.circular(12));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(20),
  );
}

/// Responsive breakpoints.
class Breakpoints {
  const Breakpoints._();

  /// Small phone (< 360dp)
  static const double xs = 360;

  /// Standard phone (360-600dp)
  static const double sm = 600;

  /// Tablet portrait (600-900dp)
  static const double md = 900;

  /// Tablet landscape / small desktop (900-1200dp)
  static const double lg = 1200;
}

/// Helper class for responsive layouts.
class ResponsiveHelper {
  const ResponsiveHelper._();

  /// Check if screen width is mobile-sized (< 600dp).
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < Breakpoints.sm;
  }

  /// Check if screen width is tablet-sized (600-900dp).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.sm && width < Breakpoints.md;
  }

  /// Check if screen width is desktop-sized (>= 900dp).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= Breakpoints.md;
  }

  /// Get responsive padding based on screen size.
  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(Insets.lg);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.lg,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: Insets.xxl,
      vertical: Insets.lg,
    );
  }

  /// Get content max width for centering on large screens.
  static double getContentMaxWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 600;
    return 800;
  }
}
