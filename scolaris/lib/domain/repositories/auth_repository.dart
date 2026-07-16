import '../entities/user_entity.dart';

/// Auth repository interface (domain layer).
abstract class AuthRepository {
  Future<AppUser?> currentUser();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signInWithQrToken(String token);
  Future<void> signOut();
  Stream<AppUser?> authChanges();
}
