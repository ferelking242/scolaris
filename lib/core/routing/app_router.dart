import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user_entity.dart';
import '../../features/admin/presentation/admin_home.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/enrollment/presentation/public_enrollment_screen.dart';
import '../../features/parent/presentation/parent_home.dart';
import '../../features/platform/presentation/platform_home.dart';
import '../../features/school_registration/school_registration_screen.dart';
import '../../features/student/presentation/student_home.dart';
import '../../features/teacher/presentation/teacher_home.dart';
import '../../presentation/providers/auth_providers.dart';
import '../permissions/platform_admin.dart';

class AppRoutes {
  static const splash          = '/';
  static const login           = '/login';
  static const registerSchool  = '/register-school';
  static const student         = '/student';
  static const parent          = '/parent';
  static const teacher         = '/teacher';
  static const staff           = '/staff';
  static const platform        = '/platform';
  static const preRegister     = '/inscription';
}

/// Retourne la route home d'un utilisateur selon son rôle ET son sous-type.
String roleHome(AppUser user) {
  // Les créateurs (allowlist) atterrissent sur la console plateforme, quel que
  // soit leur rôle d'école.
  if (PlatformAdmins.isPlatformAdmin(user)) return AppRoutes.platform;
  switch (user.role) {
    case UserRole.student:
      // Un seul shell élève : StudentHome se reconfigure selon le niveau réel
      // (classes.level via studentSchoolLevelProvider), primaire compris.
      return AppRoutes.student;
    case UserRole.parent:
      return AppRoutes.parent;
    case UserRole.teacher:
      return AppRoutes.teacher;
    case UserRole.staff:
      return AppRoutes.staff;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (ctx, state) {
      final user = ref.read(authSessionProvider);
      final loc  = state.matchedLocation;
      final atSplash         = loc == AppRoutes.splash;
      final atLogin          = loc == AppRoutes.login;
      final atRegisterSchool = loc == AppRoutes.registerSchool;
      final atPreRegister    = loc.startsWith(AppRoutes.preRegister);

      if (atRegisterSchool) return null;
      // Pré-inscription publique (lien) — accessible sans compte.
      if (atPreRegister) return null;

      // Non authentifié → page de connexion (pas de mode démo).
      if (user == null) {
        if (atLogin) return null; // page login accessible explicitement
        return AppRoutes.login;
      }

      if (atLogin || atSplash) return roleHome(user);

      final home = roleHome(user);
      if (!loc.startsWith(home)) return home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login,
          builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.registerSchool,
          builder: (_, __) => const SchoolRegistrationScreen()),
      // Pré-inscription publique : sans code → saisie du code ; avec code → form.
      GoRoute(path: AppRoutes.preRegister,
          builder: (_, __) => const PreRegEntryScreen()),
      GoRoute(path: '${AppRoutes.preRegister}/:code',
          builder: (_, state) => PublicEnrollmentScreen(
              schoolCode: state.pathParameters['code'] ?? '')),
      GoRoute(path: AppRoutes.student,
          builder: (_, __) => const StudentHome()),
      GoRoute(path: AppRoutes.parent,
          builder: (_, __) => const ParentHome()),
      GoRoute(path: AppRoutes.teacher,
          builder: (_, __) => const TeacherHome()),
      GoRoute(path: AppRoutes.staff,
          builder: (_, __) => const AdminHome()),
      GoRoute(path: AppRoutes.platform,
          builder: (_, __) => const PlatformHome()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }
}
