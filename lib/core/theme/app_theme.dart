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

/// Presets d'accent disponibles dans l'app.
class ScolarisAccents {
  ScolarisAccents._();
  static const terracotta = Color(0xFF8B1A00);
  static const sapphire   = Color(0xFF1565C0);
  static const emerald    = Color(0xFF1B5E20);
  static const amber      = Color(0xFFC17F24);
  static const violet     = Color(0xFF6A1B9A);
  static const slate      = Color(0xFF37474F);

  static const all = [terracotta, sapphire, emerald, amber, violet, slate];
  static const names = ['Terracotta', 'Saphir', 'Émeraude', 'Ambre', 'Violet', 'Ardoise'];
}

class AppTheme {
  AppTheme._();

  /// Bouton noir pur — style shadcn "primary".
  static ButtonStyle get blackButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  // Texte sombre lisible (cohérent avec `ink` de page_scaffold).
  static const _dialogInk   = Color(0xFF1A0A00);
  static const _dialogBody  = Color(0xFF4A3A2E);

  /// Force des dialogues clairs et lisibles, quel que soit le mode (les pages
  /// de l'app sont toujours claires) → plus de texte sombre sur fond sombre.
  static ThemeData _withReadableDialogs(ThemeData base) => base.copyWith(
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: base.textTheme.titleLarge?.copyWith(
            color: _dialogInk,
            fontWeight: FontWeight.w800,
          ),
          contentTextStyle: base.textTheme.bodyMedium?.copyWith(
            color: _dialogBody,
            height: 1.45,
          ),
        ),
      );

  static ThemeData light({Color? accent}) {
    final seed = accent ?? const Color(AppConfig.defaultAccentArgb);
    return _withReadableDialogs(FlexThemeData.light(
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
    ));
  }

  static ThemeData dark({Color? accent}) {
    final seed = accent ?? const Color(AppConfig.defaultAccentArgb);
    return _withReadableDialogs(FlexThemeData.dark(
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
    ));
  }
}
