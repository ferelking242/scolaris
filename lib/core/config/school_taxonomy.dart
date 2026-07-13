/// Le vocabulaire de l'école, à UN SEUL endroit.
///
/// Il en existait quatre, qui ne se parlaient pas :
///
///  1. `schools.metadata.types` (inscription) — garderie, primaire, college,
///     lycee, universite, technique, superieur, special.
///  2. `schools.metadata.educational_system` (inscription) — francophone,
///     anglophone, lmd, grande_ecole…
///  3. `class_levels.cycle` (catalogue) — prescolaire, primaire, college, lycee,
///     universite_l, universite_m, universite_d, prepa.
///  4. `class_levels.system_type` (catalogue) — francophone_africa,
///     francophone_france, anglophone_nigeria, anglophone_ghana,
///     anglophone_kenya, anglophone_cameroon, anglophone_southafrica,
///     arabophone, lmd, grande_ecole…
///
/// Chaque écran traduisait ces listes à sa façon, et chacun perdait quelque
/// chose. Une université se retrouvait avec les niveaux du primaire ; une école
/// anglophone avec des niveaux francophones.
///
/// Toute nouvelle traduction se fait ICI, nulle part ailleurs.
class SchoolTaxonomy {
  SchoolTaxonomy._();

  /// Type d'établissement → cycles du catalogue des niveaux.
  ///
  /// Une école a plusieurs types (un complexe scolaire : primaire + collège +
  /// lycée), donc plusieurs cycles.
  static const Map<String, List<String>> _typeToCycles = {
    'garderie': ['prescolaire'],
    'primaire': ['primaire'],
    'college': ['college'],
    'lycee': ['lycee'],
    // Un lycée technique reste un lycée : mêmes niveaux (2nde → Terminale),
    // seules les filières changent — et elles vivent dans `series`, pas ici.
    'technique': ['lycee'],
    'universite': ['universite_l', 'universite_m', 'universite_d'],
    'superieur': ['universite_l', 'universite_m', 'universite_d', 'prepa'],
    // Établissement spécialisé : pas de niveaux propres au catalogue. On lui
    // ouvre les cycles scolaires, à lui de choisir.
    'special': ['primaire', 'college', 'lycee'],
  };

  /// Cycles du catalogue correspondant aux types d'une école.
  ///
  /// Liste vide si l'école n'a pas renseigné ses types — et il FAUT alors la
  /// traiter comme « je ne sais pas », pas comme « aucun ». C'est cette confusion
  /// qui faisait proposer CP1 à une université.
  static List<String> cyclesOf(List<String> types) {
    final out = <String>{};
    for (final t in types) {
      out.addAll(_typeToCycles[t] ?? const []);
    }
    return out.toList();
  }

  /// Système éducatif de l'école + pays → `class_levels.system_type`.
  ///
  /// Le système seul ne suffit pas : « francophone » désigne le programme
  /// français en France et le programme africain au Congo. Ce sont deux
  /// catalogues de niveaux différents.
  static String systemTypeOf({String? system, String? country}) {
    final s = (system ?? 'francophone').toLowerCase();
    final c = (country ?? 'CG').toUpperCase();

    switch (s) {
      case 'anglophone':
        switch (c) {
          case 'NG':
            return 'anglophone_nigeria';
          case 'GH':
            return 'anglophone_ghana';
          case 'KE':
            return 'anglophone_kenya';
          case 'CM':
            return 'anglophone_cameroon';
          case 'ZA':
            return 'anglophone_southafrica';
          default:
            return 'anglophone_nigeria'; // le plus répandu de la zone
        }

      case 'arabophone':
        return 'arabophone';

      case 'lmd':
        return 'lmd';

      case 'grande_ecole':
        return 'grande_ecole';

      case 'francophone':
      default:
        // La France a son propre catalogue ; le reste de la zone partage le
        // programme africain.
        return c == 'FR' ? 'francophone_france' : 'francophone_africa';
    }
  }
}
