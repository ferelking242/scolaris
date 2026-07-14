/// Le calcul du bulletin, **isolé du reste**.
///
/// C'est le seul endroit où l'on décide ce que vaut une moyenne. Pas de widget,
/// pas de requête, pas de Supabase : des nombres qui entrent, des nombres qui
/// sortent. On peut donc le vérifier contre un vrai bulletin — ce qui a été
/// fait, ligne à ligne, sur celui du Complexe Scolaire Bilingue Félix Éboué
/// (Brazzaville, T1 2022-2023).
///
/// ── La règle ────────────────────────────────────────────────────────────────
///
///   M.C  = moyenne des DEVOIRS            (12,50 + 10,00 + 13,00) / 3 = 11,83
///   Moy  = M.C × (1-w) + Compo × w        (11,83 + 12,50) / 2      = 12,17
///   Total = Moy × Coef                     12,17 × 3               = 36,50
///   Moyenne générale = Σ Total / Σ Coef    368,33 / 30             = 12,28
///
/// `w` (le poids de la composition) et le nombre de devoirs appartiennent à
/// l'**école**, pas au code : une règle nationale figée finit toujours par
/// coincer le jour où une école note autrement. Cf. 20260740.
///
/// ── Le piège qu'on évite ────────────────────────────────────────────────────
///
/// L'ancien bulletin faisait la moyenne arithmétique de toutes les notes :
/// (12,50 + 10 + 13 + 12,50) / 4 = **12,00**. Le vrai résultat est **12,17**.
/// Faux bulletin, faux rang, fausse mention — et un élève qui redouble à tort.
library;

import '../../data/sources/remote/supabase_db_source.dart';

/// La formule de l'école : combien de devoirs, quel poids pour la composition.
class BulletinRules {
  /// Nombre de devoirs par matière et par période (CSBFE : 3).
  final int devoirs;

  /// Poids de la composition, entre 0 et 1. 0.5 → elle pèse autant que la
  /// moyenne des devoirs. 0 → pas de composition du tout.
  final double compoWeight;

  const BulletinRules({this.devoirs = 3, this.compoWeight = 0.5});

  factory BulletinRules.fromSchool(SbSchool? s) => BulletinRules(
        devoirs: s?.bulletinDevoirs ?? 3,
        compoWeight: s?.bulletinCompoWeight ?? 0.5,
      );

  /// Les intitulés de colonnes du carnet et du bulletin. Le dernier devoir
  /// s'appelle « D.D » (devoir dirigé) dans l'usage congolais quand il y en a
  /// trois — sinon on numérote simplement.
  List<String> get devoirLabels => [
        for (var i = 1; i <= devoirs; i++)
          (devoirs == 3 && i == 3) ? 'D.D' : 'Devoir $i',
      ];
}

/// Une ligne du bulletin : une matière, ses notes, sa moyenne, son rang.
class BulletinLine {
  final String subjectId;
  final String subject;
  final int coef;

  /// Les devoirs, dans l'ordre. `null` = note non saisie (case vide au bulletin).
  final List<double?> devoirs;

  /// La composition. `null` = pas encore composée.
  final double? compo;

  /// Moyenne des devoirs saisis. `null` si aucun.
  final double? mc;

  /// La moyenne de la matière : `mc × (1-w) + compo × w`.
  final double? average;

  /// `average × coef` — ce qu'on additionne pour la moyenne générale.
  final double? total;

  /// Rang de l'élève **dans cette matière** (le « RG » du bulletin).
  final int? rank;

  final String appreciation;

  const BulletinLine({
    required this.subjectId,
    required this.subject,
    required this.coef,
    required this.devoirs,
    required this.compo,
    required this.mc,
    required this.average,
    required this.total,
    required this.rank,
    required this.appreciation,
  });

  /// Une matière sans aucune note ne figure pas au bulletin.
  bool get hasGrades => average != null;

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'subject': subject,
        'coef': coef,
        'devoirs': devoirs,
        'compo': compo,
        'mc': mc,
        'average': average,
        'total': total,
        'rank': rank,
        'appreciation': appreciation,
      };
}

/// Le bulletin complet d'un élève, pour une période.
class Bulletin {
  final List<BulletinLine> lines;

  /// Σ Total (le « Total » de la ligne MOYENNES ESSENTIELLES).
  final double totalPoints;

  /// Σ Coef — celui des matières **notées**, pas du programme entier : une
  /// matière sans note ne doit pas gonfler le dénominateur et écraser la
  /// moyenne.
  final int totalCoef;

  /// Σ Total / Σ Coef.
  final double average;

  /// Rang de l'élève dans la classe, et effectif classé.
  final int? rank;
  final int classSize;

  /// Les repères du conseil de classe.
  final double? classAverage;
  final double? bestAverage;
  final double? worstAverage;

  final int absences;
  final int lates;

  const Bulletin({
    required this.lines,
    required this.totalPoints,
    required this.totalCoef,
    required this.average,
    required this.rank,
    required this.classSize,
    this.classAverage,
    this.bestAverage,
    this.worstAverage,
    this.absences = 0,
    this.lates = 0,
  });

  String get mention => mentionOf(average);

  /// La décision proposée — l'administration reste libre de la corriger.
  String get decision => average >= 10 ? 'ADMIS(E)' : 'REDOUBLE';

  bool get isEmpty => lines.isEmpty;
}

/// L'appréciation d'une moyenne. Barème lu sur le bulletin du CSBFE :
/// 14,75 → Bien · 12,83 → Assez-Bien · 10,33 → Moyen.
///
/// Il n'est **pas** réglable pour l'instant, et c'est un choix conscient : tant
/// qu'aucune école ne demande autre chose, un réglage de plus est un réglage à
/// maintenir. Le jour où l'une le demande, ça se paramètre comme le reste.
String mentionOf(double avg) {
  if (avg >= 16) return 'Excellent';
  if (avg >= 14) return 'Bien';
  if (avg >= 12) return 'Assez-Bien';
  if (avg >= 10) return 'Moyen';
  if (avg >= 8) return 'Passable';
  return 'Insuffisant';
}

/// Arrondi à deux décimales — celui du bulletin papier (11,833… → 11,83).
double _r2(double v) => (v * 100).round() / 100;

/// Les notes d'UN élève dans UNE matière → la ligne de bulletin.
///
/// [grades] : toutes les notes de cet élève, cette matière, cette période.
BulletinLine _lineFor({
  required String subjectId,
  required String subject,
  required int coef,
  required List<SbGrade> grades,
  required BulletinRules rules,
}) {
  // Les notes sont ramenées sur 20 (`outOf20`) : une école peut noter sur 10 au
  // primaire, le bulletin reste sur 20.
  double? at(String type, int seq) => grades
      .where((g) => g.type == type && g.sequence == seq)
      .map((g) => g.outOf20)
      .firstOrNull;

  final devoirs = [for (var i = 1; i <= rules.devoirs; i++) at('devoir', i)];
  final compo = at('examen', 1);

  final saisis = devoirs.whereType<double>().toList();

  // ── On calcule en PLEINE précision, on n'arrondit qu'à l'affichage ────────
  //  Le bulletin papier fait pareil, et ça se voit :
  //    Philosophie — M.C 10,67 · Compo 10,00 · Coef 3 · Total 31,00
  //  Avec la Moy arrondie (10,33 × 3) on obtient 30,99. Le papier écrit 31,00 :
  //  il multiplie la valeur exacte (10,3333… × 3 = 31,0000). Même chose pour le
  //  Français (36,50 et non 36,51). Arrondir trop tôt décale les totaux d'un
  //  centime — et sur un bulletin, un centime qui ne tombe pas juste, c'est un
  //  parent qui appelle l'école.
  final mcRaw = saisis.isEmpty
      ? null
      : saisis.reduce((a, b) => a + b) / saisis.length;

  // Pondération. Si la composition manque encore (on est en cours de trimestre),
  // la moyenne vaut celle des devoirs : mieux qu'un zéro implicite, qui ferait
  // paniquer un parent pour rien. Inversement, une compo sans devoir vaut seule.
  final w = rules.compoWeight;
  final avgRaw = (mcRaw != null && compo != null)
      ? mcRaw * (1 - w) + compo * w
      : (mcRaw ?? compo);

  return BulletinLine(
    subjectId: subjectId,
    subject: subject,
    coef: coef,
    devoirs: devoirs,
    compo: compo,
    mc: mcRaw == null ? null : _r2(mcRaw),
    average: avgRaw == null ? null : _r2(avgRaw),
    // Le total vient de la valeur EXACTE, pas de la moyenne affichée.
    total: avgRaw == null ? null : _r2(avgRaw * coef),
    rank: null, // rempli par buildBulletins, qui voit toute la classe
    appreciation: avgRaw == null ? '' : mentionOf(avgRaw),
  );
}

/// Les bulletins de **toute la classe** — en un seul calcul.
///
/// C'est nécessaire : le rang par matière (« RG »), le rang général, la moyenne
/// de la classe, le premier et le dernier ne se calculent pas élève par élève.
/// Un bulletin isolé ne peut pas connaître son rang.
///
/// [programme] : les cours de la classe (matière + coefficient **dans cette
/// classe**). [grades] : toutes les notes de la classe pour la période.
/// [absences] : par élève, (absences, retards).
Map<String, Bulletin> buildBulletins({
  required List<String> studentIds,
  required List<SbCourse> programme,
  required List<SbGrade> grades,
  required BulletinRules rules,
  Map<String, ({int absences, int lates})> attendance = const {},
}) {
  final byStudent = <String, List<SbGrade>>{};
  for (final g in grades) {
    (byStudent[g.studentId] ??= []).add(g);
  }

  // 1) Les lignes, élève par élève (sans les rangs).
  final draft = <String, List<BulletinLine>>{};
  for (final sid in studentIds) {
    final mine = byStudent[sid] ?? const <SbGrade>[];
    draft[sid] = [
      for (final c in programme)
        if (c.subjectId != null)
          _lineFor(
            subjectId: c.subjectId!,
            subject: c.name,
            coef: c.coefficient,
            grades: mine.where((g) => g.subjectId == c.subjectId).toList(),
            rules: rules,
          ),
    ].where((l) => l.hasGrades).toList();
  }

  // 2) Le rang par matière : on classe les élèves sur chaque matière.
  final rankBySubject = <String, Map<String, int>>{};
  for (final c in programme) {
    if (c.subjectId == null) continue;
    final scores = <(String, double)>[
      for (final sid in studentIds)
        for (final l in draft[sid]!)
          if (l.subjectId == c.subjectId && l.average != null)
            (sid, l.average!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    rankBySubject[c.subjectId!] = {
      for (var i = 0; i < scores.length; i++) scores[i].$1: i + 1,
    };
  }

  // 3) Les moyennes générales, puis le rang général.
  final generals = <String, ({double points, int coef, double avg})>{};
  for (final sid in studentIds) {
    final lines = draft[sid]!;
    final points = lines.fold(0.0, (s, l) => s + (l.total ?? 0));
    final coef = lines.fold(0, (s, l) => s + l.coef);
    generals[sid] = (
      points: _r2(points),
      coef: coef,
      avg: coef > 0 ? _r2(points / coef) : 0,
    );
  }

  final classed = studentIds.where((s) => draft[s]!.isNotEmpty).toList()
    ..sort((a, b) => generals[b]!.avg.compareTo(generals[a]!.avg));
  final generalRank = {
    for (var i = 0; i < classed.length; i++) classed[i]: i + 1,
  };

  final avgs = [for (final s in classed) generals[s]!.avg];
  final classAverage = avgs.isEmpty
      ? null
      : _r2(avgs.reduce((a, b) => a + b) / avgs.length);

  // 4) On assemble.
  return {
    for (final sid in studentIds)
      sid: Bulletin(
        lines: [
          for (final l in draft[sid]!)
            BulletinLine(
              subjectId: l.subjectId,
              subject: l.subject,
              coef: l.coef,
              devoirs: l.devoirs,
              compo: l.compo,
              mc: l.mc,
              average: l.average,
              total: l.total,
              rank: rankBySubject[l.subjectId]?[sid],
              appreciation: l.appreciation,
            ),
        ],
        totalPoints: generals[sid]!.points,
        totalCoef: generals[sid]!.coef,
        average: generals[sid]!.avg,
        rank: generalRank[sid],
        classSize: classed.length,
        classAverage: classAverage,
        bestAverage: avgs.isEmpty ? null : avgs.first,
        worstAverage: avgs.isEmpty ? null : avgs.last,
        absences: attendance[sid]?.absences ?? 0,
        lates: attendance[sid]?.lates ?? 0,
      ),
  };
}
