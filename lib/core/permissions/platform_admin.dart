/// Reconnaissance des **super-admins plateforme** (nous, les créateurs de
/// Scolaris) — la « tour de contrôle » au-dessus de toutes les écoles.
///
/// v1 : simple allowlist d'emails (aucune migration, modifiable en un endroit).
/// Plus tard on pourra basculer sur une table `platform_admins` ou un rôle
/// dédié + Edge Function `service_role` pour lire réellement toutes les écoles.
library;

import '../../domain/entities/user_entity.dart';

class PlatformAdmins {
  PlatformAdmins._();

  /// Emails autorisés à accéder à la console plateforme (en minuscules).
  static const Set<String> emails = {
    'kenganiboveldy@gmail.com',
  };

  static bool isOne(String? email) =>
      email != null && emails.contains(email.trim().toLowerCase());

  static bool isPlatformAdmin(AppUser? user) => isOne(user?.email);
}
