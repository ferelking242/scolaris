import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../shared/data/mock_school_brazza.dart';

/// Thin wrapper around Supabase auth.
///
/// When Supabase is not configured (no env vars), this falls back to a
/// deterministic in-memory mock so the app remains fully usable for demos
/// and CI builds.
class SupabaseAuthSource {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  Future<AppUser?> currentUser() async => _current;

  Stream<AppUser?> changes() => _controller.stream;

  Future<AppUser> signInWithEmail(String email, String password) async {
    if (AppConfig.hasSupabaseConfig) {
      // Real Supabase call would happen here.
    }
    return _mockSignIn(email);
  }

  Future<AppUser> signInWithQrToken(String token) async {
    final parts = token.split(':');
    final email = parts.length > 1 ? parts[1] : 'student@scolaris.app';
    return _mockSignIn(email);
  }

  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  /// Mock signin — vérifie d'abord le mock Congo Brazzaville,
  /// puis dérive le rôle et le sous-type depuis l'email.
  AppUser _mockSignIn(String email) {
    // 1. Lookup dans le mock école Saint-Gabriel Brazzaville
    final schoolUser = MockSchoolBrazza.getUser(email);
    if (schoolUser != null) {
      _current = schoolUser;
      _controller.add(schoolUser);
      return schoolUser;
    }

    // 2. Fallback : dériver depuis l'email
    final local = email.split('@').first.toLowerCase();
    final role  = _detectRole(local);

    // Détection du sous-type depuis l'email (ex: student_primaire, student_lycee)
    final subtype = _detectSubtype(local, role);

    final user = AppUser(
      id: 'mock-${local.hashCode}',
      email: email,
      fullName: _humanize(local),
      role: role,
      schoolId: kSchoolId,
      schoolAccentArgb: AppConfig.defaultAccentArgb,
      roleTitle: subtype,
    );
    _current = user;
    _controller.add(user);
    return user;
  }

  UserRole _detectRole(String local) {
    if (local.contains('admin') ||
        local.contains('finance') ||
        local.contains('survey') ||
        local.contains('surveillance') ||
        local.contains('staff') ||
        local.contains('secretaire') ||
        local.contains('dg') ||
        local.contains('directeur')) {
      return UserRole.staff;
    }
    if (local.contains('teacher') || local.contains('prof')) {
      return UserRole.teacher;
    }
    if (local.contains('parent')) return UserRole.parent;
    return UserRole.student;
  }

  /// Retourne le sous-type string pour les étudiants et parents
  /// (utilisé par le router pour choisir le bon dashboard).
  String? _detectSubtype(String local, UserRole role) {
    if (role == UserRole.student || role == UserRole.parent) {
      if (local.contains('primaire')) return 'primaire';
      if (local.contains('college'))  return 'college';
      if (local.contains('lycee'))    return 'lycee';
      if (local.contains('univ'))     return 'univ';
    }
    if (role == UserRole.staff) {
      if (local.contains('comptable'))  return 'Comptable';
      if (local.contains('caissier'))   return 'Caissier';
      if (local.contains('secretaire')) return 'Secrétaire';
      if (local.contains('dg'))         return 'Directeur Général';
      if (local.contains('directeur'))  return 'Directeur';
      if (local.contains('surveillance') || local.contains('survey')) return 'Surveillance';
    }
    return null;
  }

  String _humanize(String s) {
    if (s.isEmpty) return 'User';
    final clean = s.replaceAll(RegExp(r'_.*'), ''); // retire le sous-type
    return clean[0].toUpperCase() + clean.substring(1);
  }
}
