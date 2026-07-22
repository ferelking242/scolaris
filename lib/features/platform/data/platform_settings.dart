import 'platform_mock_data.dart';

/// Réglages de la plateforme — **maquette** (état en mémoire) pour les tarifs.
/// En prod, ces réglages vivront côté serveur (table `platform_settings`) et
/// piloteront réellement les tarifs. Ici, éditer ces valeurs n'affecte que
/// cette page.
///
/// ⚠️ La liste `admins` ci-dessous N'EST PLUS la source de vérité des accès —
/// depuis 20260756_platform_admins.sql, c'est la table `platform_admins` (en
/// base) qui décide qui accède à la console (cf. `PlatformAdmins`). Cette
/// liste reste un affichage/maquette pour l'écran Réglages ; ajouter/retirer
/// ici NE CHANGE RIEN à qui peut réellement se connecter — volontaire : un
/// admin plateforme ne doit pas pouvoir s'accorder ce statut, ou en accorder
/// à quelqu'un d'autre, depuis l'interface. Ça se fait par SQL direct pour
/// l'instant.
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

  /// Équipe super-admin affichée ici — maquette, cf. avertissement ci-dessus.
  static final List<String> admins = <String>[];

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
