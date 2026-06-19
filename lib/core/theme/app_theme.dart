import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Palette africaine de Scolaris.
class ScolarisPalette {
  ScolarisPalette._();

  static const terracotta  = Color(0xFF8B1A00);
  static const orange      = Color(0xFFD4540A);
  static const gold        = Color(0xFFC17F24);
  static const forestGreen = Color(0xFF1B5E20);
  static const cream       = Color(0xFFFDF6E3);
  static const darkBrown   = Color(0xFF3E1A00);
  static const menuBg      = Color(0xFF0D3B1E);
  static const menuAccent  = Color(0xFFC17F24);
}

class AppTheme {
  AppTheme._();

  static ThemeData light({Color? accent}) {
    final seed = accent ?? const Color(AppConfig.defaultAccentArgb);
    return FlexThemeData.light(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.light),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      appBarStyle: FlexAppBarStyle.surface,
      appBarOpacity: 0.95,
      subThemesData: const FlexSubThemesData(
        useM2StyleDividerInM3: false,
        defaultRadius: 12,
        elevatedButtonSchemeColor: SchemeColor.primary,
        inputDecoratorRadius: 12,
        cardRadius: 16,
        dialogRadius: 20,
        chipRadius: 10,
        tooltipRadius: 8,
        navigationBarHeight: 64,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData dark({Color? accent}) {
    final seed = accent ?? const Color(AppConfig.defaultAccentArgb);
    return FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      appBarStyle: FlexAppBarStyle.background,
      appBarOpacity: 0.93,
      subThemesData: const FlexSubThemesData(
        useM2StyleDividerInM3: false,
        defaultRadius: 12,
        inputDecoratorRadius: 12,
        cardRadius: 16,
        dialogRadius: 20,
        chipRadius: 10,
        tooltipRadius: 8,
        navigationBarHeight: 64,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  // Mode Noir Pur — AMOLED true black pour les écrans OLED
  static ThemeData pureBlack({Color? accent}) {
    final seed = accent ?? const Color(AppConfig.defaultAccentArgb);
    return FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 40,
      darkIsTrueBlack: true,
      appBarStyle: FlexAppBarStyle.background,
      appBarOpacity: 1.0,
      subThemesData: const FlexSubThemesData(
        useM2StyleDividerInM3: false,
        defaultRadius: 12,
        inputDecoratorRadius: 12,
        cardRadius: 16,
        dialogRadius: 20,
        chipRadius: 10,
        tooltipRadius: 8,
        navigationBarHeight: 64,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}
