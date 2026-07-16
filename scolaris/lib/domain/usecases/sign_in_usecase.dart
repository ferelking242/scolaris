import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Sign in with email/password — pure use case.
class SignInUseCase {
  final AuthRepository _repo;
  SignInUseCase(this._repo);

  Future<AppUser> call(String email, String password) {
    if (!email.contains('@')) {
      throw ArgumentError('auth.errors.invalidEmail');
    }
    if (password.length < 4) {
      throw ArgumentError('auth.errors.shortPassword');
    }
    return _repo.signInWithEmail(email.trim(), password);
  }
}

class SignOutUseCase {
  final AuthRepository _repo;
  SignOutUseCase(this._repo);
  Future<void> call() => _repo.signOut();
}

class SignInWithQrUseCase {
  final AuthRepository _repo;
  SignInWithQrUseCase(this._repo);
  Future<AppUser> call(String token) => _repo.signInWithQrToken(token);
}
