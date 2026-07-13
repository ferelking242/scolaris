import 'staff_permissions.dart';

/// Pont entre les deux modèles de permissions qui coexistent.
///
/// **Source de vérité** : les tables Supabase `staff_roles` /
/// `staff_role_permissions`, où un droit s'écrit `module.action`
/// (ex. `notes.saisir`). Le droit est porté par le RÔLE, pas par la personne.
///
/// **Projection** : le jsonb `users.permissions`, liste plate de 11 clés
/// ([StaffPermissions]) que consomment le menu dynamique, les gardes de pages
/// et `AppUser.can()`. On la dérive du rôle à chaque écriture pour que
/// l'existant continue de fonctionner sans modification.
///
/// La projection perd volontairement la finesse (`voir` vs `modifier`) : cette
/// finesse n'est appliquée nulle part aujourd'hui — seules 2 policies RLS sur 56
/// appellent `has_permission()`. Tant qu'un module n'est pas réellement verrouillé
/// côté base, on ne l'expose pas action par action dans l'UI : ce serait promettre
/// une sécurité inexistante. Cf. `supabase/migrations/20260713_staff_rbac.sql`.
class RbacMapping {
  RbacMapping._();

  /// Module RBAC (base) → permission historique (menu & gardes).
  ///
  /// Les 10 modules couvrent 10 des 11 clés historiques. `discipline` n'a pas
  /// de module dédié : elle est dérivée de `presences` (le Surveillant Général,
  /// qui porte la vie scolaire, a les deux dans tous les modèles de rôles).
  static const Map<String, String> moduleToPermission = {
    'eleves': StaffPermissions.students,
    'classes': StaffPermissions.classes,
    'notes': StaffPermissions.grades,
    'presences': StaffPermissions.attendance,
    'comptabilite': StaffPermissions.finance,
    'rapports': StaffPermissions.reports,
    'emploi_du_temps': StaffPermissions.timetable,
    'messages': StaffPermissions.communication,
    'utilisateurs': StaffPermissions.staffManage,
    'parametres': StaffPermissions.schoolConfig,
  };

  /// Permission historique → module RBAC (sens inverse, sans `discipline`).
  static final Map<String, String> permissionToModule = {
    for (final e in moduleToPermission.entries) e.value: e.key,
  };

  /// Modules dont au moins une action est accordée, à partir des grants
  /// `module.action` d'un rôle.
  static Set<String> modulesOf(Set<String> grants) =>
      grants.map((g) => g.split('.').first).toSet();

  /// Projette les grants d'un rôle vers la liste plate de `users.permissions`.
  ///
  /// [isAdminRole] (Direction / fondateur) court-circuite tout : `{'*'}`.
  static List<String> toLegacyPermissions(
    Set<String> grants, {
    bool isAdminRole = false,
  }) {
    if (isAdminRole) return const [kAllPermission];

    final out = <String>{};
    for (final module in modulesOf(grants)) {
      final key = moduleToPermission[module];
      if (key != null) out.add(key);
    }
    // `discipline` n'existe pas côté RBAC : la vie scolaire suit les présences.
    if (out.contains(StaffPermissions.attendance)) {
      out.add(StaffPermissions.discipline);
    }
    return out.toList()..sort();
  }

  /// Cycle de l'école (`primaire` | `college` | `lycee` | `universite`) déduit
  /// de `schools.metadata.types`. Sert à filtrer les `role_templates`.
  ///
  /// Ne pas confondre avec `SbSchool.cycles`, qui laisse tomber `universite` et
  /// n'est donc pas utilisable ici.
  static String cycleFromTypes(List<String> types) {
    if (types.contains('universite') || types.contains('superieur')) {
      return 'universite';
    }
    if (types.contains('lycee')) return 'lycee';
    if (types.contains('college')) return 'college';
    return 'primaire';
  }
}
