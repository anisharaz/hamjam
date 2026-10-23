import 'package:flutter/material.dart';

/// Plain, flat palette: white and light blue surfaces, one strong blue, one sky accent.
class Palette {
  static const bg = Color(0xFFF4F9FF);
  static const surface = Colors.white;
  static const tint = Color(
    0xFFE3F0FF,
  ); // light blue fill for secondary buttons and incoming bubbles
  static const border = Color(0xFFDCE8F5);
  static const primary = Color(0xFF1E6FE0);
  static const sky = Color(0xFF38BDF8);
  static const ink = Color(0xFF0D2B4E);
  static const live = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  /// Secondary text: the ink colour, softened.
  static Color get muted => ink.withValues(alpha: 0.6);
}

/// Shared corner radii so every surface feels related.
class Radii {
  static const card = 20.0;
  static const button = 16.0;
  static const bubble = 18.0;
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.primary,
        brightness: Brightness.light,
      ).copyWith(
        surface: Palette.surface,
        primary: Palette.primary,
        onPrimary: Colors.white,
        secondary: Palette.sky,
        onSurface: Palette.ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    iconTheme: const IconThemeData(color: Palette.ink),
    dividerTheme: const DividerThemeData(
      color: Palette.border,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Palette.ink,
      ),
      contentTextStyle: TextStyle(
        fontSize: 15,
        height: 1.4,
        color: Palette.muted,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Palette.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// White card with a thin blue-grey border. Flat: no shadow, no gradient.
BoxDecoration cardDecoration({double radius = Radii.card}) => BoxDecoration(
  color: Palette.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Palette.border),
);
