/// Application roles. Single source of truth.
///
/// Le staff (secrétaire, DG, surveillant, finance, admin, etc.)
/// est regroupé en un seul rôle [staff] avec accès total.
/// Les permissions granulaires sont définies dans PermissionService.
enum UserRole {
  staff,
  teacher,
  student,
  parent;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'staff':
      case 'staff_custom':
      case 'admin':
      case 'secretaire':
      case 'secretariat':
      case 'dg':
      case 'directeur':
      case 'surveillance':
      case 'surveillant':
      case 'finance':
      case 'comptable':
        return UserRole.staff;
      case 'teacher':
      case 'prof':
      case 'professeur':
      case 'enseignant':
        return UserRole.teacher;
      case 'parent':
      case 'guardian':
        return UserRole.parent;
      case 'student':
      case 'eleve':
      case 'élève':
      default:
        return UserRole.student;
    }
  }

  String get label {
    switch (this) {
      case UserRole.staff:
        return 'Staff';
      case UserRole.teacher:
        return 'Enseignant';
      case UserRole.student:
        return 'Élève';
      case UserRole.parent:
        return 'Parent';
    }
  }
}

/// Authenticated user entity (domain layer — pure Dart, no framework deps).
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? schoolId;
  final String? avatarUrl;
  final int? schoolAccentArgb;
  /// Sous-titre du rôle (ex: "Secrétaire", "DG", "Surveillant") — pour affichage
  final String? roleTitle;

  /// Permissions granulaires du personnel (clés de StaffPermissions).
  /// La clé "*" = accès total (Direction / fondateur). Vide pour les rôles
  /// non-staff (leur accès est défini par le rôle lui-même).
  final Set<String> permissions;

  final String? phone;
  final DateTime? createdAt;
  /// Dernière activité connue AVANT la session courante (pour « dernière
  /// connexion »). Mise à jour à chaque connexion.
  final DateTime? lastSeenAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.schoolId,
    this.avatarUrl,
    this.schoolAccentArgb,
    this.roleTitle,
    this.permissions = const {},
    this.phone,
    this.createdAt,
    this.lastSeenAt,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? schoolId,
    String? avatarUrl,
    int? schoolAccentArgb,
    String? roleTitle,
    Set<String>? permissions,
    String? phone,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        schoolId: schoolId ?? this.schoolId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        schoolAccentArgb: schoolAccentArgb ?? this.schoolAccentArgb,
        roleTitle: roleTitle ?? this.roleTitle,
        permissions: permissions ?? this.permissions,
        phone: phone ?? this.phone,
        createdAt: createdAt ?? this.createdAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  String get displayRole => roleTitle ?? role.label;

  /// Accès total (Direction / fondateur).
  bool get hasFullAccess => permissions.contains('*');

  /// Le membre a-t-il la capacité [permissionKey] ? (true si accès total.)
  bool can(String permissionKey) =>
      hasFullAccess || permissions.contains(permissionKey);
}
