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

  /// Découpage de l'année : `trimester` (T1/T2/T3), `semester` (S1/S2) ou
  /// `monthly` (un bulletin par mois — cf. le primaire, qui note chaque mois
  /// plutôt que chaque trimestre).
  /// Un lycée congolais est en trimestres, une université en semestres.
  final String periodSystem;

  /// Année scolaire (`"2025-2026"`) — ne sert qu'à générer les codes de mois
  /// quand [periodSystem] vaut `monthly` (ex. `"2025-09"`..`"2026-06"`).
  final String academicYear;

  const SchoolFormat({
    this.currency = 'XAF',
    this.gradingScale = 'numeric_20',
    this.periodSystem = 'trimester',
    this.academicYear = '',
  });

  /// Les mois de l'année scolaire, de septembre à juin (10 périodes), au
  /// format `"YYYY-MM"`. Dérivés de [academicYear] ("2025-2026" → 2025-09 …
  /// 2026-06). Si l'année scolaire est absente ou mal formée, on retombe sur
  /// des codes relatifs (`"M1"`..`"M10"`) plutôt que de planter.
  List<String> get _monthlyPeriods {
    final parts = academicYear.split('-');
    final y1 = parts.length == 2 ? int.tryParse(parts[0]) : null;
    if (y1 == null) return const ['M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7', 'M8', 'M9', 'M10'];
    return [
      for (var i = 0; i < 10; i++)
        // Septembre (mois 9) → juin (mois 6) : bascule d'année en janvier.
        () {
          final m = 9 + i;
          final month = m > 12 ? m - 12 : m;
          final year = m > 12 ? y1 + 1 : y1;
          return '$year-${month.toString().padLeft(2, '0')}';
        }(),
    ];
  }

  /// Codes des périodes de l'année, dans l'ordre. C'est la SEULE source :
  /// la saisie des notes et le bulletin doivent lire la même liste, sinon on
  /// écrit les notes dans une période que le bulletin ne relit jamais.
  List<String> get periods => switch (periodSystem) {
        'semester' => const ['S1', 'S2'],
        'monthly' => _monthlyPeriods,
        _ => const ['T1', 'T2', 'T3'],
      };

  static const _kMonthNames = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  /// « 1er trimestre », « Semestre 2 », « Septembre 2025 ».
  String periodLabel(String code) => switch (code) {
        'T1' => '1er trimestre',
        'T2' => '2e trimestre',
        'T3' => '3e trimestre',
        'S1' => 'Semestre 1',
        'S2' => 'Semestre 2',
        _ => _monthLabel(code) ?? code,
      };

  /// `"2025-09"` → `"Septembre 2025"`. `null` si [code] n'a pas cette forme
  /// (laisse [periodLabel] retomber sur le code brut, ex. `"M1"`).
  String? _monthLabel(String code) {
    final parts = code.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return '${_kMonthNames[month]} $year';
  }

  /// Libellé court, pour les puces et les en-têtes serrés : « T1 », « S2 »,
  /// « Sept. » pour un mois.
  String periodShort(String code) {
    final label = _monthLabel(code);
    return label == null ? code : label.substring(0, 4).replaceAll(' ', '');
  }

  /// Vrai si [code] est la dernière période de l'année scolaire — seul moment
  /// où la décision de passage (« ADMIS(E) »/« REDOUBLE ») a un sens. Un
  /// bulletin de septembre ne doit jamais afficher qu'un enfant redouble.
  bool isFinalPeriod(String code) => periods.isNotEmpty && periods.last == code;

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
        'numeric_10' => 10,
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
      case 'numeric_10':
        final s = score.toStringAsFixed(score % 1 == 0 ? 0 : 1);
        return '${s.replaceAll('.', ',')}/10';
      default:
        final s = score.toStringAsFixed(score % 1 == 0 ? 0 : 2);
        return '${s.replaceAll('.', ',')}/20';
    }
  }

  /// Libellé court du barème, pour les en-têtes de tableau : « Note/20 ».
  String get gradeHeader => switch (gradingScale) {
        'letter' => 'Note',
        'numeric_100' => 'Note/100',
        'numeric_10' => 'Note/10',
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
