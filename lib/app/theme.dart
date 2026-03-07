import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const Color feltDark = Color(0xFF0D4C2D);
  static const Color feltMid = Color(0xFF1A6B43);
  static const Color feltLight = Color(0xFF2B7A52);

  static const Color panelIvory = Color(0xFFF4EFE2);
  static const Color panelIvorySoft = Color(0xFFEDE5D3);
  static const Color panelBorder = Color(0xFFBBAA87);

  static const Color accentGold = Color(0xFFC89D3F);
  static const Color accentRed = Color(0xFF9D2235);
  static const Color accentBlue = Color(0xFF274B9A);
}

ThemeData buildAppTheme() {
  const seed = AppPalette.feltMid;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppPalette.feltMid,
    secondary: AppPalette.accentGold,
    tertiary: AppPalette.accentBlue,
    error: AppPalette.accentRed,
    surface: AppPalette.panelIvory,
    surfaceContainerHighest: AppPalette.panelIvorySoft,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFDEE7D8),
    dividerColor: AppPalette.panelBorder.withValues(alpha: 0.75),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.feltDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 1.25,
      margin: const EdgeInsets.all(8),
      color: AppPalette.panelIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppPalette.panelBorder.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.feltMid,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.feltDark,
        side: const BorderSide(color: AppPalette.panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.panelIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.panelIvory,
      showDragHandle: true,
    ),
  );
}
