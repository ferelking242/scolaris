import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_storage.dart';

class SettingsState {
  final bool notificationsPush;
  final bool grandePolice;
  final bool contrasteEleve;
  final bool reduireAnimations;
  final bool partagerDonnees;

  const SettingsState({
    this.notificationsPush = true,
    this.grandePolice = false,
    this.contrasteEleve = false,
    this.reduireAnimations = false,
    this.partagerDonnees = true,
  });

  SettingsState copyWith({
    bool? notificationsPush,
    bool? grandePolice,
    bool? contrasteEleve,
    bool? reduireAnimations,
    bool? partagerDonnees,
  }) =>
      SettingsState(
        notificationsPush: notificationsPush ?? this.notificationsPush,
        grandePolice: grandePolice ?? this.grandePolice,
        contrasteEleve: contrasteEleve ?? this.contrasteEleve,
        reduireAnimations: reduireAnimations ?? this.reduireAnimations,
        partagerDonnees: partagerDonnees ?? this.partagerDonnees,
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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
