/// Pré-inscription — helpers de lien public + état de la période d'ouverture.
///
/// Maquette : la période ouverte/fermée est gardée **en mémoire** (par école).
/// En prod, ce drapeau vivra sur `schools` (colonne `preregistration_open`) et
/// le lien pointera vers le build web public de Scolaris.
class PreRegStore {
  PreRegStore._();

  /// Domaine public (à ajuster quand le web sera déployé).
  static const String baseUrl = 'https://scolaris.app';

  /// Construit un « code école » lisible pour l'URL (slug), avec repli sur l'id.
  static String slugFor(String? name, String schoolId) {
    if (name == null || name.trim().isEmpty) return schoolId;
    var s = name.toLowerCase().trim();
    const accents = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? schoolId : s;
  }

  /// URL publique de pré-inscription pour un code d'école.
  static String linkFor(String code) => '$baseUrl/inscription/$code';

  // ── Période d'inscription (maquette, en mémoire, par école) ───────────────
  static final Map<String, bool> _open = {};
  static bool isOpen(String schoolId) => _open[schoolId] ?? true;
  static void setOpen(String schoolId, bool value) => _open[schoolId] = value;
}
