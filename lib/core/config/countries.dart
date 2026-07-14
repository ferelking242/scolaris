/// Les pays, à UN SEUL endroit — code ISO 3166-1 alpha-2 → nom affiché.
///
/// `schools.country` contenait du TEXTE LIBRE : « Congo », « congo ». Trois
/// calculs s'appuient pourtant dessus, et tous les trois échouaient en silence :
///
///  • la DEVISE — le rattrapage de `20260720` cherchait `country = 'CG'` et n'a
///    jamais trouvé une seule ligne. Toutes les écoles sont restées en XAF : la
///    bonne valeur pour Brazzaville, par accident. Une école kinoise aurait
///    facturé en francs CFA au lieu de francs congolais ;
///  • le SYSTÈME ÉDUCATIF — « francophone » désigne le programme français en
///    France et l'africain au Congo. La distinction se fait sur `FR` ;
///  • le CATALOGUE DES NIVEAUX, qui en découle.
///
/// La base impose désormais le format (`schools_country_iso`) : un champ texte
/// libre ferait échouer l'enregistrement. On propose donc une liste.
library;

/// Code ISO → nom du pays. Zone franc CFA d'abord (le marché actuel), puis le
/// reste de l'Afrique et la France.
const kCountries = <String, String>{
  // Afrique centrale — franc CFA (XAF)
  'CG': 'Congo-Brazzaville',
  'CD': 'RD Congo',
  'CM': 'Cameroun',
  'GA': 'Gabon',
  'TD': 'Tchad',
  'CF': 'Centrafrique',
  'GQ': 'Guinée équatoriale',

  // Afrique de l'Ouest — franc CFA (XOF)
  'SN': 'Sénégal',
  'CI': "Côte d'Ivoire",
  'BF': 'Burkina Faso',
  'ML': 'Mali',
  'BJ': 'Bénin',
  'TG': 'Togo',
  'NE': 'Niger',
  'GN': 'Guinée',

  // Afrique anglophone
  'NG': 'Nigeria',
  'GH': 'Ghana',
  'KE': 'Kenya',
  'ZA': 'Afrique du Sud',

  // Maghreb
  'MA': 'Maroc',
  'DZ': 'Algérie',
  'TN': 'Tunisie',

  'FR': 'France',
};

/// Nom affichable d'un code pays. Renvoie le code lui-même s'il est inconnu :
/// mieux vaut afficher « XX » que rien, on voit tout de suite que ça cloche.
String countryName(String? code) =>
    code == null ? '—' : (kCountries[code.toUpperCase()] ?? code);

/// Variantes de noms rencontrées à la saisie → code ISO.
/// Le formulaire d'inscription propose une saisie assistée sur les NOMS : c'est
/// une bonne ergonomie, on la garde. Mais ce qu'on ENREGISTRE est un code.
const _kNameToCode = <String, String>{
  'congo': 'CG',
  'congo-brazzaville': 'CG',
  'republique du congo': 'CG',
  'rdc': 'CD',
  'rd congo': 'CD',
  'congo-kinshasa': 'CD',
  'republique democratique du congo': 'CD',
  'cameroun': 'CM',
  'gabon': 'GA',
  'tchad': 'TD',
  'centrafrique': 'CF',
  'guinee equatoriale': 'GQ',
  'senegal': 'SN',
  'cote d ivoire': 'CI',
  'cote divoire': 'CI',
  'burkina faso': 'BF',
  'mali': 'ML',
  'benin': 'BJ',
  'togo': 'TG',
  'niger': 'NE',
  'guinee': 'GN',
  'nigeria': 'NG',
  'ghana': 'GH',
  'kenya': 'KE',
  'afrique du sud': 'ZA',
  'maroc': 'MA',
  'algerie': 'DZ',
  'tunisie': 'TN',
  'france': 'FR',
};

/// Code ISO d'un pays saisi au clavier. `null` si on ne reconnaît pas — et il
/// FAUT alors refuser l'enregistrement plutôt que d'écrire n'importe quoi : la
/// base impose le format (`schools_country_iso`), et la devise, le système
/// éducatif et le catalogue des niveaux se calculent tous à partir de ce code.
String? countryCodeOf(String? input) {
  final raw = input?.trim();
  if (raw == null || raw.isEmpty) return null;

  // Déjà un code ?
  final up = raw.toUpperCase();
  if (up.length == 2 && kCountries.containsKey(up)) return up;

  // Sinon un nom : on compare sans accents ni ponctuation.
  const accents = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
  const plain = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
  var k = raw.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    k = k.replaceAll(accents[i], plain[i].toLowerCase());
  }
  k = k.replaceAll(RegExp(r"['`’\-_.]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  return _kNameToCode[k];
}

/// Années scolaires proposées, autour de l'année courante.
/// L'année scolaire commence en septembre : en juillet 2026, on est encore sur
/// 2025-2026.
List<String> academicYears({int back = 2, int forward = 2}) {
  final now = DateTime.now();
  // Avant septembre, l'année scolaire en cours a commencé l'année civile passée.
  final start = now.month >= 9 ? now.year : now.year - 1;
  return [
    for (var y = start - back; y <= start + forward; y++) '$y-${y + 1}',
  ];
}
