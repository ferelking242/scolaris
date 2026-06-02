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
      final authUser = Supabase.instance.client.auth.currentUser;
      final email = authUser?.email ?? '';
      return AppUser(
        id: authUid,
        email: email,
        fullName: email.split('@').first,
        role: UserRole.student,
        schoolId: null,
        schoolAccentArgb: AppConfig.defaultAccentArgb,
      );
    }

    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      fullName: data['full_name'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String? ?? 'student'),
      schoolId: data['school_id'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      schoolAccentArgb: AppConfig.defaultAccentArgb,
      roleTitle: data['role'] as String?,
    );
  }
}
