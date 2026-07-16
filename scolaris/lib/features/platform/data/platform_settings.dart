import '../../../core/permissions/platform_admin.dart';
import 'platform_mock_data.dart';

/// Réglages de la plateforme — **maquette** (état en mémoire). Seedé depuis les
/// valeurs actuelles (offres codées dans `PlatformPlanX`, allowlist
/// `PlatformAdmins`). En prod, ces réglages vivront côté serveur (table
/// `platform_settings` + `platform_admins`) et piloteront réellement tarifs et
/// accès. Ici, éditer ces valeurs n'affecte que cette page.
class PlatformSettings {
  PlatformSettings._();

  /// Tarif mensuel (FCFA) par offre — modifiable.
  static final Map<PlatformPlan, int> price = {
    for (final p in PlatformPlan.values) p: p.monthlyPrice,
  };

  /// Limite d'élèves par offre (null = illimité) — modifiable.
  static final Map<PlatformPlan, int?> limit = {
    for (final p in PlatformPlan.values) p: p.studentLimit,
  };

  /// Équipe super-admin (emails, en minuscules) — seedée depuis l'allowlist.
  static final List<String> admins = [...PlatformAdmins.emails];

  static void setPlan(PlatformPlan p, {required int price, required int? limit}) {
    PlatformSettings.price[p] = price;
    PlatformSettings.limit[p] = limit;
  }

  static bool addAdmin(String email) {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || admins.contains(e)) return false;
    admins.add(e);
    return true;
  }

  static void removeAdmin(String email) => admins.remove(email);
}
