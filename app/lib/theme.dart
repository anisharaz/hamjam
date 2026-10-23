import 'package:flutter/material.dart';

class Palette {
  static const bgTop = Color(0xFFFFFFFF);
  static const bgBottom = Color(0xFFE3F2FD);
  static const ink = Color(0xFF0D2B4E); // text, dark navy
  static const violet = Color(
    0xFF1E6FE0,
  ); // primary blue (name kept for existing references)
  static const pink = Color(0xFF38BDF8); // sky blue accent
  static const live = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  static const brand = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.violet,
        brightness: Brightness.light,
      ).copyWith(
        surface: Colors.white,
        primary: Palette.violet,
        secondary: Palette.pink,
        onSurface: Palette.ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    iconTheme: const IconThemeData(color: Palette.ink),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// White card with a thin blue border and a soft shadow, used across the app.
BoxDecoration glass({double radius = 24, double fill = 0.9}) => BoxDecoration(
  color: Colors.white.withValues(alpha: fill),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Palette.violet.withValues(alpha: 0.12)),
  boxShadow: [
    BoxShadow(
      color: Palette.violet.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ],
);
