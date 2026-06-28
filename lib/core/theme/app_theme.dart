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

// ── Palette navy nuit professionnelle ─────────────────────────────────────────
// Inspirée de Linear, Vercel, Notion dark mode
const _dkBg       = Color(0xFF0D1117); // GitHub-style near-black
const _dkSurf     = Color(0xFF161B22); // surface légèrement plus claire
const _dkCard     = Color(0xFF1C2128); // cards avec dépth visible
const _dkHigh     = Color(0xFF21262D); // éléments interactifs au hover
const _dkText     = Color(0xFFE6EDF3); // texte principal (quasi-blanc)
const _dkMuted    = Color(0xFF8B949E); // texte secondaire (gris bleu)
const _dkBord     = Color(0xFF30363D); // bordures subtiles
const _dkBordStr  = Color(0xFF484F58); // bordures plus visibles

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
    final base = FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
      darkIsTrueBlack: false,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 4,
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

    // Override complet vers palette GitHub dark / Vercel dark
    return base.copyWith(
      scaffoldBackgroundColor: _dkBg,
      colorScheme: base.colorScheme.copyWith(
        surface:                  _dkSurf,
        surfaceContainer:         _dkCard,
        surfaceContainerHigh:     _dkHigh,
        surfaceContainerHighest:  _dkHigh,
        surfaceContainerLow:      _dkSurf,
        onSurface:                _dkText,
        onSurfaceVariant:         _dkMuted,
        outline:                  _dkBord,
        outlineVariant:           _dkBord.withOpacity(.5),
        shadow:                   Colors.black,
        scrim:                    Colors.black87,
      ),
      cardColor: _dkCard,
      cardTheme: base.cardTheme.copyWith(color: _dkCard),
      dividerColor: _dkBord,
      dividerTheme: base.dividerTheme.copyWith(color: _dkBord),
      listTileTheme: base.listTileTheme.copyWith(
        tileColor: _dkCard,
        textColor: _dkText,
      ),
      // Dialogues sombres cohérents
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _dkCard,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.dialogTheme.titleTextStyle
            ?.copyWith(color: _dkText, fontWeight: FontWeight.w800),
        contentTextStyle: base.dialogTheme.contentTextStyle
            ?.copyWith(color: _dkMuted),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: _dkCard,
        surfaceTintColor: Colors.transparent,
      ),
      // Header / AppBar avec même fond que la surface (pas noir absolu)
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _dkSurf,
        foregroundColor: _dkText,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(.4),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: _dkText,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: _dkText),
        actionsIconTheme: const IconThemeData(color: _dkMuted),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: _dkSurf,
        indicatorColor: seed.withOpacity(.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _dkMuted),
        ),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: _dkSurf,
        indicatorColor: seed.withOpacity(.22),
      ),
      drawerTheme: base.drawerTheme.copyWith(
        backgroundColor: _dkSurf,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: _dkCard,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dkBord),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dkBord),
        ),
        hintStyle: const TextStyle(color: _dkMuted),
        labelStyle: const TextStyle(color: _dkMuted),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: _dkCard,
        surfaceTintColor: Colors.transparent,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: _dkHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _dkBord),
        ),
        textStyle: const TextStyle(color: _dkText, fontSize: 12),
      ),
    );
  }
}
