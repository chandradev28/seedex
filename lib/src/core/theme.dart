import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SeedexPalette {
  const SeedexPalette._();

  static const Color blue = Color(0xFF2783DE);
  static const Color blueSoft = Color(0xFFE5F2FC);
  static const Color green = Color(0xFF46A171);
  static const Color greenSoft = Color(0xFFE8F1EC);
  static const Color orange = Color(0xFFD5803B);
  static const Color orangeSoft = Color(0xFFFBEBDE);
  static const Color red = Color(0xFFE56458);
  static const Color redSoft = Color(0xFFFCE9E7);
  static const Color ink = Color(0xFF2C2C2B);
  static const Color secondary = Color(0xFF7D7A75);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF9F8F7);
  static const Color surfaceStrong = Color(0xFFF0EFED);
  static const Color border = Color(0xFFE6E5E3);
  static const Color darkCanvas = Color(0xFF191919);
  static const Color darkSurface = Color(0xFF202020);
  static const Color darkRaised = Color(0xFF2C2C2B);
}

class SeedexTheme {
  const SeedexTheme._();

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? SeedexPalette.darkCanvas : SeedexPalette.canvas;
    final surface = dark ? SeedexPalette.darkSurface : SeedexPalette.surface;
    final ink = dark ? Colors.white : SeedexPalette.ink;
    final secondary = dark
        ? Colors.white.withValues(alpha: 0.65)
        : SeedexPalette.secondary;
    final border = dark
        ? Colors.white.withValues(alpha: 0.14)
        : SeedexPalette.border;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      fontFamily: 'sans-serif',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: dark ? const Color(0xFF5E9FE8) : SeedexPalette.blue,
        onPrimary: Colors.white,
        secondary: SeedexPalette.green,
        onSecondary: Colors.white,
        error: dark ? const Color(0xFFE97366) : SeedexPalette.red,
        onError: Colors.white,
        surface: surface,
        onSurface: ink,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: border,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    final text = base.textTheme.copyWith(
      displaySmall: TextStyle(
        color: ink,
        fontSize: 34,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        color: ink,
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: TextStyle(
        color: ink,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyLarge: TextStyle(
        color: ink,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: ink,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: ink,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: secondary,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? SeedexPalette.darkRaised : SeedexPalette.surface,
        hintStyle: text.bodyLarge?.copyWith(color: secondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SeedexPalette.blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: canvas,
        modalBackgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.96),
        elevation: 0,
        height: 72,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? SeedexPalette.blue : secondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? SeedexPalette.green
              : (dark ? Colors.white24 : const Color(0xFFD1D1D6));
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
    );
  }
}
