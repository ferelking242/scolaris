import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_storage.dart';

class SettingsState {
  final bool notificationsPush;
  final bool grandePolice;
  final bool contrasteEleve;
  final bool reduireAnimations;
  final bool partagerDonnees;
  final bool afficherBarreOnglets;
  /// Échelle de texte choisie via le curseur d'accessibilité (0.8 → 1.4).
  final double textScale;

  const SettingsState({
    this.notificationsPush = true,
    this.grandePolice = false,
    this.contrasteEleve = false,
    this.reduireAnimations = false,
    this.partagerDonnees = true,
    this.afficherBarreOnglets = false,
    this.textScale = 1.0,
  });

  SettingsState copyWith({
    bool? notificationsPush,
    bool? grandePolice,
    bool? contrasteEleve,
    bool? reduireAnimations,
    bool? partagerDonnees,
    bool? afficherBarreOnglets,
    double? textScale,
  }) =>
      SettingsState(
        notificationsPush: notificationsPush ?? this.notificationsPush,
        grandePolice: grandePolice ?? this.grandePolice,
        contrasteEleve: contrasteEleve ?? this.contrasteEleve,
        reduireAnimations: reduireAnimations ?? this.reduireAnimations,
        partagerDonnees: partagerDonnees ?? this.partagerDonnees,
        afficherBarreOnglets: afficherBarreOnglets ?? this.afficherBarreOnglets,
        textScale: textScale ?? this.textScale,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(_load());

  static SettingsState _load() {
    final box = OfflineStorage.settings;
    return SettingsState(
      notificationsPush:
          box.get('notif_push', defaultValue: true) as bool,
      grandePolice:
          box.get('grande_police', defaultValue: false) as bool,
      contrasteEleve:
          box.get('contraste_eleve', defaultValue: false) as bool,
      reduireAnimations:
          box.get('reduire_animations', defaultValue: false) as bool,
      partagerDonnees:
          box.get('partager_donnees', defaultValue: true) as bool,
      afficherBarreOnglets:
          box.get('afficher_barre_onglets', defaultValue: false) as bool,
      textScale:
          (box.get('text_scale', defaultValue: 1.0) as num).toDouble(),
    );
  }

  void setNotificationsPush(bool v) {
    OfflineStorage.settings.put('notif_push', v);
    state = state.copyWith(notificationsPush: v);
  }

  void setGrandePolice(bool v) {
    OfflineStorage.settings.put('grande_police', v);
    state = state.copyWith(grandePolice: v);
  }

  void setContrasteEleve(bool v) {
    OfflineStorage.settings.put('contraste_eleve', v);
    state = state.copyWith(contrasteEleve: v);
  }

  void setReduireAnimations(bool v) {
    OfflineStorage.settings.put('reduire_animations', v);
    state = state.copyWith(reduireAnimations: v);
  }

  void setPartagerDonnees(bool v) {
    OfflineStorage.settings.put('partager_donnees', v);
    state = state.copyWith(partagerDonnees: v);
  }

  void setAfficherBarreOnglets(bool v) {
    OfflineStorage.settings.put('afficher_barre_onglets', v);
    state = state.copyWith(afficherBarreOnglets: v);
  }

  void setTextScale(double v) {
    final clamped = v.clamp(0.8, 1.4);
    OfflineStorage.settings.put('text_scale', clamped);
    state = state.copyWith(textScale: clamped);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
