/// Pré-inscription — construit le lien public à partir du `slug` réel de
/// l'école (`schools.slug`, posé une fois pour toutes par la migration
/// 20260714 — jamais recalculé côté client). L'état ouvert/fermé de la
/// période vit sur `schools.preregistration_open` (cf. `SupabaseDbSource`).
class PreRegStore {
  PreRegStore._();

  /// Domaine public (à ajuster quand le web sera déployé).
  static const String baseUrl = 'https://scolaris.app';

  /// URL publique de pré-inscription pour le slug d'une école.
  static String linkFor(String slug) => '$baseUrl/inscription/$slug';
}
