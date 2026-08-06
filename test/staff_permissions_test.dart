import 'package:flutter_test/flutter_test.dart';
import 'package:scolaris/core/permissions/staff_permissions.dart';

/// Source de vérité des droits staff. Un bug ici masque (ou révèle) un écran
/// entier au mauvais membre du personnel.
void main() {
  test('byKey retrouve chaque permission déclarée', () {
    for (final p in StaffPermissions.all) {
      expect(StaffPermissions.byKey(p.key)?.key, p.key);
    }
  });

  test('byKey renvoie null pour une clé inconnue', () {
    expect(StaffPermissions.byKey('n_existe_pas'), isNull);
  });

  test('availableFor(null) = école créée avant le système de modules → tout proposer', () {
    expect(StaffPermissions.availableFor(null), StaffPermissions.all);
  });

  test('availableFor filtre les permissions liées à un module désactivé', () {
    final withLibrary = StaffPermissions.availableFor({'library'});
    final withoutLibrary = StaffPermissions.availableFor(<String>{});

    // Toute permission core (module == null) doit rester proposée même sans
    // aucun module actif.
    final coreKeys = StaffPermissions.all.where((p) => p.module == null);
    for (final p in coreKeys) {
      expect(withoutLibrary.map((e) => e.key), contains(p.key));
    }

    // Une permission qui dépend d'un module doit disparaître si ce module
    // n'est pas dans la liste activée.
    final moduleKeys = StaffPermissions.all.where((p) => p.module != null);
    if (moduleKeys.isNotEmpty) {
      final anyModule = moduleKeys.first.module!;
      final missing = StaffPermissions.availableFor({'un_autre_module_improbable'});
      expect(missing.any((p) => p.module == anyModule), isFalse);
    }
    expect(withLibrary, isNotEmpty);
  });

  test('presets ne référencent que des clés existantes (ou le joker *)', () {
    for (final entry in StaffPermissions.presets.entries) {
      for (final key in entry.value) {
        final known = key == kAllPermission || StaffPermissions.byKey(key) != null;
        expect(known, isTrue, reason: 'preset "${entry.key}" référence une clé inconnue: $key');
      }
    }
  });

  test('Co-Directeur a bien l\'accès total via kAllPermission', () {
    expect(StaffPermissions.presets['Co-Directeur'], [kAllPermission]);
  });

  test('preset Personnalisé part sans aucune permission', () {
    expect(StaffPermissions.presets['Personnalisé'], isEmpty);
  });

  test('aucune clé dupliquée dans le catalogue', () {
    final keys = StaffPermissions.all.map((p) => p.key).toList();
    expect(keys.toSet().length, keys.length);
  });
}
