/// Les droits FINS du membre connecté, tels que la base les voit.
///
/// ── Pourquoi ce fichier existe ───────────────────────────────────────────────
///
/// Deux modèles de permissions coexistent :
///
///  • `users.permissions` — 11 clés plates (`grades`, `finance`…). C'est ce que
///    lisent le menu et `PermissionGuard`. Une clé dit qu'on TOUCHE aux notes.
///    Elle ne dit pas si on a le droit de les MODIFIER.
///
///  • `staff_role_permissions` — les vrais droits, action par action
///    (`notes.voir`, `notes.modifier`, `notes.supprimer`). C'est ce que la page
///    des rôles enregistre, et ce que `has_permission()` consulte en base.
///
/// L'interface ne connaissait que le premier. Résultat : une secrétaire ayant
/// `notes.voir` sans `notes.modifier` voyait quand même les boutons « Modifier »
/// et « Supprimer » — et se faisait refuser par la base au moment de cliquer.
/// Protégé, mais absurde : on lui promettait un bouton pour le lui retirer.
///
/// Ce fichier donne à l'interface les MÊMES droits que ceux que la base
/// applique. Le menu reste grossier (il ouvre une page ou non) ; les BOUTONS,
/// eux, deviennent exacts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/remote/supabase_db_source.dart';
import '../../presentation/providers/auth_providers.dart';

/// Droits `module.action` du membre connecté. `{'*'}` = accès total.
final myGrantsProvider = FutureProvider<Set<String>>((ref) async {
  // Se recalcule à chaque changement de session (connexion, changement de rôle).
  ref.watch(authSessionProvider);
  return SupabaseDbSource.getMyGrants();
});

/// « Ai-je le droit de faire ceci ? » — ex. `ref.watch(canProvider('notes.modifier'))`.
///
/// Renvoie `false` tant que les droits ne sont pas chargés : on n'affiche jamais
/// un bouton par défaut, on l'affiche une fois qu'on SAIT.
final canProvider = Provider.family<bool, String>((ref, grant) {
  final grants = ref.watch(myGrantsProvider).valueOrNull;
  if (grants == null) return false;
  return grants.contains('*') || grants.contains(grant);
});
