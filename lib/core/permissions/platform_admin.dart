/// Reconnaissance des **super-admins plateforme** (nous, les créateurs de
/// Scolaris) — la « tour de contrôle » au-dessus de toutes les écoles.
///
/// Vient de la table `platform_admins` (cf. 20260756_platform_admins.sql),
/// résolue une fois au login dans `AppUser.isPlatformAdmin` — PAS d'allowlist
/// d'emails codée en dur ici : l'ancienne version l'était, et c'était la
/// SEULE protection de cette console (pages plateforme encore en mock
/// aujourd'hui, mais le jour où elles liront les vraies tables, il faut déjà
/// une barrière côté base, pas juste un `if` dans le client).
library;

import '../../domain/entities/user_entity.dart';

class PlatformAdmins {
  PlatformAdmins._();

  static bool isPlatformAdmin(AppUser? user) => user?.isPlatformAdmin ?? false;
}
