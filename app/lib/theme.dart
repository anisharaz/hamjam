import 'package:flutter/material.dart';

class Palette {
  static const bgTop = Color(0xFF1A0B3B);
  static const bgBottom = Color(0xFF07040F);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFF472B6);
  static const live = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);

  static const brand = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.violet,
    brightness: Brightness.dark,
  ).copyWith(surface: Palette.bgBottom, primary: Palette.violet, secondary: Palette.pink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: Typography.whiteMountainView.apply(bodyColor: Colors.white, displayColor: Colors.white),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A1B52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Frosted, softly bordered surface used for cards across the app.
BoxDecoration glass({double radius = 24, double fill = 0.07}) => BoxDecoration(
      color: Colors.white.withValues(alpha: fill),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    );
