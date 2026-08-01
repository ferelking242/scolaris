import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/entities/user_entity.dart';

/// Levée quand l'école du compte existe mais n'a pas encore été validée par
/// l'équipe Scolaris (`schools.is_active = false`) — cas d'une école créée
/// via le self-signup public (`SchoolRegistrationScreen`), en attente de
/// validation dans la console plateforme (`platform_schools_page.dart`).
class SchoolPendingValidationException implements Exception {
  final String schoolName;
  const SchoolPendingValidationException(this.schoolName);
}

class SupabaseAuthSource {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  SupabaseAuthSource() {
    // ── Restauration immédiate depuis la session stockée ──────────────────
    // Sur Flutter Web, Supabase restore la session depuis localStorage *avant*
    // que le listener ne reçoive son premier événement. On lit donc la session
    // courante de façon synchrone et on l'émet immédiatement pour que le router
    // ne redirige pas vers /login à chaque rechargement de page.
    _restoreCurrentSession();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event   = data.event;
      final session = data.session;

      // Tous les événements indiquant une session VALIDE
      if (session != null && (
          event == AuthChangeEvent.signedIn          ||
          event == AuthChangeEvent.tokenRefreshed    ||
          event == AuthChangeEvent.initialSession    ||
          event == AuthChangeEvent.userUpdated)) {
        // Évite de re-fetcher le profil si c'est le même utilisateur
        if (_current?.id == session.user.id && _current != null) {
          return;
        }
        try {
          final user = await _fetchProfile(session.user.id);
          _current = user;
          _controller.add(user);
        } catch (_) {
          _current = null;
          _controller.add(null);
        }
        return;
      }

      // Session expirée ou déconnexion explicite
      if (event == AuthChangeEvent.signedOut ||
          (event == AuthChangeEvent.tokenRefreshed && session == null)) {
        _current = null;
        _controller.add(null);
      }
    });
  }

  /// Lit la session Supabase déjà en mémoire (restaurée depuis localStorage
  /// sur web) et émet l'utilisateur sans attendre un événement du stream.
  Future<void> _restoreCurrentSession() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    if (_current != null) return; // déjà hydraté
    try {
      final user = await _fetchProfile(authUser.id);
      _current = user;
      _controller.add(user);
    } catch (_) {
      // Session stockée mais profil inaccessible (ex. RLS) → on laisse null
    }
  }

  Future<AppUser?> currentUser() async {
    if (_current != null) return _current;
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return null;
    try {
      _current = await _fetchProfile(authUser.id);
      return _current;
    } catch (_) {
      return null;
    }
  }

  Stream<AppUser?> changes() => _controller.stream;

  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.user == null) {
      throw ArgumentError('auth.errors.failed');
    }
    try {
      return await _fetchProfile(response.user!.id);
    } on SchoolPendingValidationException {
      // La session existe côté Supabase mais l'école n'est pas validée :
      // on la révoque tout de suite plutôt que de laisser un JWT valide
      // traîner pour un compte qu'on refuse d'utiliser.
      await Supabase.instance.client.auth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _current = null;
    _controller.add(null);
  }

  Future<AppUser> _fetchProfile(String authUid) async {
    final data = await Supabase.instance.client
        .from('users')
        .select()
        .eq('auth_uid', authUid)
        .maybeSingle();

    if (data == null) {
      throw StateError(
          'Profil utilisateur introuvable ou inaccessible pour $authUid — '
          'vérifier la ligne `users` et son adhésion `school_members`.');
    }

    final schoolId = data['school_id'] as String?;
    if (schoolId != null) {
      final school = await Supabase.instance.client
          .from('schools')
          .select('name, is_active')
          .eq('id', schoolId)
          .maybeSingle();
      if (school != null && school['is_active'] == false) {
        throw SchoolPendingValidationException(school['name'] as String? ?? '');
      }
    }

    final rawRole = data['role'] as String? ?? 'student';
    final role = UserRole.fromString(rawRole);

    Set<String> permissions = {};
    if (role == UserRole.staff) {
      final raw = data['permissions'];
      if (raw is List) permissions = raw.map((e) => e.toString()).toSet();
      final r = rawRole.toLowerCase();
      if (r == 'admin' || r == 'direction' || r == 'directeur' || r == 'dg') {
        permissions = {'*'};
      }
    }

    final title = data['role_title'] as String?;
    final r = rawRole.toLowerCase();
    final displayTitle = (title != null && title.isNotEmpty)
        ? title
        : (r == 'admin' || r == 'direction' ? 'Direction' : null);

    var isPlatformAdmin = false;
    try {
      final pa = await Supabase.instance.client
          .from('platform_admins')
          .select('user_id')
          .eq('user_id', data['id'] as String)
          .maybeSingle();
      isPlatformAdmin = pa != null;
    } catch (_) {}

    final user = AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      fullName: data['full_name'] as String? ?? '',
      role: role,
      schoolId: data['school_id'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      schoolAccentArgb: AppConfig.defaultAccentArgb,
      roleTitle: displayTitle,
      permissions: permissions,
      phone: data['phone'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      lastSeenAt: data['last_seen_at'] != null
          ? DateTime.tryParse(data['last_seen_at'] as String)
          : null,
      isPlatformAdmin: isPlatformAdmin,
    );

    unawaited(_touchLastSeen(data['id'] as String));
    return user;
  }

  Future<void> _touchLastSeen(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_seen_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (_) {}
  }
}
