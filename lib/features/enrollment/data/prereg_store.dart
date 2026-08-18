/// Pré-inscription — construit le lien public à partir du `slug` réel de
/// l'école (`schools.slug`, posé une fois pour toutes par la migration
/// 20260714 — jamais recalculé côté client). L'état ouvert/fermé de la
/// période vit sur `schools.preregistration_open` (cf. `SupabaseDbSource`).
class PreRegStore {
  PreRegStore._();

  /// App web réellement déployée aujourd'hui (GitHub Pages, cf.
  /// `site_saas/scolaris-config.js` LIEN_APP). ⚠️ Avant le 18/08/2026 ce champ
  /// pointait vers `https://scolaris.app`, un domaine jamais acheté — le lien
  /// public de pré-inscription était mort en pratique. À remplacer par le
  /// vrai domaine le jour où il sera acheté ET pointé vers cette app.
  static const String baseUrl = 'https://ferelking242.github.io/scolaris';

  /// URL publique de pré-inscription pour le slug d'une école. `#/` car
  /// go_router utilise la stratégie hash par défaut (pas de `setUrlStrategy`
  /// dans main.dart) — indispensable sur un hébergement statique GitHub
  /// Pages sans réécriture d'URL côté serveur.
  static String linkFor(String slug) => '$baseUrl/#/inscription/$slug';
}
