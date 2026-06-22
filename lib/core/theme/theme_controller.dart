import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Theme state: brightness mode + dynamic accent color (per-school branding).
class ThemeState {
  final ThemeMode mode;
  final Color accent;

  const ThemeState({required this.mode, required this.accent});

  ThemeState copyWith({ThemeMode? mode, Color? accent}) =>
      ThemeState(mode: mode ?? this.mode, accent: accent ?? this.accent);
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController()
      : super(ThemeState(
          mode: ThemeMode.system,
          accent: const Color(AppConfig.defaultAccentArgb),
        ));

  void setMode(ThemeMode mode) => state = state.copyWith(mode: mode);
  void setAccent(Color color) => state = state.copyWith(accent: color);
  void toggleBrightness() {
    final next = state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = state.copyWith(mode: next);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
