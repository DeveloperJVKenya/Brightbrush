import 'package:flutter/material.dart';

/// Brand palette sampled from the BrightBrush Creations logo, deliberately
/// kept separate from the neutral surface palette below. Material's
/// `ColorScheme.fromSeed` ties every neutral (background/surface/outline)
/// to the hue of a single seed color — seeding on the brand red gives
/// "clean" light surfaces but a muddy, brownish-red dark mode. Studios that
/// live and die by color shouldn't ship a theme with an accidental hue cast,
/// so the two palettes below are built independently and merged in
/// [AppTheme]: cool neutral graphite for structure, red used only where it's
/// meant to be seen.
class BrandColors {
  BrandColors._();

  static const Color brushRed = Color(0xFFD8232B);
  static const Color brushRedBright = Color(0xFFFF5A60); // dark-mode accent
  static const Color brushRedDeep = Color(0xFF8C0F16);
  static const Color plum = Color(0xFF3A1620); // gradient partner for brushRed

  /// A subtle two-stop brand gradient used sparingly for accent strokes,
  /// selected-state fills and hero moments — never for large flat fills.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brushRed, plum],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    // Neutral seed (cool blue-gray) keeps surfaces/outlines genuinely
    // neutral instead of red-tinted; brand red is grafted on as the
    // primary accent only.
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6472),
      brightness: Brightness.light,
    );
    final colorScheme = base.copyWith(
      primary: BrandColors.brushRed,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFE0DE),
      onPrimaryContainer: BrandColors.brushRedDeep,
      secondary: const Color(0xFF3D4451),
      surface: const Color(0xFFFAFAF9),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F4F3),
      surfaceContainer: const Color(0xFFEFEEEC),
      surfaceContainerHigh: const Color(0xFFE9E7E5),
      outline: const Color(0xFFDAD8D5),
      outlineVariant: const Color(0xFFE7E5E2),
    );
    return _build(colorScheme, Brightness.light);
  }

  static ThemeData dark() {
    // Cool graphite, not brown: the neutral seed stays neutral in dark
    // brightness too, and the red accent is brightened for contrast
    // instead of relying on the seed's (muddy) dark-red tonal step.
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6472),
      brightness: Brightness.dark,
    );
    final colorScheme = base.copyWith(
      primary: BrandColors.brushRedBright,
      onPrimary: const Color(0xFF3A0508),
      primaryContainer: const Color(0xFF5C1015),
      onPrimaryContainer: const Color(0xFFFFDAD8),
      secondary: const Color(0xFFC4C9D4),
      surface: const Color(0xFF17181C),
      surfaceContainerLowest: const Color(0xFF101114),
      surfaceContainerLow: const Color(0xFF1B1C20),
      surfaceContainer: const Color(0xFF202127),
      surfaceContainerHigh: const Color(0xFF282A31),
      outline: const Color(0xFF3A3C43),
      outlineVariant: const Color(0xFF2A2C32),
    );
    return _build(colorScheme, Brightness.dark);
  }

  static ThemeData _build(ColorScheme colorScheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colorScheme.surfaceContainer : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
