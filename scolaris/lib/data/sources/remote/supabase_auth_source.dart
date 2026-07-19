import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/entities/user_entity.dart';

class SupabaseAuthSource {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  SupabaseAuthSource() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      if (event == AuthChangeEvent.signedIn && session != null) {
        try {
          final user = await _fetchProfile(session.user.id);
          _current = user;
          _controller.add(user);
        } catch (_) {
          _current = null;
          _controller.add(null);
        }
      } else if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.tokenRefreshed && session == null) {
        _current = null;
        _controller.add(null);
      }
    });
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
    return _fetchProfile(response.user!.id);
  }

  Future<AppUser> signInWithQrToken(String token) async {
    final parts = token.split(':');
    if (parts.length < 2) throw ArgumentError('QR invalide');
    final email = parts[1];
    final password = parts.length > 2 ? parts[2] : 'demo1234';
    return signInWithEmail(email, password);
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
      // Ne JAMAIS se rabattre silencieusement sur un faux profil élève : ça a
      // déjà causé un bug (prof invité redirigé vers l'espace élève) quand la
      // ligne `users` existait mais restait invisible à cause de la RLS
      // (adhésion `school_members` manquante). Mieux vaut échouer bruyamment.
      throw StateError(
          'Profil utilisateur introuvable ou inaccessible pour $authUid — '
          'vérifier la ligne `users` et son adhésion `school_members`.');
    }

    final rawRole = data['role'] as String? ?? 'student';
    final role = UserRole.fromString(rawRole);

    // Permissions du personnel : lues depuis la colonne jsonb. Le fondateur /
    // direction (rôle brut 'admin'/'direction') a TOUJOURS un accès total, même
    // si la colonne est vide (compte créé à l'inscription avant assignation).
    Set<String> permissions = {};
    if (role == UserRole.staff) {
      final raw = data['permissions'];
      if (raw is List) permissions = raw.map((e) => e.toString()).toSet();
      final r = rawRole.toLowerCase();
      if (r == 'admin' || r == 'direction' || r == 'directeur' || r == 'dg') {
        permissions = {'*'};
      }
    }

    // Titre affiché : la colonne role_title (ex. « Secrétaire ») si renseignée,
    // sinon « Direction » pour le fondateur, sinon le libellé du rôle.
    final title = data['role_title'] as String?;
    final r = rawRole.toLowerCase();
    final displayTitle = (title != null && title.isNotEmpty)
        ? title
        : (r == 'admin' || r == 'direction' ? 'Direction' : null);

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
      // Valeur AVANT cette connexion (= « dernière connexion »).
      lastSeenAt: data['last_seen_at'] != null
          ? DateTime.tryParse(data['last_seen_at'] as String)
          : null,
    );

    // Marque l'activité courante (pour la prochaine « dernière connexion » et
    // la liste du personnel côté admin). Fire-and-forget — n'échoue pas le login.
    unawaited(_touchLastSeen(data['id'] as String));

    return user;
  }

  Future<void> _touchLastSeen(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_seen_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (_) {
      /* sans gravité */
    }
  }
}
