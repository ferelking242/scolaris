import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Theme state: dynamic accent color (per-school branding).
/// L'application est en thème clair uniquement — le mode sombre a été retiré.
class ThemeState {
  final Color accent;

  const ThemeState({required this.accent});

  ThemeState copyWith({Color? accent}) =>
      ThemeState(accent: accent ?? this.accent);
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController()
      : super(const ThemeState(
          accent: Color(AppConfig.defaultAccentArgb),
        ));

  void setAccent(Color color) => state = state.copyWith(accent: color);
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
