import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/remote/supabase_auth_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthSource _remote;
  AuthRepositoryImpl(this._remote);

  @override
  Future<AppUser?> currentUser() => _remote.currentUser();

  @override
  Future<AppUser> signInWithEmail(String email, String password) =>
      _remote.signInWithEmail(email, password);

  @override
  Future<AppUser> signInWithQrToken(String token) =>
      _remote.signInWithQrToken(token);

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Stream<AppUser?> authChanges() => _remote.changes();
}
