import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/offline_storage.dart';

/// Theme state : brightness + accent couleur + mode noir pur.
class ThemeState {
  final ThemeMode mode;
  final Color accent;
  final bool pureBlack;

  const ThemeState({
    required this.mode,
    required this.accent,
    this.pureBlack = false,
  });

  ThemeState copyWith({ThemeMode? mode, Color? accent, bool? pureBlack}) =>
      ThemeState(
        mode: mode ?? this.mode,
        accent: accent ?? this.accent,
        pureBlack: pureBlack ?? this.pureBlack,
      );
}

class ThemeController extends StateNotifier<ThemeState> {
  ThemeController() : super(_load());

  static ThemeState _load() {
    final box = OfflineStorage.settings;
    final modeIdx =
        ((box.get('theme_mode', defaultValue: 0) as int)).clamp(0, 2);
    final accentInt =
        box.get('theme_accent', defaultValue: AppConfig.defaultAccentArgb)
            as int;
    final pureBlack =
        box.get('theme_pure_black', defaultValue: false) as bool;
    return ThemeState(
      mode: ThemeMode.values[modeIdx],
      accent: Color(accentInt),
      pureBlack: pureBlack,
    );
  }

  void setMode(ThemeMode mode) {
    OfflineStorage.settings.put('theme_mode', mode.index);
    state = state.copyWith(mode: mode);
  }

  void setAccent(Color color) {
    OfflineStorage.settings.put('theme_accent', color.value);
    state = state.copyWith(accent: color);
  }

  void setPureBlack(bool v) {
    OfflineStorage.settings.put('theme_pure_black', v);
    state = state.copyWith(pureBlack: v);
  }

  void toggleBrightness() {
    final next =
        state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setMode(next);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeState>(
  (ref) => ThemeController(),
);
