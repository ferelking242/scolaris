import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/offline_storage.dart';

/// Theme state: dynamic accent color (per-school branding).
/// L'application est en thème clair uniquement — le mode sombre a été retiré.
class ThemeState {
  final Color accent;

  const ThemeState({required this.accent});

  ThemeState copyWith({Color? accent}) =>
      ThemeState(accent: accent ?? this.accent);
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController() : super(_load());

  static const _key = 'theme_accent_argb';

  static ThemeState _load() {
    final saved = OfflineStorage.settings.get(_key) as int?;
    return ThemeState(
      accent: Color(saved ?? AppConfig.defaultAccentArgb),
    );
  }

  void setAccent(Color color) {
    OfflineStorage.settings.put(_key, color.toARGB32());
    state = state.copyWith(accent: color);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
