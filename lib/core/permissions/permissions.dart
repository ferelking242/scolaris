import '../../domain/entities/user_entity.dart';
import 'staff_permissions.dart';

/// RBAC centralisé. L'UI ne doit JAMAIS coder en dur des checks de rôle —
/// appeler ce service.
///
/// Deux niveaux :
///  • rôle (staff / teacher / student / parent) — accès de base ;
///  • permissions granulaires du staff (capacités cochées par l'admin).
/// La Direction (fondateur) a `permissions = {'*'}` → accès total.
///
/// Exemple :
///   if (PermissionService.I.has(user, StaffPermissions.finance)) { ... }
class PermissionService {
  PermissionService._();
  static final I = PermissionService._();

  /// Le membre du personnel a-t-il la capacité [key] ?
  /// (true si accès total. Faux pour les rôles non-staff.)
  bool has(AppUser? u, String key) =>
      u != null && u.role == UserRole.staff && u.can(key);

  bool canViewDashboard(AppUser? u) => u != null;

  // Notes : enseignant (ses classes) OU staff avec la capacité « grades ».
  bool canEditGrades(AppUser? u) =>
      u != null &&
      (u.role == UserRole.teacher || has(u, StaffPermissions.grades));

  // Présences : enseignant OU staff avec la capacité « attendance ».
  bool canMarkAttendance(AppUser? u) =>
      u != null &&
      (u.role == UserRole.teacher || has(u, StaffPermissions.attendance));

  bool canManagePayments(AppUser? u) => has(u, StaffPermissions.finance);

  bool canManageUsers(AppUser? u) => has(u, StaffPermissions.staffManage);

  bool canViewChildren(AppUser? u) => u?.role == UserRole.parent;
}
