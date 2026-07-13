/// Devise et barème de notation — à UN SEUL endroit.
///
/// « FCFA » était écrit en dur dans 11 fichiers, et « /20 » dans une dizaine.
/// Une école nigériane aurait vu ses frais de scolarité en FCFA et ses bulletins
/// notés sur 20 — deux choses qui ne veulent rien dire là-bas.
///
/// Ces deux réglages appartiennent à l'école (`schools.currency`,
/// `schools.grading_scale`), pas au code.
///
/// Ne concerne PAS les prix de la plateforme (plans Simple/Pro/Max) : ce sont
/// les prix du vendeur, déjà déclinables par pays via `plan_prices.country`.
library;

/// Symbole d'affichage d'une devise ISO 4217.
///
/// On garde le code ISO quand il n'existe pas de symbole court et sans ambiguïté
/// (FCFA, KES…) : mieux vaut « 12 000 KES » que « 12 000 Sh », qu'on confondrait.
const _kCurrencySymbols = <String, String>{
  'XAF': 'FCFA', // franc CFA Afrique centrale — Congo, Cameroun, Gabon, Tchad…
  'XOF': 'FCFA', // franc CFA Afrique de l'Ouest — Sénégal, Côte d'Ivoire, Mali…
  'CDF': 'FC', // franc congolais (RDC)
  'GNF': 'GNF', // franc guinéen
  'NGN': '₦', // naira
  'GHS': '₵', // cedi
  'KES': 'KES', // shilling kényan
  'ZAR': 'R', // rand
  'MAD': 'MAD', // dirham marocain
  'DZD': 'DA', // dinar algérien
  'TND': 'DT', // dinar tunisien
  'EUR': '€',
  'USD': '\$',
};

/// Devises sans sous-unité en usage courant : on n'affiche pas de décimales.
/// (Le franc CFA n'a pas de centimes.)
const _kZeroDecimal = {'XAF', 'XOF', 'CDF', 'GNF'};

class SchoolFormat {
  final String currency;
  final String gradingScale;

  const SchoolFormat({
    this.currency = 'XAF',
    this.gradingScale = 'numeric_20',
  });

  String get currencySymbol => _kCurrencySymbols[currency] ?? currency;

  /// « 150 000 FCFA », « ₦ 45 000 », « 1 250,50 € ».
  String money(num amount) {
    final zeroDec = _kZeroDecimal.contains(currency);
    final v = zeroDec ? amount.round().toString() : amount.toStringAsFixed(2);

    // Séparateur de milliers : espace insécable étroit, comme en typographie
    // française. Sur la partie entière seulement.
    final parts = v.split('.');
    final digits = parts.first.replaceAll('-', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    final entier = '$sign$buf';
    final montant = parts.length > 1 ? '$entier,${parts[1]}' : entier;

    // Symbole devant pour les devises à symbole court, derrière sinon.
    final sym = currencySymbol;
    return sym.length <= 2 ? '$sym $montant' : '$montant $sym';
  }

  /// Note maximale du barème. 20, 100 — ou 20 en interne pour les lettres, que
  /// l'on convertit à l'affichage.
  double get maxScore => switch (gradingScale) {
        'numeric_100' => 100,
        _ => 20,
      };

  /// Affichage d'une note. [score] est toujours stocké sur le barème de l'école
  /// (colonne `grades.score`), sauf pour 'letter' où il reste numérique en base
  /// et devient une lettre à l'écran.
  ///
  /// « 14,5/20 », « 72/100 », « B ».
  String grade(num? score) {
    if (score == null) return '—';

    switch (gradingScale) {
      case 'letter':
        return _letter(score / maxScore * 100);
      case 'numeric_100':
        return '${score.toStringAsFixed(0)}/100';
      default:
        final s = score.toStringAsFixed(score % 1 == 0 ? 0 : 2);
        return '${s.replaceAll('.', ',')}/20';
    }
  }

  /// Libellé court du barème, pour les en-têtes de tableau : « Note/20 ».
  String get gradeHeader => switch (gradingScale) {
        'letter' => 'Note',
        'numeric_100' => 'Note/100',
        _ => 'Note/20',
      };

  /// Ratio 0→1, pour les jauges et les barres de progression.
  double ratio(num score) => (score / maxScore).clamp(0, 1).toDouble();

  static String _letter(double pct) {
    if (pct >= 70) return 'A';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 45) return 'D';
    if (pct >= 40) return 'E';
    return 'F';
  }
}
