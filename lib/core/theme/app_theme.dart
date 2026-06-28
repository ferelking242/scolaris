import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

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

class ScolarisAccents {
  ScolarisAccents._();
  static const terracotta = Color(0xFF8B1A00);
  static const sapphire   = Color(0xFF1565C0);
  static const emerald    = Color(0xFF1B5E20);
  static const amber      = Color(0xFFC17F24);
  static const violet     = Color(0xFF6A1B9A);
  static const slate      = Color(0xFF37474F);
  static const rose       = Color(0xFFBE185D);
  static const cyan       = Color(0xFF0891B2);

  static const all   = [terracotta, sapphire, emerald, amber, violet, slate, rose, cyan];
  static const names = ['Terracotta','Saphir','Émeraude','Ambre','Violet','Ardoise','Rose','Cyan'];
}

// ── Navy dark palette ────────────────────────────────────────────────────────
const _navyBg    = Color(0xFF0F172A); // slate-950
const _navySurf  = Color(0xFF1E293B); // slate-800
const _navyCard  = Color(0xFF1E293B);
const _navyHigh  = Color(0xFF263549); // slate-700ish
const _navyText  = Color(0xFFF1F5F9); // slate-100
const _navyMuted = Color(0xFF94A3B8); // slate-400
const _navyBord  = Color(0xFF334155); // slate-700

class AppTheme {
  AppTheme._();

  static ButtonStyle get blackButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      );

  static const _dialogInk  = Color(0xFF1A0A00);
  static const _dialogBody = Color(0xFF4A3A2E);

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
      // blendLevel très faible → surfaces restent blanches/gris clair, pas beiges
      surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
      blendLevel: 1,
      appBarStyle: FlexAppBarStyle.surface,
      appBarOpacity: 0.96,
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
    final base = _withReadableDialogs(FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
      darkIsTrueBlack: false,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 2,
      appBarStyle: FlexAppBarStyle.background,
      appBarOpacity: 0.97,
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

    // Remplace les surfaces générées par un vrai dark navy pro
    return base.copyWith(
      scaffoldBackgroundColor: _navyBg,
      colorScheme: base.colorScheme.copyWith(
        surface:              _navySurf,
        surfaceContainer:     _navyHigh,
        surfaceContainerHigh: _navyHigh,
        onSurface:            _navyText,
        onSurfaceVariant:     _navyMuted,
        outline:              _navyBord,
        outlineVariant:       _navyBord.withOpacity(.5),
      ),
      cardColor: _navyCard,
      dividerColor: _navyBord,
      // Dialogues sombres cohérents (override du _withReadableDialogs)
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _navySurf,
        titleTextStyle: base.dialogTheme.titleTextStyle
            ?.copyWith(color: _navyText, fontWeight: FontWeight.w800),
        contentTextStyle: base.dialogTheme.contentTextStyle
            ?.copyWith(color: _navyMuted),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: _navySurf,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _navySurf,
        foregroundColor: _navyText,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: _navySurf,
        indicatorColor: seed.withOpacity(.2),
      ),
      drawerTheme: base.drawerTheme.copyWith(
        backgroundColor: _navySurf,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: _navyHigh,
        filled: true,
      ),
    );
  }
}
